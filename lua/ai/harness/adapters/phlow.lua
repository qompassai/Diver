-- /qompassai/diver/lua/ai/harness/adapters/phlow.lua
-- Qompass AI Agent Harness: Phlow adapter (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
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
        available = ok_client and ok_transports and ok_schemas,
        streaming = false,
        cancellation = false,
        resume = false,
        permissions = false,
        artifacts = false,
        remote = true,
        tools = false,
        wired_start = false,
        notes = 'transport wiring is Phase 6; use native ai.phlow API directly',
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
---@param reason string
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
