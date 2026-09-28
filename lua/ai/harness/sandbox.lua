-- /qompassai/diver/lua/ai/harness/sandbox.lua
-- Qompass AI Agent Harness: execution profiles (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Execution profiles for untrusted tools and coding agents. The Neovim
-- process coordinates agents; it is not their security boundary. Profiles
-- describe workspace mounts, network mode, environment allowlists, and
-- resource limits. No policy is embedded here: profiles constrain *how*
-- something runs, policy decides *whether* it runs.

local M = {}

local ARGV_MAX = 128
local ARG_BYTES_MAX = 4096

---@class AiHarnessSandboxProfile
---@field name string
---@field workspace_mode 'none'|'read-only'|'read-write'
---@field path_roots string[]
---@field network 'none'|'loopback'|'allowlist'|'unrestricted'
---@field env_allowlist string[]
---@field limits table<string, integer>
---@field tmp_separate boolean

---@type table<string, AiHarnessSandboxProfile>
M.PROFILES = {
    none = {
        name = 'none',
        workspace_mode = 'none',
        path_roots = {},
        network = 'none',
        env_allowlist = { 'PATH', 'HOME', 'LANG', 'LC_ALL', 'TERM' },
        limits = {
            cpu_ms = 30000,
            memory_bytes = 268435456,
            procs = 16,
            file_bytes = 10485760,
            wall_ms = 60000,
        },
        tmp_separate = true,
    },
    readonly = {
        name = 'readonly',
        workspace_mode = 'read-only',
        path_roots = {},
        network = 'none',
        env_allowlist = { 'PATH', 'HOME', 'LANG', 'LC_ALL', 'TERM' },
        limits = {
            cpu_ms = 60000,
            memory_bytes = 536870912,
            procs = 32,
            file_bytes = 104857600,
            wall_ms = 120000,
        },
        tmp_separate = true,
    },
    restricted = {
        name = 'restricted',
        workspace_mode = 'read-write',
        path_roots = {},
        network = 'loopback',
        env_allowlist = { 'PATH', 'HOME', 'LANG', 'LC_ALL', 'TERM' },
        limits = {
            cpu_ms = 120000,
            memory_bytes = 1073741824,
            procs = 64,
            file_bytes = 1073741824,
            wall_ms = 300000,
        },
        tmp_separate = true,
    },
    standard = {
        name = 'standard',
        workspace_mode = 'read-write',
        path_roots = {},
        network = 'allowlist',
        env_allowlist = { 'PATH', 'HOME', 'LANG', 'LC_ALL', 'TERM' },
        limits = {
            cpu_ms = 300000,
            memory_bytes = 2147483648,
            procs = 128,
            file_bytes = 10737418240,
            wall_ms = 600000,
        },
        tmp_separate = true,
    },
}

---Resolve a named profile.
---@param name string
---@return AiHarnessSandboxProfile? profile
---@return string? err
function M.resolve(name)
    if type(name) ~= 'string' then
        return nil, 'sandbox profile name must be a string'
    end
    local profile = M.PROFILES[name]
    if profile == nil then
        return nil, 'unknown sandbox profile: ' .. name
    end
    return profile
end

---Validate a spawn spec against a profile. Argv arrays only: no shell
---strings, no interpolation. Returns ok without executing anything.
---@param profile AiHarnessSandboxProfile
---@param spec table
---@return boolean ok
---@return string? err
function M.check_spawn(profile, spec)
    if type(profile) ~= 'table' or type(profile.name) ~= 'string' then
        return nil, 'profile must be a resolved sandbox profile'
    end
    if type(spec) ~= 'table' then
        return nil, 'spawn spec must be a table'
    end
    local argv = spec.argv
    if type(argv) ~= 'table' or #argv == 0 then
        return nil, 'spawn spec.argv must be a non-empty array'
    end
    if #argv > ARGV_MAX then
        return nil, 'spawn argv exceeds bound'
    end
    for i, arg in ipairs(argv) do
        if type(arg) ~= 'string' or arg == '' then
            return nil, 'spawn argv[' .. i .. '] must be a non-empty string'
        end
        if #arg > ARG_BYTES_MAX then
            return nil, 'spawn argv[' .. i .. '] exceeds size bound'
        end
    end
    if spec.cwd ~= nil and type(spec.cwd) ~= 'string' then
        return nil, 'spawn spec.cwd must be a string when given'
    end
    if spec.env ~= nil and type(spec.env) ~= 'table' then
        return nil, 'spawn spec.env must be a table when given'
    end
    return true
end

---One-line human description of a profile.
---@param profile AiHarnessSandboxProfile
---@return string
function M.describe(profile)
    assert(type(profile) == 'table' and type(profile.name) == 'string', 'profile required')
    return string.format(
        'sandbox:%s workspace=%s network=%s wall_ms=%d',
        profile.name,
        profile.workspace_mode,
        profile.network,
        profile.limits.wall_ms
    )
end

return M
