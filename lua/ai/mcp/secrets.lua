-- /qompassai/Diver/lua/ai/mcp/secrets.lua
-- Qompass AI MCP Secret Resolution (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
--
-- Secret *references* for MCP server declarations. A declaration names the
-- environment variables a server needs and where to find each value -- never
-- the value itself. Values are resolved at spawn time, live only in the
-- child process environment, and are never written to disk, logs, or
-- notifications. Error messages name the server, variable, and provider;
-- they never include the value.
--
-- Providers:
--   pass     { provider = 'pass', path = 'github/mcp-token' }
--            runs `pass show <path>`; the first stdout line is the secret.
--   env      { provider = 'env', path = 'GITHUB_TOKEN' }
--            reads the named process environment variable.
--   command  { provider = 'command', argv = { '/usr/bin/pass', 'show', 'x' } }
--            runs argv directly (no shell); the first stdout line is the secret.
--
-- Honest limitation: resolved values reach the child via environment
-- variables, which are briefly visible to other local processes via /proc.
-- This keeps secrets out of files and logs; it does not hide them from root
-- or from the same user on this machine.

local M = {}

local SECRET_COUNT_MAX = 16
local SECRET_VALUE_MAX = 8192
local SECRET_PATH_MAX = 512
local ARG_LENGTH_MAX = 4096
local RESOLVE_TIMEOUT_MS = 10000

---@class McpSecretRef
---@field provider string 'pass' | 'env' | 'command'
---@field path string pass entry path or environment variable name
---@field argv string[]? command provider only: argv array, no shell

local VALID_PROVIDERS = { pass = true, env = true, command = true }

---@param value any
---@param limit integer
---@return boolean
local function is_bounded_string(value, limit)
    return type(value) == 'string' and #value >= 1 and #value <= limit and value:find('%z') == nil
end

---@param ref any
---@return boolean ok
---@return string? err
local function validate_ref(ref)
    if type(ref) ~= 'table' then
        return false, 'secret ref must be a table'
    end
    if VALID_PROVIDERS[ref.provider] ~= true then
        return false, "secret provider must be 'pass', 'env', or 'command'"
    end
    if ref.provider == 'command' then
        if type(ref.argv) ~= 'table' or #ref.argv < 1 then
            return false, 'command provider needs a non-empty argv array'
        end
        for index, arg in ipairs(ref.argv) do
            if not is_bounded_string(arg, ARG_LENGTH_MAX) then
                return false, ('command argv[%d] must be a 1..%d character string'):format(index, ARG_LENGTH_MAX)
            end
        end
        if ref.argv[1]:sub(1, 1) ~= '/' then
            return false, 'command argv[1] must be an absolute path'
        end
    else
        if not is_bounded_string(ref.path, SECRET_PATH_MAX) then
            return false, ('secret path must be a 1..%d character string'):format(SECRET_PATH_MAX)
        end
        if ref.path:sub(1, 1) == '-' then
            return false, 'secret path must not start with a dash'
        end
    end
    return true, nil
end

---@param secrets any
---@return boolean ok
---@return string? err
function M.validate_refs(secrets)
    if secrets == nil then
        return true, nil
    end
    if type(secrets) ~= 'table' then
        return false, 'secrets must be a variable-name -> ref table'
    end
    local count = 0
    for var, ref in pairs(secrets) do
        count = count + 1
        if count > SECRET_COUNT_MAX then
            return false, 'secrets exceeds ' .. SECRET_COUNT_MAX .. ' entries'
        end
        if not is_bounded_string(var, 128) or var:match('^[A-Za-z_][A-Za-z0-9_]*$') == nil then
            return false, 'secret variable names must look like ENV_VAR names'
        end
        local ok, err = validate_ref(ref)
        if not ok then
            return false, var .. ': ' .. err
        end
    end
    return true, nil
end

---@param argv string[]
---@return string? value first stdout line, trimmed
---@return string? err never includes command output
local function run_capture(argv)
    local completed = vim.system(argv, { text = true, timeout = RESOLVE_TIMEOUT_MS, stderr = false }):wait()
    if completed.code ~= 0 then
        return nil, 'exited with code ' .. tostring(completed.code)
    end
    local first = (completed.stdout or ''):match('([^\r\n]*)') or ''
    first = first:gsub('^%s+', ''):gsub('%s+$', '')
    if first == '' then
        return nil, 'produced no output'
    end
    if #first > SECRET_VALUE_MAX then
        return nil, 'secret exceeds max length'
    end
    return first, nil
end

---@param entry table MCP server entry with optional secrets refs
---@return table? resolved variable name -> value
---@return string? err names server/variable/provider, never the value
function M.resolve(entry)
    local refs = entry.secrets
    if refs == nil then
        return {}, nil
    end
    local valid, verr = M.validate_refs(refs)
    if not valid then
        return nil, 'invalid secret refs for server ' .. tostring(entry.name) .. ': ' .. verr
    end
    local resolved = {}
    for var, ref in pairs(refs) do
        local value, err
        if ref.provider == 'env' then
            value = vim.env[ref.path]
            if type(value) ~= 'string' or value == '' then
                err = 'environment variable ' .. ref.path .. ' is not set'
            end
        elseif ref.provider == 'pass' then
            value, err = run_capture({ 'pass', 'show', ref.path })
        else -- command
            value, err = run_capture(ref.argv)
        end
        if err ~= nil then
            return nil,
                ('server %s: cannot resolve secret %s (%s provider): %s'):format(
                    tostring(entry.name),
                    var,
                    ref.provider,
                    err
                )
        end
        resolved[var] = value
    end
    return resolved, nil
end

return M
