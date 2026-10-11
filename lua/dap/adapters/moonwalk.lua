-- #################################################################
-- lua/dap/adapters/moonwalk.lua
-- Qompass AI Diver Moonwalk DAP Adapter Descriptor
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

--- Declarative descriptor for the Moonwalk DAP executable (Lua).
---
--- Plain-language version: this file is Moonwalk's ID card for the adapter
--- registry -- one common DAP executable, thin editor-side wrapper. It says
--- which program to run, which files it debugs, how to check its version,
--- and the security rules it runs under (loopback-only networking, a short
--- allowlist of environment variables, secrets scrubbed from logs).
--- Register it with: `require('dap.registry').register(require('dap.adapters.moonwalk'))`.
---@module 'dap.adapters.moonwalk'

--- Environment variables Moonwalk may inherit; everything else is dropped.
---@type string[]
local ENV_ALLOWLIST = {
    'HOME',
    'LANG',
    'LC_ALL',
    'LC_CTYPE',
    'LUA_CPATH',
    'LUA_PATH',
    'MOONWALK_ARGS',
    'MOONWALK_PATH',
    'PATH',
    'TERM',
    'TMPDIR',
    'XDG_CACHE_HOME',
    'XDG_CONFIG_HOME',
    'XDG_DATA_HOME',
}

---@type string[]
local LOOPBACK_HOSTS = { '127.0.0.1', '::1', 'localhost' }

--- Subprocess bound for version/health probes, in milliseconds.
local PROBE_TIMEOUT_MS = 3000

--- Load the sibling security policy without crashing when it is absent.
---@return table|nil
local function adapter_policy()
    local ok, mod = pcall(require, 'security.adapter_policy')
    if ok and type(mod) == 'table' then
        return mod
    end
    return nil
end

--- True for a configured path that points at something executable.
---@param candidate any
---@return string|nil
local function as_executable(candidate)
    if type(candidate) ~= 'string' or candidate == '' then
        return nil
    end
    if vim.fn.executable(candidate) == 1 then
        return candidate
    end
    return nil
end

--- Filter an environment table through the security policy allowlist.
---@param env table<string, string>|nil
---@return table<string, string>|nil filtered, string|nil err
local function build_env(env)
    local policy = adapter_policy()
    if policy == nil then
        return nil, 'security.adapter_policy is unavailable'
    end
    return policy.filter_env(env or {}, ENV_ALLOWLIST)
end

--- Build `launch` request params for a Lua program.
---@param opts { program: string, cwd?: string, args?: string[], stop_on_entry?: boolean, env?: table<string,string> }
---@return table|nil params, string|nil err
local function build_launch(opts)
    if type(opts) ~= 'table' or type(opts.program) ~= 'string' or opts.program == '' then
        return nil, 'launch needs opts.program'
    end
    local env, env_err = build_env(opts.env)
    if env == nil then
        return nil, env_err
    end
    return {
        request = 'launch',
        program = opts.program,
        cwd = opts.cwd,
        args = opts.args,
        stopOnEntry = opts.stop_on_entry == true,
        env = env,
    },
        nil
end

--- Reject non-loopback hosts while the loopback-only policy is in force.
---@param host string|nil
---@return boolean ok, string? err
local function check_remote_host(host)
    if host == nil or host == '' then
        return true
    end
    for _, loopback in ipairs(LOOPBACK_HOSTS) do
        if host == loopback then
            return true
        end
    end
    return false, 'remote host blocked by loopback-only policy: ' .. host
end

--- Resolve the Moonwalk executable. Order: vim.g.moonwalk_path, then
--- require('dap.moonwalk').path, then PATH lookup of 'moonwalk',
--- then PATH lookup of 'lua-debug'. No hardcoded home directories.
---@return string|nil
local function discover()
    local from_g = as_executable(vim.g.moonwalk_path)
    if from_g then
        return from_g
    end
    local ok, mod = pcall(require, 'dap.moonwalk')
    if ok and type(mod) == 'table' then
        local from_config = as_executable(mod.path)
        if from_config then
            return from_config
        end
    end
    for _, name in ipairs({ 'moonwalk', 'lua-debug' }) do
        local found = vim.fn.exepath(name)
        if found ~= '' then
            return found
        end
    end
    return nil
end

--- Scrub secrets from a string before it is logged or displayed.
---@param s string
---@return string|nil redacted, string|nil err
local function redact(s)
    local policy = adapter_policy()
    if policy == nil then
        return nil, 'security.adapter_policy is unavailable'
    end
    return policy.redact(s)
end

--- Run the executable with its version flag, bounded by PROBE_TIMEOUT_MS.
---@param exe string resolved executable path
---@return string|nil version, string|nil err
local function version_probe(exe)
    local ok, result = pcall(vim.system, { exe, '--version' }, { timeout = PROBE_TIMEOUT_MS })
    if not ok then
        return nil, 'could not spawn version probe: ' .. tostring(result)
    end
    ---@cast result vim.SystemObj
    local completed = result:wait(PROBE_TIMEOUT_MS + 1000)
    if not completed or completed.code ~= 0 then
        return nil, string.format('version probe exited %s', tostring(completed.code))
    end
    local first_line = tostring(completed.stdout or ''):match('^([^\r\n]+)') or ''
    local version = first_line:match('(%d+%.%d+%.?%d*)')
    if not version then
        return nil, 'unparseable version output: ' .. first_line
    end
    return version, nil
end

--- Liveness check: the process spawns and exits 0 on its version flag.
---@param exe string resolved executable path
---@return boolean
local function smoke_check(exe)
    local version, _ = version_probe(exe)
    return version ~= nil
end

--- Build `attach` request params (local process id or loopback socket).
---@param opts { process_id?: integer, host?: string, port?: integer }
---@return table|nil params, string|nil err
local function build_attach(opts)
    if type(opts) ~= 'table' then
        return nil, 'attach needs an opts table'
    end
    local host_ok, host_err = check_remote_host(opts.host)
    if not host_ok then
        return nil, host_err
    end
    if opts.port ~= nil then
        return {
            request = 'attach',
            host = opts.host or '127.0.0.1',
            port = opts.port,
        },
            nil
    end
    if type(opts.process_id) ~= 'number' then
        return nil, 'attach needs opts.process_id or opts.port'
    end
    return { request = 'attach', processId = opts.process_id }, nil
end

---@class dap.MoonwalkDescriptor: dap.RegistryDescriptor
local descriptor = {
    attach = build_attach,
    -- No hard expectations: the lifecycle tracker records whatever the
    -- initialize response negotiates; mismatches surface there, not here.
    capability_expectations = {},
    discovery = discover,
    executable = { args = { '--stdio' }, names = { 'moonwalk', 'lua-debug' } },
    filetypes = { 'lua' },
    health_checks = {
        smoke = smoke_check,
        version = function(exe)
            local version, _ = version_probe(exe)
            return version ~= nil
        end,
    },
    id = 'moonwalk',
    launch = build_launch,
    remote = {
        allow_remote_host = false,
        check_host = check_remote_host,
        default_host = '127.0.0.1',
    },
    security = {
        build_env = build_env,
        env_allowlist = ENV_ALLOWLIST,
        loopback_only = true,
        redact = redact,
        redact_secrets = true,
    },
    -- Moonwalk reports real source paths; no client/server remapping needed.
    source_mapping = {},
    transports = { 'stdio', 'socket' },
    -- No minimum known yet: Moonwalk has no public release to pin against.
    -- Any successfully probed version satisfies the policy for now.
    version_policy = { minimum = nil, scheme = 'semver' },
    version_probe = version_probe,
}

return descriptor
