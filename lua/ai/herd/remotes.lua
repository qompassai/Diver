-- /qompassai/Diver/lua/ai/herd/remotes.lua
-- Qompass AI Herd Remote Machines (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- v1 scope: a registry of SSH machines (target -> diver checkout path)
-- plus one-shot queries against a remote machine's own herd socket API.
-- Each query runs the standalone lua/ai/herd/remote_query.lua on the far
-- end over ssh (`nvim --headless --noplugin -l`); the remote must run the
-- same diver checkout with Neovim installed and its herd daemon up. The
-- ssh target is passed as a single argv element, never interpolated into
-- a shell string.
--
-- Honestly NOT done here (v1):
--   - No persistent tunneling daemon: every query spawns a fresh ssh.
--   - No automatic discovery of the remote diver checkout path; the
--     operator registers it explicitly with M.add.
--   - No remote file sync and no command execution beyond the herd
--     socket API; queries are one-shot, never multiplexed.

local M = {}

local REGISTRY_SUBDIR = 'herd'
local REGISTRY_FILENAME = 'remotes.json'
local DATA_DIR_MODE = '0700'
local FILE_SIZE_BYTES_MAX = 65536
local MACHINE_COUNT_MAX = 32
local TARGET_LENGTH_MAX = 256
local DIVER_PATH_LENGTH_MAX = 4096
local JSON_BYTES_MAX = 65536
local SSH_TIMEOUT_MS = 30000
local SSH_ERROR_TEXT_MAX = 500

-- 'host' or 'user@host'. Anchored with no spaces or shell
-- metacharacters, so a validated target is safe to hand to ssh as one
-- argv element. Note: written with an optional literal '@' between two
-- required runs because Lua patterns cannot quantify a capture group --
-- a '(...)?' shape would silently never match.
local TARGET_PATTERN = '^[A-Za-z0-9._-]+@?[A-Za-z0-9._-]+$'

-- Absolute remote checkout paths. OpenSSH joins the post-host ssh
-- argv into one string the REMOTE login shell interprets, so a
-- registry path with quotes, semicolons, whitespace, or other shell
-- metacharacters would become remote command injection (proven
-- 2026-09-26: "/x';touch /tmp/RCE_PROOF;echo '"). Only alphanumerics
-- plus dot, dash, underscore, and slash survive; '..' segments are
-- rejected separately.
local DIVER_PATH_PATTERN = '^[A-Za-z0-9%._/-]+$'

---@class HerdRemoteEntry
---@field target string SSH target: 'host' or 'user@host'.
---@field diver_path string? Absolute path to the diver checkout on the
---remote machine. Required by M.query.

local machines = {} ---@type table<string, HerdRemoteEntry>
local loaded = false

---@return string
local function data_dir()
    return vim.fn.stdpath('data') .. '/' .. REGISTRY_SUBDIR
end

---@return string
local function registry_path()
    return data_dir() .. '/' .. REGISTRY_FILENAME
end

---Ensure a directory exists with owner-only permissions, tightening
---pre-existing directories: vim.fn.mkdir() applies the mode only when
---it creates the directory, so a loose pre-existing dir would
---otherwise keep its permissions while we claim 0700.
---@param dir string
---@return boolean ok
---@return string? err
local function ensure_private_dir(dir)
    local mkdir_ok, made = pcall(vim.fn.mkdir, dir, 'p', DATA_DIR_MODE)
    if not mkdir_ok or made ~= 1 then
        return false, 'cannot create directory: ' .. dir
    end
    local stat = vim.uv.fs_stat(dir)
    if stat == nil or stat.type ~= 'directory' then
        return false, 'not a directory: ' .. dir
    end
    -- stat.mode is st_mode: mask to the permission bits and tighten
    -- when any group/other bit is set. 448 is 0o700.
    local perms = (stat.mode or 511) % 512
    if perms % 64 ~= 0 then
        local chmod_ok, chmod_err = pcall(vim.uv.fs_chmod, dir, 448)
        if not chmod_ok then
            return false, 'cannot tighten permissions on ' .. dir .. ': ' .. tostring(chmod_err)
        end
    end
    return true, nil
end

---@param path string
local function backup_corrupt(path)
    pcall(os.rename, path, path .. '.corrupt-' .. os.time())
end

---@param target any
---@return boolean ok
---@return string? err
local function check_target(target)
    if type(target) ~= 'string' or #target > TARGET_LENGTH_MAX then
        return false, 'invalid ssh target'
    end
    if target:match(TARGET_PATTERN) == nil then
        return false, 'invalid ssh target'
    end
    return true, nil
end

---@param path any
---@return boolean ok
---@return string? err
local function check_diver_path(path)
    if type(path) ~= 'string' or path == '' then
        return false, 'diver_path must be a non-empty string'
    end
    if #path > DIVER_PATH_LENGTH_MAX then
        return false, 'diver_path too long'
    end
    if path:sub(1, 1) ~= '/' then
        return false, 'diver_path must be absolute'
    end
    if path:find('%z') ~= nil then
        return false, 'diver_path must not contain NUL'
    end
    if path:match(DIVER_PATH_PATTERN) == nil then
        return false, 'diver_path has unsafe characters'
    end
    for segment in path:gmatch('[^/]+') do
        if segment == '..' then
            return false, 'diver_path must not contain ".."'
        end
    end
    return true, nil
end

---@param raw any
---@return HerdRemoteEntry? entry
local function entry_from_decoded(raw)
    if type(raw) ~= 'table' then
        return nil
    end
    local target_ok = check_target(raw.target)
    if not target_ok then
        return nil
    end
    local entry = { target = raw.target }
    if raw.diver_path ~= nil then
        -- Re-validate on load: the registry file is hand-editable, so
        -- a persisted path is untrusted input, not a stored fact.
        local path_ok, path_err = check_diver_path(raw.diver_path)
        if not path_ok then
            return nil
        end
        assert(path_err == nil, 'check_diver_path failed without an error')
        entry.diver_path = raw.diver_path
    end
    return entry
end

---Load the registry file once. A missing file means "no machines yet".
---A corrupt or oversized file is renamed aside and the registry starts
---empty rather than crashing.
local function load()
    if loaded then
        return
    end
    loaded = true
    local path = registry_path()
    local file = io.open(path, 'r')
    if file == nil then
        return
    end
    local text = file:read(FILE_SIZE_BYTES_MAX + 1)
    file:close()
    if type(text) ~= 'string' or text == '' then
        return
    end
    if #text > FILE_SIZE_BYTES_MAX then
        backup_corrupt(path)
        local msg = 'herd remotes: registry too large; backed up, empty'
        vim.notify(msg, vim.log.levels.WARN)
        return
    end
    local ok, decoded = pcall(vim.json.decode, text)
    local shape_ok = ok and type(decoded) == 'table'
    shape_ok = shape_ok and type(decoded.machines) == 'table'
    if not shape_ok then
        backup_corrupt(path)
        local msg = 'herd remotes: registry corrupt; backed up, empty'
        vim.notify(msg, vim.log.levels.WARN)
        return
    end
    local count = 0
    local skipped = 0
    for _, raw in ipairs(decoded.machines) do
        if count >= MACHINE_COUNT_MAX then
            skipped = skipped + 1
        else
            local entry = entry_from_decoded(raw)
            if entry == nil or machines[entry.target] ~= nil then
                skipped = skipped + 1
            else
                machines[entry.target] = entry
                count = count + 1
            end
        end
    end
    if skipped > 0 then
        local msg = 'herd remotes: skipped ' .. skipped .. ' entries'
        vim.notify(msg, vim.log.levels.WARN)
    end
end

---Persist the registry atomically: write a temp file in the same
---directory, then rename over the registry file.
---@return boolean ok
---@return string? err
local function save()
    local targets = {}
    for target in pairs(machines) do
        targets[#targets + 1] = target
    end
    table.sort(targets)
    local list = {}
    for _, target in ipairs(targets) do
        list[#list + 1] = machines[target]
    end
    local encoded_ok, text = pcall(vim.json.encode, { machines = list })
    if not encoded_ok or type(text) ~= 'string' then
        return false, 'cannot encode registry'
    end
    local dir_ok, dir_err = ensure_private_dir(data_dir())
    if not dir_ok then
        return false, dir_err
    end
    local path = registry_path()
    local tmp_path = path .. '.tmp'
    local file, file_err = io.open(tmp_path, 'w')
    if file == nil then
        return false, 'cannot write registry: ' .. tostring(file_err)
    end
    file:write(text)
    file:close()
    local renamed, rename_err = os.rename(tmp_path, path)
    if not renamed then
        return false, 'cannot replace registry: ' .. tostring(rename_err)
    end
    return true, nil
end

---Register a machine. diver_path is validated here, not just
---asserted: it reaches a remote shell via ssh, so a bad path is a
---rejected registration, never a crash or an injection.
---@param target string SSH target: 'host' or 'user@host'.
---@param diver_path string? Absolute path to the diver checkout on the
---remote; required later by M.query.
---@return true|nil ok
---@return string? err
function M.add(target, diver_path)
    local target_ok, target_err = check_target(target)
    if not target_ok then
        return nil, target_err
    end
    assert(target_err == nil, 'check_target failed without an error')
    if diver_path ~= nil then
        local path_ok, path_err = check_diver_path(diver_path)
        if not path_ok then
            return nil, path_err
        end
        assert(path_err == nil, 'check_diver_path failed without an error')
    end
    load()
    if machines[target] ~= nil then
        return nil, 'already registered'
    end
    if vim.tbl_count(machines) >= MACHINE_COUNT_MAX then
        return nil, 'registry is full (' .. MACHINE_COUNT_MAX .. ' machines)'
    end
    machines[target] = { target = target, diver_path = diver_path }
    local saved, save_err = save()
    if not saved then
        machines[target] = nil
        return nil, save_err
    end
    return true
end

---Remove a machine from the registry.
---@param target string SSH target: 'host' or 'user@host'.
---@return true|nil ok
---@return string? err
function M.remove(target)
    local target_ok, target_err = check_target(target)
    if not target_ok then
        return nil, target_err
    end
    assert(target_err == nil, 'check_target failed without an error')
    load()
    local entry = machines[target]
    if entry == nil then
        return nil, 'unknown machine'
    end
    machines[target] = nil
    local saved, save_err = save()
    if not saved then
        machines[target] = entry
        return nil, save_err
    end
    return true
end

---List registered machines, sorted by target for determinism. Returns
---fresh tables so callers cannot mutate the registry.
---@return HerdRemoteEntry[] entries
function M.list()
    load()
    local targets = {}
    for target in pairs(machines) do
        targets[#targets + 1] = target
    end
    table.sort(targets)
    local list = {}
    for _, target in ipairs(targets) do
        local entry = machines[target]
        list[#list + 1] = {
            target = entry.target,
            diver_path = entry.diver_path,
        }
    end
    return list
end

---Query a remote machine's own herd socket API over ssh. Blocks up to
---SSH_TIMEOUT_MS. The target is one argv element to ssh; the request is
---JSON-encoded and piped as a single stdin line to remote_query.lua.
---@param target string SSH target, must be registered with a diver_path.
---@param request table Request with a string `cmd` field.
---@return table? response Decoded JSON response table from the remote.
---@return string? err
function M.query(target, request)
    local target_ok, target_err = check_target(target)
    if not target_ok then
        return nil, target_err
    end
    assert(target_err == nil, 'check_target failed without an error')
    if type(request) ~= 'table' then
        return nil, 'request must be a table'
    end
    if type(request.cmd) ~= 'string' then
        return nil, 'request.cmd must be a string'
    end
    load()
    local entry = machines[target]
    if entry == nil then
        return nil, 'unknown machine'
    end
    if entry.diver_path == nil then
        return nil, 'no diver_path configured for machine ' .. target
    end
    local encoded_ok, json = pcall(vim.json.encode, request)
    if not encoded_ok or type(json) ~= 'string' then
        return nil, 'request is not JSON-encodable'
    end
    if #json > JSON_BYTES_MAX then
        return nil, 'request exceeds 65536 bytes'
    end
    local script = entry.diver_path .. '/lua/ai/herd/remote_query.lua'
    local argv = {
        'ssh',
        target,
        '--',
        'nvim',
        '--headless',
        '--noplugin',
        '-l',
        script,
    }
    local spawn_ok, sysobj = pcall(vim.system, argv, {
        stdin = json .. '\n',
        timeout = SSH_TIMEOUT_MS,
    })
    if not spawn_ok then
        local detail = tostring(sysobj):sub(1, SSH_ERROR_TEXT_MAX)
        return nil, 'ssh query failed: ' .. detail
    end
    local completed = sysobj:wait()
    if completed.code ~= 0 or completed.signal ~= 0 then
        local detail = 'exit ' .. completed.code
        detail = detail .. ', signal ' .. completed.signal
        local stderr = vim.trim(completed.stderr or '')
        if stderr ~= '' then
            detail = detail .. ': ' .. stderr
        end
        local err_detail = detail:sub(1, SSH_ERROR_TEXT_MAX)
        return nil, 'ssh query failed: ' .. err_detail
    end
    local stdout = completed.stdout or ''
    if #stdout > JSON_BYTES_MAX then
        return nil, 'response exceeds 65536 bytes'
    end
    local decoded_ok, response = pcall(vim.json.decode, stdout)
    if not decoded_ok or type(response) ~= 'table' then
        return nil, 'bad response from remote'
    end
    return response
end

return M
