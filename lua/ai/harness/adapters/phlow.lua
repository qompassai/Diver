-- /qompassai/diver/lua/ai/harness/adapters/phlow.lua
-- Qompass AI Agent Harness: Phlow adapter (Tiger Style)
---@module 'ai.harness.adapters.phlow'
-- Capability probe over ai.phlow.client. Phlow is the durable external
-- workflow control plane; wiring its transport into harness runs is
-- Phase 6 work. Until then the adapter reports honest capabilities and
-- start() declines with a clear error instead of inventing a transport.

local M = {}

M.name = 'phlow'

---@return AiHarnessCapabilities
function M.probe()
    local ok_client = pcall(require, 'ai.phlow.client')
    local ok_transports = pcall(require, 'ai.phlow.transports')
    local ok_schemas = pcall(require, 'ai.phlow.schemas')
    return {
        artifacts = false,
        available = ok_client and ok_transports and ok_schemas,
        cancellation = false,
        notes = 'transport wiring is Phase 6; use native ai.phlow API directly',
        permissions = false,
        remote = true,
        resume = false,
        streaming = false,
        tools = false,
        wired_start = false,
    }
end

---@param run table
---@param sink AiHarnessSink
---@return nil handle
---@return string err
function M.start(run, sink)
    assert(run ~= nil, 'run required')
    assert(sink ~= nil, 'sink required')
    return nil, 'phlow adapter start is Phase 6 work: use native ai.phlow API'
end

---@param handle table
---@param _reason string
---@return boolean
function M.cancel(handle, _reason)
    assert(handle ~= nil, 'handle required')
    return true
end

---@param handle table
function M.close(handle)
    assert(handle ~= nil, 'handle required')
end

return M
