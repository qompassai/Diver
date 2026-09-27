-- #################################################################
-- ~/workspace/repos/diver/lua/dap/integrations/moonwalk.lua
-- Qompass AI Diver Native Moonwalk DAP Integration
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
---Thin Moonwalk DAP integration for Diver: executable resolution, launch and
---attach configuration builders honoring the security baseline. Presentation
---only: returns plain nvim-dap-compatible configuration tables and keeps no
---orchestration state.
---@source https://github.com/qompassai/diver

local fn = vim.fn

local M = {}

local SOURCE = 'dap-moonwalk'

---@type string
local LOOPBACK = '127.0.0.1'

---@type integer
local DEFAULT_ATTACH_PORT = 9966

---@type string[]
---Conservative inherited-environment allowlist used only when the
---`security.adapter_policy` module is unavailable.
local SAFE_ENV_KEYS = {
    'HOME',
    'LANG',
    'LC_ALL',
    'LUA_CPATH',
    'LUA_PATH',
    'MOONWALK_ROOT',
    'PATH',
    'TERM',
    'TMPDIR',
    'XDG_RUNTIME_DIR',
}

---@type string[]
---Key-name fragments that mark a value as secret for redaction. Lua patterns
---have no alternation, so fragments are matched one at a time.
local SECRET_KEY_FRAGMENTS = {
    'TOKEN',
    'SECRET',
    'PASSWORD',
    'PASSWD',
    'API_KEY',
    'API-KEY',
    'AUTH',
    'CREDENTIAL',
    'PRIVATE',
}

---@param message string
---@param level? integer
local function notify(message, level)
    vim.notify(('[%s] %s'):format(SOURCE, message), level or vim.log.levels.INFO)
end

---@param value unknown
---@return boolean
local function nonempty_string(value)
    return type(value) == 'string' and value ~= ''
end

---@param path string
---@return boolean
local function executable(path)
    return nonempty_string(path) and fn.executable(path) == 1
end

---@return table?
---The optional `security.adapter_policy` module, or nil when it is not
---installed. Callers must fall back to the conservative builtin policy.
local function adapter_policy()
    local ok, policy = pcall(require, 'security.adapter_policy')

    if ok and type(policy) == 'table' then
        return policy
    end

    return nil
end

---@param key string
---@return boolean
---True when the key name marks its value as secret.
local function secret_key(key)
    local upper = key:upper()

    for index = 1, #SECRET_KEY_FRAGMENTS do
        if upper:find(SECRET_KEY_FRAGMENTS[index], 1, true) ~= nil then
            return true
        end
    end

    return false
end

---@param key string
---@param value string
---@return string
---Render one `KEY=value` pair with secret-looking values redacted. Prefers
---`security.adapter_policy.redact`, which understands `KEY=value` shapes;
---falls back to the builtin fragment list when the module is unavailable.
local function redact_kv(key, value)
    local policy = adapter_policy()

    if policy ~= nil and type(policy.redact) == 'function' then
        local ok, cleaned = pcall(policy.redact, key .. '=' .. value)

        if ok and type(cleaned) == 'string' then
            return cleaned
        end
    end

    if secret_key(key) then
        return key .. '=[REDACTED]'
    end

    return key .. '=' .. value
end

---@param env table<string,string>
---@return table<string,string>
---Filter an environment table through the adapter security policy. Prefers
---`security.adapter_policy.filter_env` with `default_allowlist()`; falls
---back to the conservative builtin allowlist when that module is missing or
---its call fails.
local function filter_env(env)
    local policy = adapter_policy()

    if policy ~= nil and type(policy.filter_env) == 'function' and type(policy.default_allowlist) == 'function' then
        local ok, allowlist = pcall(policy.default_allowlist)

        if ok and type(allowlist) == 'table' then
            local fok, filtered, ferr = pcall(policy.filter_env, env, allowlist)

            if fok and type(filtered) == 'table' then
                return filtered
            end

            notify(
                ('adapter_policy.filter_env failed (%s); using builtin allowlist'):format(tostring(ferr)),
                vim.log.levels.WARN
            )
        end
    end

    local out = {}

    for index = 1, #SAFE_ENV_KEYS do
        local key = SAFE_ENV_KEYS[index]
        local value = env[key]

        if type(value) == 'string' then
            out[key] = value
        end
    end

    return out
end

---@param env table<string,string>
---@return string
---One-line, secret-redacted summary of an environment table for logging.
local function describe_env(env)
    local parts = {}

    for key, value in pairs(env) do
        parts[#parts + 1] = redact_kv(key, tostring(value))
    end

    table.sort(parts)
    return table.concat(parts, ' ')
end

---@param opts? table
---@return string?, string?
---Resolve the Moonwalk adapter executable. Order: `vim.g.moonwalk_path`,
---then `opts.path`, then `exepath('moonwalk')`, then `exepath('lua-debug')`.
function M.resolve_executable(opts)
    opts = opts or {}

    local g_path = vim.g.moonwalk_path

    if executable(g_path) then
        return g_path, nil
    end

    if executable(opts.path) then
        return opts.path, nil
    end

    for _, name in ipairs({ 'moonwalk', 'lua-debug' }) do
        local found = fn.exepath(name)

        if executable(found) then
            return found, nil
        end
    end

    return nil, 'no moonwalk executable: set vim.g.moonwalk_path or install moonwalk/lua-debug'
end

---@param config table
---@return string
---Redacted one-line summary of a DAP configuration, safe to log.
function M.describe(config)
    local parts = {
        ('type=%s'):format(tostring(config.type)),
        ('request=%s'):format(tostring(config.request)),
        ('name=%s'):format(tostring(config.name)),
    }

    if config.program ~= nil then
        parts[#parts + 1] = ('program=%s'):format(tostring(config.program))
    end

    if config.env ~= nil and type(config.env) == 'table' then
        parts[#parts + 1] = ('env={%s}'):format(describe_env(config.env))
    end

    return table.concat(parts, ' ')
end

---@param opts? table
---@return table?, string?
---Build a plain nvim-dap-compatible launch configuration. Loopback-only by
---construction; the child environment is filtered through the adapter
---security policy.
function M.launch_config(opts)
    opts = opts or {}

    local adapter, resolve_err = M.resolve_executable(opts)

    if adapter == nil then
        return nil, resolve_err
    end

    local program = opts.program

    if not nonempty_string(program) then
        return nil, 'launch requires opts.program'
    end

    local env = filter_env(opts.env or {})

    ---@type table
    local config = {
        type = 'moonwalk',
        request = 'launch',
        name = opts.name or 'Moonwalk: Launch',
        program = program,
        cwd = opts.cwd or fn.getcwd(),
        args = opts.args or {},
        env = env,
        adapter_command = adapter,
    }

    notify(M.describe(config), vim.log.levels.DEBUG)
    return config, nil
end

---@param opts? table
---@return table?, string?
---Build a plain nvim-dap-compatible attach configuration. The adapter
---endpoint is loopback-only (`127.0.0.1`); `opts.port` selects the port.
function M.attach_config(opts)
    opts = opts or {}

    local adapter, resolve_err = M.resolve_executable(opts)

    if adapter == nil then
        return nil, resolve_err
    end

    local port = opts.port or DEFAULT_ATTACH_PORT

    if type(port) ~= 'number' or port < 1 or port > 65535 then
        return nil, 'attach requires opts.port in 1..65535'
    end

    local env = filter_env(opts.env or {})

    ---@type table
    local config = {
        type = 'moonwalk',
        request = 'attach',
        name = opts.name or 'Moonwalk: Attach',
        host = LOOPBACK,
        port = port,
        env = env,
        adapter_command = adapter,
    }

    notify(M.describe(config), vim.log.levels.DEBUG)
    return config, nil
end

return M
