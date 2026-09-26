-- /qompassai/Diver/lua/ai/cache/tiered.lua
-- Two-tier context/prefix cache for the ai/ stack (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved.
-- ----------------------------------------
--
-- Plain words: some context is worth keeping for days (system
-- prompts, project facts) and some is only useful for minutes (the
-- tail of the current turn: tool outputs, last messages). This
-- module keeps the first kind on disk and the second kind in memory
-- only, with a time limit on each.
--
-- The design borrows from DeepSeek-V4.1-Flash's SWA Bounded Replay
-- (arXiv:2609.19969): long-lived state is persisted (their global
-- KV on SSD), short-lived state is recomputed on a miss instead of
-- persisted (their SWA KV), and the recompute is BOUNDED -- only
-- the requested tail window is rebuilt, never the whole context.
-- The rebuilt tail is therefore approximate, not exact; callers
-- that need exact history must keep it themselves.
--
-- Failure behavior is fail-closed: a corrupt or unreadable disk
-- file is ignored (treated as empty) and the cache keeps working
-- from memory. Nothing here ever raises on external input; misuse
-- returns nil + an error string.

local M = {}

local GLOBAL_TTL_S_DEFAULT = 259200 -- 72 hours, the paper's horizon
local LOCAL_TTL_S_DEFAULT = 300 -- 5 minutes: one active turn or so
local GLOBAL_COUNT_MAX_DEFAULT = 512
local LOCAL_COUNT_MAX_DEFAULT = 128
local REPLAY_ITEM_MAX_DEFAULT = 32 -- bounded-replay window cap
local KEY_LENGTH_MAX = 256
local PERSIST_FILENAME = 'tiered_global.json'
local PERSIST_VERSION = 1

-- Monotonic tmp-file sequence, process-scoped below by pid. A fixed
-- '.tmp' name would let anyone with directory write access pre-plant
-- a symlink and have the 'w' open in persist_global truncate the
-- link target; an unpredictable name closes that vector.
local persist_tmp_seq = 0

---@class AiTieredCacheOpts
---@field dir? string persist directory; defaults to stdpath('data')/ai/cache
---@field global_ttl_s? integer default time-to-live for global entries
---@field local_ttl_s? integer default time-to-live for local entries
---@field global_count_max? integer LRU cap for the global tier
---@field local_count_max? integer LRU cap for the local tier
---@field replay_item_max? integer max keys per replay() call

---@class AiTieredPutOpts
---@field ttl_s? integer per-entry TTL override

---@class AiTieredStats
---@field global_count integer live global entries
---@field local_count integer live local entries
---@field hits integer get_* hits since new()
---@field misses integer get_* misses since new()
---@field evictions integer LRU evictions since new()
---@field last_persist_error? string last disk-write failure, if any
---@field last_load_error? string disk-load failure at new(), if any
---@field dir_error? string persist-dir creation failure, if any

---@alias AiRebuildFn fun(global: table<string, any>, keys: string[]): table?
---Rebuilds a bounded local tail from the global snapshot.

---@class AiTieredCache
---@field put_global fun(key: string, value: any, opts?: AiTieredPutOpts): boolean?, string?
---@field get_global fun(key: string): any
---@field put_local fun(key: string, value: any): boolean?, string?
---@field get_local fun(key: string): any
---@field replay fun(keys: string[], rebuild_fn: AiRebuildFn): table?, string?
---@field stats fun(): AiTieredStats
---@field prune fun(): integer

---@param key any
---@return boolean ok
---@return string? err
local function check_key(key)
    if type(key) ~= 'string' then
        return false, 'key must be a string'
    end
    if key == '' then
        return false, 'key must not be empty'
    end
    if #key > KEY_LENGTH_MAX then
        return false, 'key exceeds ' .. KEY_LENGTH_MAX .. ' bytes'
    end
    if key:find('%z') ~= nil then
        return false, 'key contains NUL'
    end
    return true, nil
end

---@param value any
---@return boolean ok
---@return string? err
local function check_integer(value, what)
    if type(value) ~= 'number' then
        return false, what .. ' must be a number'
    end
    if value ~= value or value == math.huge or value == -math.huge then
        return false, what .. ' must be finite'
    end
    if value % 1 ~= 0 then
        return false, what .. ' must be an integer'
    end
    if value < 1 then
        return false, what .. ' must be >= 1'
    end
    return true, nil
end

---@param entry table
---@param now integer
---@return boolean expired
local function entry_expired(entry, now)
    return now - entry.stored_at >= entry.ttl_s
end

---@param entries table<string, table>
---@return string[] sorted keys, for deterministic persistence
local function sorted_keys(entries)
    local keys = {}
    for key in pairs(entries) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

---@param entries table<string, table> mutated in place
---@param count_max integer
---@return integer evicted_count
local function evict_lru(entries, count_max)
    local keys = sorted_keys(entries)
    if #keys <= count_max then
        return 0
    end
    -- Oldest sequence first; keys break ties deterministically.
    table.sort(keys, function(a, b)
        if entries[a].seq ~= entries[b].seq then
            return entries[a].seq < entries[b].seq
        end
        return a < b
    end)
    local evicted = 0
    -- Keys are oldest-first, so the overflow at the front goes.
    for index = 1, #keys - count_max do
        entries[keys[index]] = nil
        evicted = evicted + 1
    end
    return evicted
end

---@param dir string
---@return string path
local function persist_path(dir)
    return dir .. '/' .. PERSIST_FILENAME
end

---@param dir string
---@param entries table<string, table>
---@return boolean ok
---@return string? err
local function persist_global(dir, entries)
    local plain = { version = PERSIST_VERSION, entries = {} }
    for _, key in ipairs(sorted_keys(entries)) do
        local entry = entries[key]
        plain.entries[key] = {
            value = entry.value,
            stored_at = entry.stored_at,
            ttl_s = entry.ttl_s,
        }
    end
    local ok, text = pcall(vim.json.encode, plain)
    if not ok or type(text) ~= 'string' then
        return false, 'encode failed: ' .. tostring(text)
    end
    -- Write-temp + atomic rename so a crash never leaves half a file.
    -- The tmp name is unique per persist (pid + sequence): a
    -- predictable name would let a pre-planted symlink redirect the
    -- 'w' open below into truncating an arbitrary file.
    persist_tmp_seq = persist_tmp_seq + 1
    local tmp_path = persist_path(dir) .. '.tmp.' .. tostring(vim.fn.getpid()) .. '.' .. tostring(persist_tmp_seq)
    local handle, open_err = io.open(tmp_path, 'w')
    if handle == nil then
        return false, 'open failed: ' .. tostring(open_err)
    end
    handle:write(text)
    local flushed, flush_err = handle:close()
    if not flushed then
        os.remove(tmp_path)
        return false, 'close failed: ' .. tostring(flush_err)
    end
    local renamed, rename_err = os.rename(tmp_path, persist_path(dir))
    if not renamed then
        os.remove(tmp_path) -- best-effort: do not litter unique tmp files
        return false, 'rename failed: ' .. tostring(rename_err)
    end
    return true, nil
end

---@param entry any
---@return boolean ok
local function valid_disk_entry(entry)
    return type(entry) == 'table'
        and type(entry.stored_at) == 'number'
        and type(entry.ttl_s) == 'number'
        and entry.value ~= nil
end

---@param dir string
---@return table<string, table> entries (empty when the disk is unusable)
---@return string? load_err set when the disk file was ignored; never raises
local function load_global_entries(dir)
    local handle = io.open(persist_path(dir), 'r')
    if handle == nil then
        return {}, nil -- no file yet: not an error
    end
    local text = handle:read('*a')
    handle:close()
    if type(text) ~= 'string' or text == '' then
        return {}, 'persist file is empty'
    end
    local ok, decoded = pcall(vim.json.decode, text)
    if not ok or type(decoded) ~= 'table' then
        return {}, 'persist file is not valid JSON'
    end
    if decoded.version ~= PERSIST_VERSION or type(decoded.entries) ~= 'table' then
        return {}, 'persist file has an unknown shape'
    end
    local entries = {}
    local now = os.time()
    for key, disk_entry in pairs(decoded.entries) do
        local key_ok = check_key(key)
        if key_ok and valid_disk_entry(disk_entry) then
            local entry = {
                value = disk_entry.value,
                stored_at = math.floor(disk_entry.stored_at),
                ttl_s = math.floor(disk_entry.ttl_s),
                seq = 0,
            }
            -- Drop already-expired disk entries instead of serving them.
            if not entry_expired(entry, now) then
                entries[key] = entry
            end
        end
    end
    return entries, nil
end

---@param opts any
---@return table? normalized
---@return string? err
local function normalize_opts(opts)
    if opts == nil then
        opts = {}
    end
    if type(opts) ~= 'table' then
        return nil, 'opts must be a table'
    end
    local out = {
        dir = opts.dir,
        global_ttl_s = opts.global_ttl_s,
        local_ttl_s = opts.local_ttl_s,
        global_count_max = opts.global_count_max,
        local_count_max = opts.local_count_max,
        replay_item_max = opts.replay_item_max,
    }
    if out.dir == nil then
        out.dir = vim.fn.stdpath('data') .. '/ai/cache'
    end
    if type(out.dir) ~= 'string' or out.dir == '' then
        return nil, 'opts.dir must be a non-empty string'
    end
    if out.global_ttl_s == nil then
        out.global_ttl_s = GLOBAL_TTL_S_DEFAULT
    end
    if out.local_ttl_s == nil then
        out.local_ttl_s = LOCAL_TTL_S_DEFAULT
    end
    if out.global_count_max == nil then
        out.global_count_max = GLOBAL_COUNT_MAX_DEFAULT
    end
    if out.local_count_max == nil then
        out.local_count_max = LOCAL_COUNT_MAX_DEFAULT
    end
    if out.replay_item_max == nil then
        out.replay_item_max = REPLAY_ITEM_MAX_DEFAULT
    end
    local checks = {
        { 'global_ttl_s', out.global_ttl_s },
        { 'local_ttl_s', out.local_ttl_s },
        { 'global_count_max', out.global_count_max },
        { 'local_count_max', out.local_count_max },
        { 'replay_item_max', out.replay_item_max },
    }
    for _, pair in ipairs(checks) do
        local ok, err = check_integer(pair[2], 'opts.' .. pair[1])
        if not ok then
            return nil, err
        end
    end
    return out, nil
end

---Create a two-tier cache. Never raises on bad input.
---@param opts? AiTieredCacheOpts
---@return AiTieredCache?
---@return string? err
function M.new(opts)
    local cfg, cfg_err = normalize_opts(opts)
    if cfg == nil then
        return nil, cfg_err
    end
    assert(cfg_err == nil, 'normalize_opts failed without an error')

    local state = {
        cfg = cfg,
        seq = 0,
        hits = 0,
        misses = 0,
        evictions = 0,
        last_persist_error = nil,
        last_load_error = nil,
        dir_error = nil,
        global_entries = {},
        local_entries = {},
    }

    local mkdir_ok, mkdir_err = pcall(vim.fn.mkdir, cfg.dir, 'p')
    if not mkdir_ok then
        state.dir_error = 'mkdir failed: ' .. tostring(mkdir_err)
    end
    local loaded, load_err = load_global_entries(cfg.dir)
    state.global_entries = loaded
    state.last_load_error = load_err

    local function next_seq()
        state.seq = state.seq + 1
        return state.seq
    end

    -- Detach the caller's table via a JSON round-trip, which also
    -- proves the value is persistable. Returns nil + err otherwise.
    ---@param value any
    ---@return any? copy
    ---@return string? err
    local function detached_copy(value)
        local ok, text = pcall(vim.json.encode, value)
        if not ok or type(text) ~= 'string' then
            return nil, 'value is not JSON-encodable'
        end
        local dok, copy = pcall(vim.json.decode, text)
        if not dok then
            return nil, 'value did not survive a JSON round-trip'
        end
        return copy, nil
    end

    ---@param entries table<string, table>
    ---@param key string
    ---@return any? value
    local function get_entry(entries, key)
        if check_key(key) ~= true then
            return nil
        end
        local entry = entries[key]
        if entry == nil then
            state.misses = state.misses + 1
            return nil
        end
        if entry_expired(entry, os.time()) then
            entries[key] = nil
            state.misses = state.misses + 1
            return nil
        end
        entry.seq = next_seq()
        state.hits = state.hits + 1
        return entry.value
    end

    ---@param entries table<string, table>
    ---@param count_max integer
    ---@param key string
    ---@param value any
    ---@param ttl_s integer
    local function put_entry(entries, count_max, key, value, ttl_s)
        entries[key] = {
            value = value,
            stored_at = os.time(),
            ttl_s = ttl_s,
            seq = next_seq(),
        }
        state.evictions = state.evictions + evict_lru(entries, count_max)
    end

    ---@type AiTieredCache
    local cache = {}

    ---Store a long-lived entry, persisted to disk best-effort.
    ---@param key string
    ---@param value any must be JSON-encodable
    ---@param put_opts? AiTieredPutOpts
    ---@return boolean?
    ---@return string? err
    function cache.put_global(key, value, put_opts)
        local key_ok, key_err = check_key(key)
        if not key_ok then
            return nil, key_err
        end
        local copy, copy_err = detached_copy(value)
        if copy == nil then
            return nil, copy_err
        end
        local ttl_s = state.cfg.global_ttl_s
        if put_opts ~= nil then
            if type(put_opts) ~= 'table' then
                return nil, 'put_opts must be a table'
            end
            if put_opts.ttl_s ~= nil then
                ttl_s = put_opts.ttl_s
            end
        end
        local ttl_ok, ttl_err = check_integer(ttl_s, 'ttl_s')
        if not ttl_ok then
            return nil, ttl_err
        end
        put_entry(state.global_entries, state.cfg.global_count_max, key, copy, ttl_s)
        local persisted, persist_err = persist_global(state.cfg.dir, state.global_entries)
        if not persisted then
            -- Memory is authoritative; the miss only costs durability.
            state.last_persist_error = persist_err
        end
        return true, nil
    end

    ---Look up a long-lived entry. The returned value is a detached
    ---copy: mutating it never affects the cached entry (which would
    ---otherwise also poison the next disk persist).
    ---@param key string
    ---@return any value, or nil on miss/expiry/invalid key
    function cache.get_global(key)
        local value = get_entry(state.global_entries, key)
        if value == nil then
            return nil
        end
        -- Cannot fail: put_global only stores values that already
        -- survived a JSON round-trip. Fail closed anyway.
        local copy = detached_copy(value)
        if copy == nil then
            return nil
        end
        return copy
    end

    ---Store a short-lived, memory-only entry. The value is kept by
    ---reference (no JSON round-trip, so any Lua value is allowed);
    ---callers must not mutate it after storing.
    ---@param key string
    ---@param value any
    ---@return boolean?
    ---@return string? err
    function cache.put_local(key, value)
        local key_ok, key_err = check_key(key)
        if not key_ok then
            return nil, key_err
        end
        put_entry(state.local_entries, state.cfg.local_count_max, key, value, state.cfg.local_ttl_s)
        return true, nil
    end

    ---Look up a short-lived entry. Returns the live stored reference;
    ---mutating it mutates the cache.
    ---@param key string
    ---@return any value, or nil on miss/expiry/invalid key
    function cache.get_local(key)
        return get_entry(state.local_entries, key)
    end

    ---Bounded recompute of a local tail, the SWA Bounded Replay
    ---analog: rebuild_fn sees the live global snapshot plus the
    ---requested keys, and only those keys are rebuilt and stored.
    ---The result is approximate by design -- a cheap reconstruction
    ---of the tail, never a full context rebuild.
    ---@param keys string[] local keys to rebuild; at most replay_item_max
    ---@param rebuild_fn fun(global: table<string, any>, keys: string[]): table?
    ---@return table? rebuilt map of key -> value for the requested keys
    ---@return string? err
    function cache.replay(keys, rebuild_fn)
        if type(keys) ~= 'table' then
            return nil, 'keys must be an array of strings'
        end
        if #keys == 0 then
            return nil, 'keys must not be empty'
        end
        if #keys > state.cfg.replay_item_max then
            return nil, 'replay bound exceeded: at most ' .. state.cfg.replay_item_max .. ' keys'
        end
        for _, key in ipairs(keys) do
            local key_ok, key_err = check_key(key)
            if not key_ok then
                return nil, 'bad replay key: ' .. tostring(key_err)
            end
        end
        if type(rebuild_fn) ~= 'function' then
            return nil, 'rebuild_fn must be a function'
        end
        -- Snapshot live globals; drop expired ones as we go. Values
        -- are detached: rebuild_fn is caller code and must not be
        -- able to mutate live cache state through the snapshot it is
        -- handed (the corruption would persist to disk on next put).
        local now = os.time()
        local global = {}
        for key, entry in pairs(state.global_entries) do
            if entry_expired(entry, now) then
                state.global_entries[key] = nil
            else
                local copy = detached_copy(entry.value)
                if copy ~= nil then
                    global[key] = copy
                end
            end
        end
        local ok, rebuilt = pcall(rebuild_fn, global, keys)
        if not ok then
            return nil, 'rebuild_fn raised: ' .. tostring(rebuilt)
        end
        if type(rebuilt) ~= 'table' then
            return nil, 'rebuild_fn must return a table'
        end
        local out = {}
        for _, key in ipairs(keys) do
            local value = rebuilt[key]
            if value ~= nil then
                put_entry(state.local_entries, state.cfg.local_count_max, key, value, state.cfg.local_ttl_s)
                out[key] = value
            end
        end
        return out, nil
    end

    ---@return AiTieredStats
    function cache.stats()
        local global_count = 0
        for _ in pairs(state.global_entries) do
            global_count = global_count + 1
        end
        local local_count = 0
        for _ in pairs(state.local_entries) do
            local_count = local_count + 1
        end
        return {
            global_count = global_count,
            local_count = local_count,
            hits = state.hits,
            misses = state.misses,
            evictions = state.evictions,
            last_persist_error = state.last_persist_error,
            last_load_error = state.last_load_error,
            dir_error = state.dir_error,
        }
    end

    ---Drop expired entries from both tiers.
    ---@return integer pruned_count
    function cache.prune()
        local now = os.time()
        local pruned = 0
        for _, entries in ipairs({ state.global_entries, state.local_entries }) do
            for key, entry in pairs(entries) do
                if entry_expired(entry, now) then
                    entries[key] = nil
                    pruned = pruned + 1
                end
            end
        end
        return pruned
    end

    return cache, nil
end

return M
