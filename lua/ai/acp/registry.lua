-- /qompassai/Diver/lua/ai/acp/registry.lua
-- Qompass AI ACP Agent Registry (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Two sources of truth, merged:
--   1. M.manual   -- agents that are NOT in the official registry (bridges,
--                    forks, unverified entries), maintained by hand here.
--   2. The live official registry.json, fetched on demand and cached, for
--      every agent that natively speaks ACP (claude, codex, gemini, cursor,
--      devin, goose, opencode, github-copilot, etc.).
-- Reference: https://github.com/agentclientprotocol/registry

local fs = vim.fs
local uv = vim.uv

local M = {}

local REGISTRY_URL = 'https://cdn.agentclientprotocol.com/registry/v1/latest/registry.json'
local CACHE_PATH = fs.joinpath(vim.fn.stdpath('cache'), 'acp', 'registry.json')
local FETCH_TIMEOUT_MS = 8000
local CACHE_MAX_BYTES = 4 * 1024 * 1024

---@class AcpAgentSpec
---@field cmd string[] Ordered argv; first element must be an executable.
---@field kind 'native'|'bridge' 'native' speaks ACP directly; 'bridge' wraps
---  a non-ACP backend (e.g. a raw model API) and re-exposes it as ACP.
---@field verified boolean Whether this exact invocation has been confirmed.
---@field notes? string

-- Agents outside the official registry: bridges, personal forks, and one
-- explicitly unverified placeholder. Nothing here is guessed silently --
-- every entry that isn't a native ACP agent says so, and the one product
-- name we could not find any evidence for is left unfilled rather than
-- invented.
---@type table<string, AcpAgentSpec>
M.manual = {
    ollama = {
        cmd = { 'acp-bridge', '--backend', 'ollama' },
        kind = 'bridge',
        verified = false,
        notes = 'Ollama does not speak ACP natively. This assumes acp-bridge '
            .. '(github.com/BlakeHung/acp-bridge); adjust cmd/args if you use a '
            .. 'different bridge such as @medyll/acp-team instead.',
    },
    rose = {
        cmd = { 'acp-bridge', '--backend', 'ollama', '--host', 'http://127.0.0.1:11434' },
        kind = 'bridge',
        verified = false,
        notes = 'Your Ollama fork, bridged the same way as `ollama` above. '
            .. 'Update --host/--port to match wherever Rose actually listens.',
    },
    huggingface = {
        cmd = { 'uvx', 'hf-inference-acp' },
        kind = 'native',
        verified = true,
        notes = 'Confirmed real: PyPI package hf-inference-acp, speaks ACP '
            .. 'directly against the HF Inference API. Requires HF_TOKEN in env; '
            .. 'first run drops into a setup mode with /login if unset.',
    },
}

local function ensure_cache_dir()
    local dir = assert(fs.dirname(CACHE_PATH), 'CACHE_PATH has no parent directory')
    vim.fn.mkdir(dir, 'p', '700')
end

---@param callback fun(ok: boolean, data: table?, err: string?)
function M.refresh(callback)
    ensure_cache_dir()
    vim.system({
        'curl',
        '--disable',
        '--fail',
        '--silent',
        '--show-error',
        '--location',
        '--proto',
        '=https',
        '--connect-timeout',
        '3',
        '--max-time',
        tostring(math.floor(FETCH_TIMEOUT_MS / 1000)),
        '--user-agent',
        'Diver-acp-registry',
        REGISTRY_URL,
    }, { timeout = FETCH_TIMEOUT_MS }, function(result)
        vim.schedule(function()
            if result.code ~= 0 then
                callback(false, nil, 'Registry fetch failed: ' .. tostring(result.stderr))
                return
            end
            if #result.stdout > CACHE_MAX_BYTES then
                callback(false, nil, 'Registry response exceeds cache size bound')
                return
            end
            local ok, data = pcall(vim.json.decode, result.stdout)
            if not ok or type(data) ~= 'table' then
                callback(false, nil, 'Registry response was not valid JSON')
                return
            end
            local fd = uv.fs_open(CACHE_PATH, 'w', 384)
            if fd then
                uv.fs_write(fd, result.stdout, 0)
                uv.fs_close(fd)
            end
            callback(true, data, nil)
        end)
    end)
end

---@return table?
local function read_cache()
    local stat = uv.fs_stat(CACHE_PATH)
    if not stat or stat.type ~= 'file' or stat.size > CACHE_MAX_BYTES then
        return nil
    end
    local fd = uv.fs_open(CACHE_PATH, 'r', 0)
    if not fd then
        return nil
    end
    local text = uv.fs_read(fd, stat.size, 0)
    uv.fs_close(fd)
    local ok, data = pcall(vim.json.decode, text or '')
    return ok and data or nil
end

---@param name string
---@return AcpAgentSpec?
function M.get(name)
    local manual = M.manual[name]
    if manual then
        return manual
    end
    local cached = read_cache()
    local entry = cached and cached.agents and cached.agents[name]
    if type(entry) ~= 'table' or type(entry.command) ~= 'table' then
        return nil
    end
    return {
        cmd = entry.command,
        kind = 'native',
        verified = true,
        notes = 'From official registry cache; run :AcpRegistryRefresh to update.',
    }
end

---@return string[]
function M.list()
    local names = {}
    for name in pairs(M.manual) do
        names[#names + 1] = name
    end
    local cached = read_cache()
    if cached and type(cached.agents) == 'table' then
        for name in pairs(cached.agents) do
            if M.manual[name] == nil then
                names[#names + 1] = name
            end
        end
    end
    table.sort(names)
    return names
end

return M
