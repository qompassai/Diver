-- /qompassai/Diver/lua/ai/mcp/registry.lua
-- Qompass AI MCP Server Registry (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- CRUD over the MCP server registry: name -> {command, args, env, cwd,
-- enabled}. Persisted as JSON at stdpath('data')/ai/mcp/servers.json with
-- atomic tmp+rename writes and a bounded file size. Entries are validated
-- on load (a corrupt file is backed up and the registry starts empty --
-- never a crash) and re-validated before launch. No shell strings anywhere:
-- command is an absolute executable path, args is an argv array.

local M = {}

local REGISTRY_SUBDIR = 'ai/mcp'
local REGISTRY_FILENAME = 'servers.json'
local FILE_SIZE_BYTES_MAX = 256 * 1024
local ENTRY_COUNT_MAX = 128
local NAME_LENGTH_MAX = 64
local ARG_COUNT_MAX = 32
local ARG_LENGTH_MAX = 4096
local ENV_COUNT_MAX = 64
local ENV_VALUE_LENGTH_MAX = 8192

---@class McpServerEntry
---@field name string Registry key; letters, digits, dot, dash, underscore only.
---@field command string Absolute path to the server executable.
---@field args string[] argv elements; never a shell string.
---@field env table<string, string>? Extra environment variables for the server.
---@field cwd string? Working directory for the server process.
---@field enabled boolean Whether the server may be started.

---@class McpValidateOpts
---@field require_executable boolean? Default true. Load-time validation
---passes false so a temporarily missing binary does not drop the entry.

local test_data_dir = nil ---@type string?

---@return string
local function data_dir()
    if test_data_dir ~= nil then
        return test_data_dir
    end
    return vim.fn.stdpath('data') .. '/' .. REGISTRY_SUBDIR
end

---@return string
local function registry_path()
    return data_dir() .. '/' .. REGISTRY_FILENAME
end

---@param command string
---@return string
local function basename(command)
    local base = command:match('([^/]+)$')
    return base or command
end

local AUTO_FETCH_COMMANDS = { npx = true, uvx = true, bunx = true, pnpx = true, yarn = true }
local SHELL_COMMANDS = { sh = true, bash = true, zsh = true, fish = true }

---Warn about entries that can pull and run remote code or hide execution.
---These are warnings, not rejections: installing one needs explicit typed
---confirmation (see discovery.install_from_result).
---@param entry McpServerEntry
---@return string[] flags
function M.risk_flags(entry)
    assert(type(entry) == 'table', 'entry must be a table')
    local flags = {}
    local base = basename(entry.command)
    if AUTO_FETCH_COMMANDS[base] then
        flags[#flags + 1] = base .. ' auto-fetches and runs remote packages; pin a version'
    end
    if SHELL_COMMANDS[base] then
        flags[#flags + 1] = base .. ' is a shell wrapper; inspect exactly what it executes'
    end
    for _, arg in ipairs(entry.args) do
        if type(arg) == 'string' and arg:match('^https?://') then
            flags[#flags + 1] = 'argv contains a remote URL: ' .. arg:sub(1, 80)
            break
        end
    end
    return flags
end

---@param value any
---@param limit integer
---@return boolean
local function is_bounded_string(value, limit)
    return type(value) == 'string' and #value >= 1 and #value <= limit and value:find('%z') == nil
end

---@param entry any
---@param opts McpValidateOpts?
---@return boolean ok
---@return string? err
function M.validate(entry, opts)
    local require_executable = opts == nil or opts.require_executable ~= false
    if type(entry) ~= 'table' then
        return false, 'entry must be a table'
    end
    if not is_bounded_string(entry.name, NAME_LENGTH_MAX) then
        return false, 'name must be a 1..' .. NAME_LENGTH_MAX .. ' character string'
    end
    if entry.name:match('^[A-Za-z0-9._-]+$') == nil then
        return false, 'name may only contain letters, digits, dot, dash, underscore'
    end
    if not is_bounded_string(entry.command, ARG_LENGTH_MAX) then
        return false, 'command must be a non-empty path string'
    end
    if entry.command:sub(1, 1) ~= '/' then
        return false, 'command must be an absolute path, got: ' .. entry.command
    end
    if require_executable and vim.fn.executable(entry.command) ~= 1 then
        return false, 'command is not an executable file: ' .. entry.command
    end
    if type(entry.args) ~= 'table' then
        return false, 'args must be an argv array'
    end
    if #entry.args > ARG_COUNT_MAX then
        return false, 'args exceeds ' .. ARG_COUNT_MAX .. ' elements'
    end
    for index, arg in ipairs(entry.args) do
        if not is_bounded_string(arg, ARG_LENGTH_MAX) then
            return false, ('args[%d] too long (max %d)'):format(index, ARG_LENGTH_MAX)
        end
    end
    if entry.env ~= nil then
        if type(entry.env) ~= 'table' then
            return false, 'env must be a string->string table'
        end
        local count = 0
        for key, value in pairs(entry.env) do
            count = count + 1
            if count > ENV_COUNT_MAX then
                return false, 'env exceeds ' .. ENV_COUNT_MAX .. ' entries'
            end
            local key_ok = is_bounded_string(key, ARG_LENGTH_MAX)
            local value_ok = is_bounded_string(value, ENV_VALUE_LENGTH_MAX)
            if not key_ok or not value_ok then
                return false, 'env keys/values must be bounded strings'
            end
        end
    end
    if entry.cwd ~= nil then
        if not is_bounded_string(entry.cwd, ARG_LENGTH_MAX) or entry.cwd:sub(1, 1) ~= '/' then
            return false, 'cwd must be an absolute path'
        end
    end
    if type(entry.enabled) ~= 'boolean' then
        return false, 'enabled must be a boolean'
    end
    return true, nil
end

---@param path string
local function backup_corrupt(path)
    pcall(os.rename, path, path .. '.corrupt-' .. os.time())
end

local servers = {} ---@type table<string, McpServerEntry>
local loaded = false

---@param raw any
---@return McpServerEntry? entry
local function entry_from_decoded(raw)
    local ok, err = M.validate(raw, { require_executable = false })
    if not ok then
        return nil
    end
    assert(err == nil, 'validate returned false with no error')
    return {
        name = raw.name,
        command = raw.command,
        args = vim.deepcopy(raw.args),
        env = raw.env ~= nil and vim.deepcopy(raw.env) or nil,
        cwd = raw.cwd,
        enabled = raw.enabled,
    }
end

---Load the registry file once. A missing file means "no servers yet". A
---corrupt or oversized file is renamed aside and the registry starts empty.
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
    local text = file:read('*a')
    file:close()
    if type(text) ~= 'string' or text == '' then
        return
    end
    if #text > FILE_SIZE_BYTES_MAX then
        backup_corrupt(path)
        local msg = 'MCP registry exceeded size bound; backed up, starting empty'
        vim.notify(msg, vim.log.levels.WARN)
        return
    end
    local ok, decoded = pcall(vim.json.decode, text)
    if not ok or type(decoded) ~= 'table' or type(decoded.servers) ~= 'table' then
        backup_corrupt(path)
        vim.notify('MCP registry was corrupt; backed up and starting empty', vim.log.levels.WARN)
        return
    end
    local skipped = 0
    local count = 0
    for _, raw in ipairs(decoded.servers) do
        if count >= ENTRY_COUNT_MAX then
            break
        end
        local entry = entry_from_decoded(raw)
        if entry ~= nil then
            servers[entry.name] = entry
            count = count + 1
        else
            skipped = skipped + 1
        end
    end
    if skipped > 0 then
        vim.notify('MCP registry: skipped ' .. skipped .. ' invalid entries', vim.log.levels.WARN)
    end
end

---@return boolean ok
---@return string? err
local function save()
    local names = {}
    for name in pairs(servers) do
        names[#names + 1] = name
    end
    table.sort(names)
    local list = {}
    for _, name in ipairs(names) do
        list[#list + 1] = servers[name]
    end
    local text = vim.json.encode({ servers = list })
    vim.fn.mkdir(data_dir(), 'p')
    local path = registry_path()
    local tmp = path .. '.tmp'
    local file, file_err = io.open(tmp, 'w')
    if file == nil then
        return false, 'cannot write registry: ' .. tostring(file_err)
    end
    file:write(text)
    file:close()
    local renamed, rename_err = os.rename(tmp, path)
    if not renamed then
        return false, 'cannot replace registry: ' .. tostring(rename_err)
    end
    return true, nil
end

---Test-only hook: redirect the registry directory (e.g. to a temp dir).
---@param dir string
function M._test_set_data_dir(dir)
    assert(type(dir) == 'string' and dir ~= '', 'dir must be a non-empty string')
    test_data_dir = dir
    servers = {}
    loaded = false
end

---@param entry McpServerEntry
---@return boolean ok
---@return string? err
function M.add(entry)
    load()
    local valid, validation_err = M.validate(entry)
    if not valid then
        return false, validation_err
    end
    assert(validation_err == nil, 'validate returned false with no error')
    if servers[entry.name] ~= nil then
        return false, 'server already registered: ' .. entry.name
    end
    if vim.tbl_count(servers) >= ENTRY_COUNT_MAX then
        return false, 'registry is full (' .. ENTRY_COUNT_MAX .. ' servers)'
    end
    servers[entry.name] = {
        name = entry.name,
        command = entry.command,
        args = vim.deepcopy(entry.args),
        env = entry.env ~= nil and vim.deepcopy(entry.env) or nil,
        cwd = entry.cwd,
        enabled = entry.enabled,
    }
    return save()
end

---@param name string
---@return boolean ok
---@return string? err
function M.remove(name)
    load()
    if type(name) ~= 'string' or servers[name] == nil then
        return false, 'unknown server: ' .. tostring(name)
    end
    servers[name] = nil
    return save()
end

---@param name string
---@param enabled boolean
---@return boolean ok
---@return string? err
local function set_enabled(name, enabled)
    load()
    local entry = servers[name]
    if type(name) ~= 'string' or entry == nil then
        return false, 'unknown server: ' .. tostring(name)
    end
    entry.enabled = enabled
    return save()
end

---@param name string
---@return boolean ok
---@return string? err
function M.enable(name)
    return set_enabled(name, true)
end

---@param name string
---@return boolean ok
---@return string? err
function M.disable(name)
    return set_enabled(name, false)
end

---@param name string
---@return McpServerEntry?
function M.get(name)
    load()
    local entry = servers[name]
    if entry == nil then
        return nil
    end
    return vim.deepcopy(entry)
end

---@return McpServerEntry[] entries sorted by name
function M.list()
    load()
    local names = {}
    for name in pairs(servers) do
        names[#names + 1] = name
    end
    table.sort(names)
    local list = {}
    for _, name in ipairs(names) do
        list[#list + 1] = vim.deepcopy(servers[name])
    end
    return list
end

return M
