--- Supply-chain guard — the "check the delivery list" rule.
---
--- Plain-language version: Neovim installs plugins from the internet, and it
--- writes down exactly which version of each plugin it installed in a
--- lockfile -- like a delivery list with tracking numbers. If a sneaky
--- program (or a careless update) swaps a plugin for a different version
--- without updating the list, the list and the real boxes no longer match.
--- This module reads the delivery list (nvim-pack-lock.json, written by
--- vim.pack) and checks every box on the shelf: is the installed copy really
--- the exact version (git commit) the list says it should be? It also checks
--- lazy-lock.json to make sure every plugin there is pinned to a specific
--- commit and not floating on a branch name. It never changes anything --
--- it only reads and reports.
---
--- Sources: `:h vim.pack` (lockfile at stdpath('data')/..., plugin layout),
--- vim.json.decode for lockfile parsing, `git rev-parse HEAD` for the
--- installed commit (run via security.rce argv form, never a shell string).
---@module 'security.supplychain'

local M = {}

local rce = require('security.rce')

local GIT_TIMEOUT_MS = 15000 -- bound on one `git rev-parse` call.
local PLUGIN_MAX = 512 -- hard cap on lockfile entries examined.
local READ_BYTES_MAX = 1048576 -- 1 MiB cap on a lockfile read.

---@class security.SupplyChainPackSection
---@field checked integer Number of plugin entries examined.
---@field desync { installed_rev: string, name: string, pinned_rev: string }[] Pinned rev differs from checkout.
---@field errors { err: string, name: string }[] Entries that could not be checked.
---@field missing string[] Lockfile entries with no installed checkout.
---@field path string Path that was read.
---@field present boolean Whether nvim-pack-lock.json was found and parsed.

---@class security.SupplyChainLazySection
---@field checked integer Number of plugin entries examined.
---@field errors { err: string, name: string }[] Lockfile read/parse failures (fail-closed).
---@field path string Path that was read.
---@field present boolean Whether lazy-lock.json was found and parsed.
---@field unpinned string[] Entries with no commit pin.

---@class security.SupplyChainReport
---@field lazy_lock security.SupplyChainLazySection
---@field ok boolean True when every present lockfile is fully in sync.
---@field pack_lock security.SupplyChainPackSection

---@class security.SupplyChainOptions
---@field lazy_lock_path? string Explicit lazy-lock.json path (overrides root).
---@field pack_dir? string Directory holding installed vim.pack checkouts (overrides the stdpath default).
---@field pack_lock_path? string Explicit nvim-pack-lock.json path (overrides root).
---@field root? string Config root holding the lockfiles (default: current working directory).

---The installed commit of a checkout directory, via argv-form git.
---@param dir string
---@return string|nil rev 40-hex commit, or nil with err.
---@return string|nil err
local function installed_rev(dir)
    local result, exec_err = rce.safe_exec({ 'git', '-C', dir, 'rev-parse', 'HEAD' }, {
        timeout_ms = GIT_TIMEOUT_MS,
    })
    if exec_err ~= nil then
        return nil, exec_err
    end
    assert(result ~= nil, 'safe_exec returned no error but no result')
    if result.code ~= 0 then
        return nil, 'git rev-parse exited with code ' .. result.code
    end
    local rev = (result.stdout or ''):match('^%s*(%x+)%s*$')
    if rev == nil or #rev ~= 40 then
        return nil, 'could not parse git rev-parse output'
    end
    return rev:lower(), nil
end

---Read and JSON-decode a file, bounded in size. Returns (decoded, nil, false)
---on success. A missing path (or a non-file) is not fatal -- it just means
---that package manager is not in use -- and returns (nil, err, true).
---Any other read failure (oversize, unreadable, malformed JSON) is a
---verification failure, never silent absence: it returns (nil, err, false)
---so the caller can record it as an error and fail closed. Bloating a
---lockfile past READ_BYTES_MAX must not silently disable the check.
---@param path string
---@return table|nil decoded
---@return string|nil err
---@return boolean absent True only when the file is simply not there.
local function read_json_file(path)
    local stat = vim.uv.fs_stat(path)
    if stat == nil then
        return nil, 'not found: ' .. path, true
    end
    if stat.type ~= 'file' then
        return nil, 'not a file: ' .. path, true
    end
    if stat.size > READ_BYTES_MAX then
        return nil, 'file too large: ' .. path, false
    end
    local handle, open_err = io.open(path, 'rb')
    if handle == nil then
        return nil, 'cannot open: ' .. path .. ' (' .. tostring(open_err) .. ')', false
    end
    local content = handle:read('*a')
    handle:close()
    if type(content) ~= 'string' then
        return nil, 'cannot read: ' .. path, false
    end
    local decode_ok, decoded = pcall(vim.json.decode, content)
    if not decode_ok or type(decoded) ~= 'table' then
        return nil, 'malformed JSON: ' .. path, false
    end
    return decoded, nil, false
end

---Deterministic key order: never rely on pairs() order in reports.
---Callers bound the examined entries at PLUGIN_MAX; this helper only sorts.
---@param t table
---@return string[] keys Sorted string keys of t.
local function sorted_keys(t)
    local keys = {}
    for key, _ in pairs(t) do
        if type(key) == 'string' then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys)
    return keys
end

---Every lazy-lock.json entry must pin a commit; a bare branch floats.
---@param lock_path string
---@return security.SupplyChainLazySection
local function check_lazy_lock(lock_path)
    ---@type security.SupplyChainLazySection
    local section = { checked = 0, errors = {}, path = lock_path, present = false, unpinned = {} }
    local decoded, read_err, absent = read_json_file(lock_path)
    if read_err ~= nil then
        if absent then
            return section
        end
        -- Fail closed: an oversize, unreadable, or malformed lockfile is a
        -- verification error, never silent absence.
        section.errors[#section.errors + 1] = { err = read_err, name = '<lockfile>' }
        return section
    end
    assert(decoded ~= nil, 'read_json_file returned no error but no table')
    section.present = true
    local names = sorted_keys(decoded)
    local examined = 0
    for _, name in ipairs(names) do
        if examined >= PLUGIN_MAX then
            break
        end
        examined = examined + 1
        local entry = decoded[name]
        local commit = type(entry) == 'table' and entry.commit or nil
        if type(commit) ~= 'string' or commit == '' then
            section.unpinned[#section.unpinned + 1] = name
        end
    end
    section.checked = examined
    return section
end

---Compare nvim-pack-lock.json pinned revs against installed checkouts.
---@param lock_path string
---@param pack_dir string
---@return security.SupplyChainPackSection
local function check_pack_lock(lock_path, pack_dir)
    ---@type security.SupplyChainPackSection
    local section = {
        checked = 0,
        desync = {},
        errors = {},
        missing = {},
        path = lock_path,
        present = false,
    }
    local decoded, read_err, absent = read_json_file(lock_path)
    if read_err ~= nil then
        if absent then
            return section
        end
        -- Fail closed: an oversize, unreadable, or malformed lockfile is a
        -- verification error, never silent absence.
        section.errors[#section.errors + 1] = { err = read_err, name = '<lockfile>' }
        return section
    end
    assert(decoded ~= nil, 'read_json_file returned no error but no table')
    local plugins = decoded.plugins
    if type(plugins) ~= 'table' then
        section.present = true
        section.errors[#section.errors + 1] = { err = 'missing "plugins" table', name = '<lockfile>' }
        return section
    end
    section.present = true
    local names = sorted_keys(plugins)
    local examined = 0
    for _, name in ipairs(names) do
        if examined >= PLUGIN_MAX then
            break
        end
        examined = examined + 1
        local entry = plugins[name]
        local pinned_rev = type(entry) == 'table' and entry.rev or nil
        if type(pinned_rev) ~= 'string' or pinned_rev == '' then
            section.errors[#section.errors + 1] = { err = 'no pinned rev in lockfile', name = name }
        else
            local dir = pack_dir .. '/' .. name
            if vim.uv.fs_stat(dir) == nil then
                section.missing[#section.missing + 1] = name
            else
                local rev, rev_err = installed_rev(dir)
                if rev_err ~= nil then
                    section.errors[#section.errors + 1] = { err = rev_err, name = name }
                elseif rev ~= nil and rev ~= pinned_rev:lower() then
                    section.desync[#section.desync + 1] = { installed_rev = rev, name = name, pinned_rev = pinned_rev }
                end
            end
        end
    end
    section.checked = examined
    return section
end

---Verify lockfile integrity. Read-only: never writes, installs, or updates.
---Catches the A1 finding class -- a checkout whose code no longer matches
---the pinned rev in the lockfile.
---@param opts? security.SupplyChainOptions
---@return security.SupplyChainReport report
function M.verify_lockfile(opts)
    opts = opts or {}
    local root = opts.root or vim.fn.getcwd()
    local pack_lock_path = opts.pack_lock_path or (root .. '/nvim-pack-lock.json')
    local lazy_lock_path = opts.lazy_lock_path or (root .. '/lazy-lock.json')
    local pack_dir = opts.pack_dir or (vim.fn.stdpath('data') .. '/site/pack/core/opt')

    local pack_section = check_pack_lock(pack_lock_path, pack_dir)
    local lazy_section = check_lazy_lock(lazy_lock_path)

    local ok = #pack_section.desync == 0
        and #pack_section.missing == 0
        and #pack_section.errors == 0
        and #lazy_section.unpinned == 0
        and #lazy_section.errors == 0
    return { lazy_lock = lazy_section, ok = ok, pack_lock = pack_section }
end

return M
