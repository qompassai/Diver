-- /qompassai/Diver/tests/lua/ai_cache_tiered.lua
-- Self-test for ai.cache.tiered (two-tier context cache).
--
-- Plain words: this script exercises the cache like a checklist --
-- normal use, bad input, time limits, a trashed disk file, and
-- memory limits -- and reports pass or fail. It runs headless via
-- `nvim -l`; it is not loaded at startup.
local passed = 0
local function check(value, message)
    assert(value, message)
    passed = passed + 1
end

local here = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fn.fnamemodify(here, ':h:h:h')
package.path = root .. '/lua/?.lua;' .. root .. '/lua/?/init.lua;' .. package.path

local tiered = require('ai.cache.tiered')

local tmpbase = vim.fn.tempname()
local made_dirs = {}
local function fresh_dir(name)
    local dir = tmpbase .. '_' .. name
    vim.fn.mkdir(dir, 'p')
    made_dirs[#made_dirs + 1] = dir
    return dir
end

-- Constructor validation.
local bad, bad_err = tiered.new('nope')
check(bad == nil and type(bad_err) == 'string', 'new rejects non-table opts')
local bad2 = tiered.new({ global_ttl_s = 0 })
check(bad2 == nil, 'new rejects zero ttl')
local bad3 = tiered.new({ replay_item_max = 'x' })
check(bad3 == nil, 'new rejects non-numeric bound')
local bad4 = tiered.new({ local_count_max = 1.5 })
check(bad4 == nil, 'new rejects fractional count')

-- Normal global put/get.
local dir = fresh_dir('basic')
local cache, new_err = tiered.new({ dir = dir })
check(cache ~= nil, 'new succeeds: ' .. tostring(new_err))
local ok, put_err = cache.put_global('sys.prompt', { text = 'hello' })
check(ok == true, 'put_global ok: ' .. tostring(put_err))
local got = cache.get_global('sys.prompt')
check(type(got) == 'table' and got.text == 'hello', 'get_global roundtrip')
check(vim.fn.filereadable(dir .. '/tiered_global.json') == 1, 'global tier writes a disk file')

-- Stored values are detached from the caller's table.
local original = { text = 'mutable' }
check(cache.put_global('detach', original) == true, 'put detach ok')
original.text = 'changed'
check(cache.get_global('detach').text == 'mutable', 'global stores a detached copy')

-- Global values must survive JSON; functions cannot.
local okf, errf = cache.put_global('fn', function() end)
check(okf == nil and type(errf) == 'string', 'put_global rejects non-encodable value')

-- Misses and bad keys never crash.
check(cache.get_global('missing') == nil, 'get_global miss is nil')
check(cache.get_global(123) == nil, 'get_global bad key is nil, not a crash')
check(cache.get_local('missing') == nil, 'get_local miss is nil')

-- The global tier persists across instances; the local tier does not.
cache.put_local('turn.tail', { last = 'message' })
check(cache.get_local('turn.tail').last == 'message', 'local put/get roundtrip')
local cache2 = tiered.new({ dir = dir })
check(cache2 ~= nil, 'second new on the same dir')
local persisted = cache2.get_global('sys.prompt')
check(type(persisted) == 'table' and persisted.text == 'hello', 'global tier reloads from disk')
check(cache2.get_local('turn.tail') == nil, 'local tier is memory-only')

-- A corrupt disk file is ignored, never fatal (fail closed).
local cdir = fresh_dir('corrupt')
local c1 = tiered.new({ dir = cdir })
check(c1 ~= nil and c1.put_global('k', 'v') == true, 'corrupt setup put ok')
local handle = io.open(cdir .. '/tiered_global.json', 'w')
assert(handle ~= nil, 'can clobber the persist file')
handle:write('this is not json {{{')
handle:close()
local c2 = tiered.new({ dir = cdir })
check(c2 ~= nil, 'new survives a corrupt disk file')
check(c2.get_global('k') == nil, 'corrupt disk reads as a miss')
local cstats = c2.stats()
check(type(cstats.last_load_error) == 'string', 'corrupt disk is reported in stats')
check(c2.put_global('k2', 'v2') == true, 'cache keeps working after corrupt disk')
check(c2.get_global('k2') == 'v2', 'post-corrupt put/get works')

-- Valid JSON with the wrong shape is also ignored.
local handle2 = io.open(cdir .. '/tiered_global.json', 'w')
assert(handle2 ~= nil, 'can rewrite the persist file')
handle2:write('{"version":999,"entries":{}}')
handle2:close()
local c3 = tiered.new({ dir = cdir })
check(c3 ~= nil, 'new survives wrong-shape disk JSON')
check(
    c3.get_global('k2') == nil and type(c3.stats().last_load_error) == 'string',
    'wrong-shape disk is ignored and reported'
)

-- TTL expiry on both tiers, plus prune().
local tdir = fresh_dir('ttl')
local tc = tiered.new({ dir = tdir })
check(tc.put_global('short', 'x', { ttl_s = 1 }) == true, 'short-ttl put ok')
check(tc.get_global('short') == 'x', 'unexpired ttl hits')
vim.wait(1500)
check(tc.get_global('short') == nil, 'expired global ttl misses')
check(tc.put_local('lshort', 'y') == true, 'local put ok')
tc.put_global('prune_me', 'z', { ttl_s = 1 })
vim.wait(1500)
local pruned = tc.prune()
check(pruned >= 1, 'prune removes expired entries')
check(tc.get_global('prune_me') == nil, 'pruned entry stays gone')

-- LRU eviction is deterministic (monotonic sequence, not wall time).
local ldir = fresh_dir('lru')
local lc = tiered.new({ dir = ldir, global_count_max = 2 })
lc.put_global('a', 1)
lc.put_global('b', 2)
check(lc.get_global('a') == 1, 'lru: a present before eviction')
lc.put_global('c', 3)
check(lc.get_global('a') == 1, 'lru: refreshed a survives')
check(lc.get_global('b') == nil, 'lru: least-recently-used b evicted')
check(lc.get_global('c') == 3, 'lru: c present')
check(lc.stats().evictions == 1, 'lru: exactly one eviction counted')

-- Bounded replay: rebuild_fn sees globals + keys; only the window
-- is rebuilt and stored locally. The result is approximate.
local rdir = fresh_dir('replay')
local rc = tiered.new({ dir = rdir, replay_item_max = 4 })
check(rc.put_global('sys', 'SYSTEM') == true, 'replay setup put ok')
local seen_global, seen_keys
local rebuilt, rerr = rc.replay({ 't1', 't2' }, function(global, keys)
    seen_global = global
    seen_keys = keys
    return { t1 = 'rebuilt-t1' }
end)
check(rebuilt ~= nil, 'replay ok: ' .. tostring(rerr))
check(rebuilt.t1 == 'rebuilt-t1' and rebuilt.t2 == nil, 'replay returns requested keys only')
check(seen_global.sys == 'SYSTEM', 'rebuild_fn sees the global snapshot')
check(#seen_keys == 2 and seen_keys[1] == 't1', 'rebuild_fn receives the keys')
check(rc.get_local('t1') == 'rebuilt-t1', 'replay stores rebuilt tails locally')
check(rc.get_local('t2') == nil, 'unrebuilt keys stay missing locally')

-- The replay bound is enforced: never a full rebuild.
local over, over_err = rc.replay({ 'a', 'b', 'c', 'd', 'e' }, function()
    return {}
end)
check(over == nil and over_err:find('bound') ~= nil, 'replay enforces the item bound')

-- Replay misuse.
local r1, e1 = rc.replay('nope', function()
    return {}
end)
check(r1 == nil and type(e1) == 'string', 'replay rejects non-array keys')
local r2 = rc.replay({}, function()
    return {}
end)
check(r2 == nil, 'replay rejects empty keys')
local r3 = rc.replay({ 't1' }, 'nope')
check(r3 == nil, 'replay rejects non-function rebuild_fn')
local r4, e4 = rc.replay({ 't1' }, function()
    error('boom')
end)
check(r4 == nil and e4:find('raised') ~= nil, 'replay converts a rebuild_fn raise to error')
local r5 = rc.replay({ 't1' }, function()
    return 42
end)
check(r5 == nil, 'replay rejects a non-table rebuild result')

-- Put misuse.
local p1, pe1 = rc.put_global('', 'x')
check(p1 == nil and type(pe1) == 'string', 'put_global rejects empty key')
local p2 = rc.put_global('k', 'x', { ttl_s = 0 })
check(p2 == nil, 'put_global rejects a bad ttl override')
local p3 = rc.put_global('k', 'x', 'nope')
check(p3 == nil, 'put_global rejects non-table put_opts')
local p4 = rc.put_local(123, 'x')
check(p4 == nil, 'put_local rejects a non-string key')

-- Stats shape.
local s = rc.stats()
check(s.global_count >= 1 and s.local_count >= 1, 'stats counts both tiers')
check(s.hits >= 1 and s.misses >= 1, 'stats counts hits and misses')
check(s.last_persist_error == nil, 'no persist error on a writable dir')
check(s.last_load_error == nil, 'no load error on a clean dir')

for _, gone in ipairs(made_dirs) do
    vim.fn.delete(gone, 'rf')
end
print(('PASS: %d checks'):format(passed))
