-- /qompassai/Diver/tests/lua/ai_cache_retrieval_adversarial.lua
-- Adversarial tests for ai.cache.tiered + ai.retrieval.two_stage.
--
-- Plain words: the main test files check the modules behave; this
-- file tries to BREAK them -- hostile callbacks, reference-aliasing
-- attacks, symlink tricks, TTL edges, shape poisoning, and scale.
-- Checks marked [regression] failed before a fix and pass after.
-- Runs headless via `nvim -l`; it is not loaded at startup.
local passed = 0
local function check(value, message)
    assert(value, message)
    passed = passed + 1
end

local here = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fn.fnamemodify(here, ':h:h:h')
package.path = root .. '/lua/?.lua;' .. root .. '/lua/?/init.lua;' .. package.path

local tiered = require('ai.cache.tiered')
local two = require('ai.retrieval.two_stage')
local discovery = require('ai.mcp.discovery')

local tmpbase = vim.fn.tempname()
local made_dirs = {}
local function fresh_dir(name)
    local dir = tmpbase .. '_' .. name
    vim.fn.mkdir(dir, 'p')
    made_dirs[#made_dirs + 1] = dir
    return dir
end

local function write_file(path, text)
    local handle = assert(io.open(path, 'w'))
    handle:write(text)
    assert(handle:close())
end

-- ------------------------------------------------------------------
-- Discovery wiring: the cache is best-effort. With the tiered module
-- unavailable, M.search must behave exactly as if caching never
-- existed. Runs before any M.search call (the cache is memoized).
-- ------------------------------------------------------------------
do
    local saved = package.loaded['ai.cache.tiered']
    package.loaded['ai.cache.tiered'] = nil
    local modpath = root .. '/lua/ai/cache/tiered.lua'
    local bakpath = modpath .. '.advbak'
    assert(os.rename(modpath, bakpath), 'test setup: hide tiered module')
    local function restore()
        os.rename(bakpath, modpath)
        package.loaded['ai.cache.tiered'] = saved
    end
    local ok, run_err = pcall(function()
        local called = false
        discovery.search('advnocacheq', function(err, results)
            called = true
            check(type(err) == 'string' and results == nil, 'uncached M.search surfaces the backend error, no crash')
        end)
        check(called, 'uncached M.search invokes the callback')
    end)
    restore()
    assert(ok, 'uncached search raised: ' .. tostring(run_err))
    check(vim.fn.filereadable(modpath) == 1, 'tiered module restored after the uncached test')
end

-- ------------------------------------------------------------------
-- Discovery wiring: shape-poisoned disk entries must be rejected by
-- the read-path validation and fall through to a live search (which
-- errors here -- no backend is configured), never served.
-- The disk file is written BEFORE the first M.search call, because
-- the discovery cache instance is memoized per process.
-- ------------------------------------------------------------------
local searxng_url, brave_key = vim.env.SEARXNG_URL, vim.env.BRAVE_API_KEY
vim.env.SEARXNG_URL = nil
vim.env.BRAVE_API_KEY = nil
local data_dir = vim.fn.stdpath('data') .. '/ai/cache'
vim.fn.mkdir(data_dir, 'p')
local persist_file = data_dir .. '/tiered_global.json'
local backup_file = persist_file .. '.advbak'
local had_persist = vim.fn.filereadable(persist_file) == 1
if had_persist then
    assert(os.rename(persist_file, backup_file), 'test setup: back up the persist file')
end
do
    local now = os.time()
    local poison_doc = {
        version = 1,
        entries = {
            ['mcp_discovery:advhitq'] = {
                value = {
                    { title = 'Cached Server', url = 'https://example.com/x', content = 'cached' },
                },
                stored_at = now,
                ttl_s = 3600,
            },
            -- Well-formed JSON, but title is not a string: poison.
            ['mcp_discovery:advpoisonq'] = {
                value = { { title = {}, url = 'https://evil.example/', content = 'poison' } },
                stored_at = now,
                ttl_s = 3600,
            },
        },
    }
    write_file(persist_file, vim.json.encode(poison_doc))

    local hit1 = false
    discovery.search('advhitq', function(err, results)
        hit1 = true
        check(err == nil, 'cached search: no error')
        check(
            type(results) == 'table' and results[1].title == 'Cached Server',
            'valid cache entry is served without a backend'
        )
        results[1].title = 'MUTATED'
    end)
    check(hit1, 'cached search callback ran')
    local hit2 = false
    discovery.search('advhitq', function(err, results)
        hit2 = true
        check(
            err == nil and results[1].title == 'Cached Server',
            'served results are detached; caller mutation does not poison the cache'
        )
    end)
    check(hit2, 'second cached search callback ran')

    local poisoned = false
    discovery.search('advpoisonq', function(err, results)
        poisoned = true
        check(type(err) == 'string' and results == nil, 'poisoned entry is rejected, never served')
        check(
            err:find('no search backend') ~= nil or err:find('curl') ~= nil,
            'poison falls through to the live-search error path: ' .. tostring(err)
        )
    end)
    check(poisoned, 'poisoned search callback ran')

    local validated = false
    discovery.search('', function(err, results)
        validated = true
        check(
            err == 'query must be a non-empty string' and results == nil,
            'query validation still runs before the cache'
        )
    end)
    check(validated, 'validation callback ran')

    -- search_ranked: a fine_fn that always raises falls back to unranked.
    local fell_back = false
    discovery.search_ranked('advhitq', function(err, results)
        fell_back = true
        check(err == nil, 'search_ranked with raising fine_fn: no error')
        check(
            #results == 1 and results[1].title == 'Cached Server',
            'search_ranked with raising fine_fn falls back to unranked results'
        )
    end, {
        fine_fn = function()
            error('judge exploded')
        end,
    })
    check(fell_back, 'raising-fine_fn fallback callback ran')

    -- search_ranked: fine_fn smuggling outside-pool hits falls back too.
    local intruder = false
    discovery.search_ranked('advhitq', function(err, results)
        intruder = true
        check(err == nil and #results == 1, 'search_ranked with outside-pool fine hits falls back to unranked')
    end, {
        fine_fn = function()
            return { { item = { title = 'INTRUDER' }, score = 99 } }
        end,
    })
    check(intruder, 'intruder fallback callback ran')

    -- search_ranked with the default fine scorer still ranks.
    local ranked = false
    discovery.search_ranked('advhitq', function(err, results)
        ranked = true
        check(
            err == nil and #results == 1 and results[1].title == 'Cached Server',
            'search_ranked default fine_fn ranks cached results'
        )
    end)
    check(ranked, 'default-rank callback ran')
end
os.remove(persist_file)
if had_persist then
    assert(os.rename(backup_file, persist_file), 'test cleanup: restore the persist file')
end
vim.env.SEARXNG_URL = searxng_url
vim.env.BRAVE_API_KEY = brave_key

-- ------------------------------------------------------------------
-- Cache: TTL edges via a crafted disk file. os.time() has 1-second
-- granularity, so margins are chosen to be deterministic no matter
-- when within the second the load happens.
-- ------------------------------------------------------------------
do
    local edir = fresh_dir('edges')
    local enow = os.time()
    write_file(
        edir .. '/tiered_global.json',
        vim.json.encode({
            version = 1,
            entries = {
                -- age >= ttl_s at any load instant: deterministically expired.
                edge_expired = { value = 'old', stored_at = enow - 3600, ttl_s = 3600 },
                -- age <= 3599 < ttl_s at any load instant: deterministically live.
                edge_live = { value = 'new', stored_at = enow - 3590, ttl_s = 3600 },
                -- stored_at in the future (clock ran backwards): fail-safe.
                edge_future = { value = 'skew', stored_at = enow + 7200, ttl_s = 3600 },
            },
        })
    )
    local ec = tiered.new({ dir = edir })
    check(ec ~= nil, 'edge disk loads')
    check(ec.get_global('edge_expired') == nil, 'ttl boundary: age == ttl_s is expired')
    check(ec.get_global('edge_live') == 'new', 'ttl: inside ttl_s is live')
    check(ec.get_global('edge_future') == 'skew', 'clock skew (stored_at in the future) serves fail-safe, no crash')
end

-- ------------------------------------------------------------------
-- Cache: reference-aliasing attacks.
-- ------------------------------------------------------------------
do
    -- [regression] get_global used to hand out the live entry table,
    -- so any caller could silently corrupt the cache (and the next
    -- disk persist).
    local ac = tiered.new({ dir = fresh_dir('alias') })
    check(ac.put_global('nested', { a = { b = 1 }, s = 'x' }) == true, 'alias setup put')
    local ref = ac.get_global('nested')
    ref.a.b = 999
    ref.s = 'mut'
    ref.brand_new = true
    local reread = ac.get_global('nested')
    check(
        reread.a.b == 1 and reread.s == 'x' and reread.brand_new == nil,
        '[regression] mutating a get_global result cannot corrupt the cache'
    )

    -- [regression] replay() handed rebuild_fn the LIVE global values.
    local rc = tiered.new({ dir = fresh_dir('replayalias') })
    check(rc.put_global('sys', { v = 1 }) == true, 'replay-alias setup put')
    local rok, rerr = rc.replay({ 't1' }, function(global, keys)
        check(type(global.sys) == 'table' and global.sys.v == 1, 'rebuild_fn still sees global values')
        check(#keys == 1 and keys[1] == 't1', 'rebuild_fn still receives the keys')
        global.sys.v = 999 -- hostile mutation attempt through the "snapshot"
        global.sys.injected = true
        return { t1 = 'rebuilt' }
    end)
    check(rok ~= nil, 'hostile replay ok: ' .. tostring(rerr))
    local sys_after = rc.get_global('sys')
    check(
        sys_after.v == 1 and sys_after.injected == nil,
        '[regression] rebuild_fn cannot mutate globals through the snapshot'
    )

    -- replay stores only requested keys, even if rebuild_fn returns more.
    local r2, r2_err = rc.replay({ 't1' }, function()
        return { t1 = 'x', evil = 'y', sys = 'zzz' }
    end)
    check(r2 ~= nil, 'replay with extra rebuilt keys ok: ' .. tostring(r2_err))
    check(r2.evil == nil and r2.sys == nil, 'replay output contains only requested keys')
    check(rc.get_local('evil') == nil, 'unrequested rebuilt keys are not stored locally')
    check(rc.get_global('sys').v == 1, 'rebuilt key colliding with a global name is ignored')

    -- The replay bound counts duplicate keys: no bypass via repetition.
    local dup_keys = {}
    for i = 1, 33 do
        dup_keys[i] = 'a'
    end
    local rdup, rdup_err = rc.replay(dup_keys, function()
        return {}
    end)
    check(rdup == nil and rdup_err:find('bound') ~= nil, 'replay bound counts duplicate keys')
end

-- ------------------------------------------------------------------
-- Cache: JSON-hostile values never crash, they become nil + error.
-- vim.json.encode caps nesting at 1001 and rejects NaN/inf, so the
-- pcall in detached_copy is the whole defense; prove it holds.
-- ------------------------------------------------------------------
do
    local hc = tiered.new({ dir = fresh_dir('hostile') })
    local nan_ok, nan_err = hc.put_global('nan', 0 / 0)
    check(nan_ok == nil and type(nan_err) == 'string', 'NaN value rejected, no raise')
    local inf_ok, inf_err = hc.put_global('inf', math.huge)
    check(inf_ok == nil and type(inf_err) == 'string', 'inf value rejected, no raise')
    local cyc = {}
    cyc.self = cyc
    local cyc_ok, cyc_err = hc.put_global('cyc', cyc)
    check(cyc_ok == nil and cyc_err:find('JSON') ~= nil, 'cyclic value rejected, no crash: ' .. tostring(cyc_err))
    local deep = {}
    local cursor = deep
    for _ = 1, 20000 do
        cursor.n = {}
        cursor = cursor.n
    end
    local deep_ok, deep_err = hc.put_global('deep', deep)
    check(deep_ok == nil and type(deep_err) == 'string', '20000-deep value rejected without a stack overflow')
end

-- ------------------------------------------------------------------
-- Cache: key edges -- weird-but-legal keys, length limits, and
-- nil/false discipline on values.
-- ------------------------------------------------------------------
do
    local kdir = fresh_dir('keys')
    local kc = tiered.new({ dir = kdir })
    local weird = 'line1\nline2\tünïcodé✓'
    check(kc.put_global(weird, 'w') == true, 'key with newline/tab/unicode accepted')
    check(kc.get_global(weird) == 'w', 'weird key round-trips in memory')
    local kc2 = tiered.new({ dir = kdir })
    check(kc2.get_global(weird) == 'w', 'weird key survives the JSON disk round-trip')
    check(kc.put_global(string.rep('k', 256), 1) == true, '256-byte key accepted')
    local k257_ok, k257_err = kc.put_global(string.rep('k', 257), 1)
    check(k257_ok == nil and k257_err:find('256') ~= nil, '257-byte key rejected')

    check(kc.put_global('kf', false) == true, 'false value stored')
    check(kc.get_global('kf') == false, 'false reads back as false, not nil')
    check(kc.put_global('kz', 0) == true, 'zero value stored')
    check(kc.get_global('kz') == 0, 'zero reads back')
    check(kc.put_global('ke', '') == true, 'empty-string value stored')
    check(kc.get_global('ke') == '', 'empty-string value reads back')
end

-- ------------------------------------------------------------------
-- Cache: symlink attacks on the persist path.
-- ------------------------------------------------------------------
do
    -- [regression] persist used a predictable '.tmp' name: a
    -- pre-planted symlink made io.open('w') truncate the link target.
    local sdir = fresh_dir('symlink')
    local victim = sdir .. '/victim.txt'
    write_file(victim, 'VICTIM-CONTENT')
    assert(vim.uv.fs_symlink(victim, sdir .. '/tiered_global.json.tmp'), 'plant the symlink')
    local sc = tiered.new({ dir = sdir })
    check(sc.put_global('k', 'v') == true, 'put works with a hostile symlink planted')
    local vh = assert(io.open(victim, 'r'))
    local vtext = vh:read('*a')
    vh:close()
    check(vtext == 'VICTIM-CONTENT', '[regression] planted symlink no longer redirects the write')
    local pst = vim.uv.fs_lstat(sdir .. '/tiered_global.json')
    check(pst ~= nil and pst.type == 'file', 'persist file is a regular file')
    local tst = vim.uv.fs_lstat(sdir .. '/tiered_global.json.tmp')
    check(tst ~= nil and tst.type == 'link', 'planted symlink left alone')
    check(sc.get_global('k') == 'v', 'cache works after the symlink attack')

    -- Read side: a persist file that is a symlink to /etc/passwd is
    -- fail-closed, and the next persist replaces the link.
    local rdir = fresh_dir('symlinkread')
    assert(vim.uv.fs_symlink('/etc/passwd', rdir .. '/tiered_global.json'), 'plant read symlink')
    local rc2 = tiered.new({ dir = rdir })
    check(rc2 ~= nil, 'new() survives a symlinked persist file')
    check(rc2.get_global('root') == nil, 'symlinked /etc/passwd reads as a miss')
    check(type(rc2.stats().last_load_error) == 'string', 'symlinked /etc/passwd is reported in stats')
    check(rc2.put_global('k', 'v') == true, 'put works after the read-side attack')
    local rst = vim.uv.fs_lstat(rdir .. '/tiered_global.json')
    check(rst ~= nil and rst.type == 'file', 'persist replaced the symlink with a regular file')
end

-- ------------------------------------------------------------------
-- Cache: LRU order under interleaved get/put; unusable dir.
-- ------------------------------------------------------------------
do
    local lc = tiered.new({ dir = fresh_dir('lru2'), global_count_max = 3 })
    lc.put_global('a', 1)
    lc.put_global('b', 2)
    lc.put_global('c', 3)
    check(lc.get_global('b') == 2, 'interleaved get b')
    check(lc.get_global('a') == 1, 'interleaved get a')
    lc.put_global('d', 4) -- evicts the least-recently-used: c
    check(lc.get_global('c') == nil, 'lru: untouched c evicted under interleaved access')
    check(
        lc.get_global('a') == 1 and lc.get_global('b') == 2 and lc.get_global('d') == 4,
        'lru: refreshed entries survive'
    )

    -- A persist dir that is really a file: memory keeps working.
    local fdir = fresh_dir('filedir')
    local file_path = fdir .. '/not_a_dir'
    write_file(file_path, 'x')
    local fc = tiered.new({ dir = file_path })
    check(fc ~= nil, 'new() with a file as dir still returns a cache')
    check(fc.put_global('k', 'v') == true, 'memory tier works when the disk is unusable')
    check(fc.get_global('k') == 'v', 'memory read works when the disk is unusable')
    check(type(fc.stats().last_persist_error) == 'string', 'persist failure is reported, not raised')
end

-- ------------------------------------------------------------------
-- two_stage: text_of contract violations must become nil + error.
-- ------------------------------------------------------------------
do
    -- [regression] a raising text_of used to escape M.rank as a Lua error.
    local t_raise, t_raise_err = two.rank({ 'a' }, 'q', {
        text_of = function()
            error('boom')
        end,
        fine_fn = function()
            return {}
        end,
    })
    check(
        t_raise == nil and t_raise_err:find('text_of raised') ~= nil,
        '[regression] text_of raise becomes nil+err: ' .. tostring(t_raise_err)
    )

    -- [regression] a table return used to escape via table.concat.
    local t_tab, t_tab_err = two.rank({ 'a' }, 'q', {
        text_of = function()
            return {}
        end,
        fine_fn = function()
            return {}
        end,
    })
    check(
        t_tab == nil and t_tab_err:find('must return a string') ~= nil,
        '[regression] text_of returning a table becomes nil+err'
    )

    -- nil was silently swallowed (treated as ''); the contract says string.
    local t_nil, t_nil_err = two.rank({ 'a' }, 'q', {
        text_of = function()
            return nil
        end,
        fine_fn = function()
            return {}
        end,
    })
    check(t_nil == nil and type(t_nil_err) == 'string', 'text_of returning nil is rejected')

    -- The discovery text_of closure over malformed live-backend items:
    -- a table-valued title makes the '..' raise inside the closure;
    -- that must become nil+err, never escape M.rank.
    local malformed, malformed_err = two.rank({ { title = {}, url = 'u', content = 'c' } }, 'q', {
        text_of = function(item)
            return (item.title or '') .. '\n' .. (item.url or '')
        end,
        fine_fn = function()
            return {}
        end,
    })
    check(malformed == nil and type(malformed_err) == 'string', 'malformed items become nil+err, never a raise')
end

-- ------------------------------------------------------------------
-- two_stage: determinism and scale.
-- ------------------------------------------------------------------
local function overlap_fine(items, query)
    local qterms = {}
    for term in query:lower():gmatch('%w+') do
        qterms[term] = true
    end
    local hits = {}
    for _, item in ipairs(items) do
        local score = 0
        for term in tostring(item):lower():gmatch('%w+') do
            if qterms[term] then
                score = score + 1
            end
        end
        hits[#hits + 1] = { item = item, score = score }
    end
    return hits
end

local function rank_sig(out)
    local parts = {}
    for _, hit in ipairs(out) do
        parts[#parts + 1] = tostring(hit.item) .. '=' .. tostring(hit.score)
    end
    return table.concat(parts, '|')
end

do
    local det_candidates = {}
    for i = 1, 30 do
        det_candidates[i] = 'doc ' .. i .. ' about testing'
    end
    det_candidates[5] = 'neovim lua guide'
    local det_opts = { fine_fn = overlap_fine }
    local first = two.rank(det_candidates, 'neovim lua', det_opts)
    check(first ~= nil, 'determinism baseline ranks')
    local base_sig = rank_sig(first)
    for _ = 1, 20 do
        local again = two.rank(det_candidates, 'neovim lua', det_opts)
        check(again ~= nil and rank_sig(again) == base_sig, 'rank identical across 20 runs')
    end

    -- Order-independent scoring: block_size 1 with distinct scores
    -- derived from content alone. Shuffled input must rank identically.
    local src = {}
    for i = 1, 40 do
        src[i] = 'cand' .. i
    end
    local function num_of(s)
        return tonumber(s:match('cand(%d+)'))
    end
    local oi_opts = {
        block_size = 1,
        pool_size = 40,
        top_k = 40,
        coarse_fn = function(block_text)
            return num_of(block_text)
        end,
        fine_fn = function(items)
            local hits = {}
            for _, item in ipairs(items) do
                hits[#hits + 1] = { item = item, score = 1000 - num_of(item) }
            end
            return hits
        end,
    }
    local function ranking_key(cands)
        local out = assert(two.rank(cands, 'cand', oi_opts))
        local parts = {}
        for _, hit in ipairs(out) do
            parts[#parts + 1] = hit.item
        end
        return table.concat(parts, ',')
    end
    local base_key = ranking_key(src)
    local shuffled = {}
    for i, v in ipairs(src) do
        shuffled[i] = v
    end
    local seed = 12345
    local function rnd(n)
        seed = (seed * 1103515245 + 12345) % 2147483648
        return (seed % n) + 1
    end
    for i = #shuffled, 2, -1 do
        local j = rnd(i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end
    check(base_key == ranking_key(shuffled), 'shuffled input ranks identically (order-free scores)')

    -- Duplicate candidates: identical input, identical output.
    local dups = { 'x one', 'x one', 'y two', 'x one' }
    local dd1 = two.rank(dups, 'x', { fine_fn = overlap_fine })
    local dd2 = two.rank(dups, 'x', { fine_fn = overlap_fine })
    check(dd1 ~= nil and rank_sig(dd1) == rank_sig(dd2), 'duplicate candidates rank deterministically')
end

do
    -- 100k candidates: stage 1 must stay linear-ish, fine_fn sees a
    -- bounded pool only.
    local big = {}
    for i = 1, 100000 do
        big[i] = 'document ' .. i .. ' w' .. (i % 97)
    end
    local pool_seen = 0
    local t0 = os.clock()
    local big_out, big_err = two.rank(big, 'w42', {
        block_size = 8,
        pool_size = 4,
        top_k = 10,
        fine_fn = function(items, query)
            pool_seen = #items
            return overlap_fine(items, query)
        end,
    })
    local elapsed = os.clock() - t0
    check(big_out ~= nil, '100k candidates rank: ' .. tostring(big_err))
    check(pool_seen <= 4 * 8, '100k: fine_fn saw only the bounded pool (' .. pool_seen .. ')')
    check(#big_out == 10, '100k: top_k respected')
    check(elapsed < 20, ('100k: stage 1 stayed linear-ish (%.2fs)'):format(elapsed))
end

-- ------------------------------------------------------------------
-- two_stage: fine_fn edge contracts.
-- ------------------------------------------------------------------
do
    local nohits = two.rank({ 'a', 'b' }, 'q', {
        fine_fn = function()
            return {}
        end,
    })
    check(nohits ~= nil and #nohits == 0, 'empty fine hits give empty results, not an error')

    local noitem, noitem_err = two.rank({ 'a' }, 'q', {
        fine_fn = function()
            return { { score = 1 } }
        end,
    })
    check(noitem == nil and noitem_err:find('outside the candidate pool') ~= nil, 'hit without an item is rejected')

    local infin = two.rank({ 'a', 'b' }, 'q', {
        block_size = 1,
        pool_size = 2,
        top_k = 2,
        fine_fn = function(items)
            return { { item = items[1], score = math.huge }, { item = items[2], score = 1 } }
        end,
    })
    check(infin ~= nil and infin[1].score == math.huge, 'inf fine score accepted and sorts first')

    local ws = two.rank({ 'a', 'b' }, '   ', { fine_fn = overlap_fine })
    check(ws ~= nil and #ws == 2, 'whitespace-only query ranks without crashing')

    local falsy = two.rank({ false, 'a' }, 'a', {
        fine_fn = function()
            return { { item = false, score = 5 } }
        end,
    })
    check(falsy ~= nil and falsy[1].item == false, 'false candidate round-trips the pool check')
end

for _, gone in ipairs(made_dirs) do
    vim.fn.delete(gone, 'rf')
end
print(('PASS: %d checks'):format(passed))
