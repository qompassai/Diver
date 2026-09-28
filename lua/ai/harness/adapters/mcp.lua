-- /qompassai/diver/lua/ai/harness/adapters/mcp.lua
-- Qompass AI Agent Harness: MCP adapter (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Thin translator over ai.mcp.client. Preserves MCP native semantics: one
-- client per server boundary, initialization/capabilities, tools/resources/
-- prompts. A "run" here is a managed server-session lifecycle; tool calls
-- stay on the native ai.mcp.tools API. Wraps; does not modify ai/mcp.

local M = {}

M.name = 'mcp'

local generation_counter = 0

---@return AiHarnessCapabilities
function M.probe()
    local ok_client = pcall(require, 'ai.mcp.client')
    local ok_tools = pcall(require, 'ai.mcp.tools')
    return {
        available = ok_client and ok_tools,
        streaming = false,
        cancellation = true,
        resume = false,
        permissions = false,
        artifacts = false,
        remote = false,
        tools = true,
        wired_start = true,
        notes = 'run = server session lifecycle; tool calls stay on ai.mcp.tools',
    }
end

---Start the named MCP server session. Requires
---run.extensions.mcp.server (registry name known to ai.mcp.client).
---@param run table
---@param sink AiHarnessSink
---@return table? handle
---@return string? err
function M.start(run, sink)
    assert(run ~= nil, 'run required')
    assert(sink ~= nil, 'sink required')
    local ext = (run.extensions ~= nil and run.extensions.mcp) or {}
    if type(ext.server) ~= 'string' or ext.server == '' then
        return nil, 'mcp adapter requires run.extensions.mcp.server'
    end
    local found, client = pcall(require, 'ai.mcp.client')
    if not found then
        return nil, 'ai.mcp.client unavailable: ' .. tostring(client)
    end
    generation_counter = generation_counter + 1
    local handle = {
        adapter = 'mcp',
        generation = generation_counter,
        run_id = run.id,
        server = ext.server,
        ready = false,
        closed = false,
    }
    local my_generation = handle.generation
    local ok, err = pcall(client.start, ext.server, function(start_err)
        if my_generation ~= handle.generation or handle.closed then
            return
        end
        handle.ready = start_err == nil
        sink:append(run.id, 'model.completed', {
            adapter = 'mcp',
            outcome = start_err == nil and 'completed' or 'failed',
            error = start_err,
            server = ext.server,
        }, { source = 'mcp' })
    end)
    if not ok then
        return nil, 'mcp client.start raised: ' .. tostring(err)
    end
    return handle
end

---@param handle table
---@param reason string
---@return boolean
function M.cancel(handle, _reason)
    assert(handle ~= nil, 'handle required')
    handle.generation = handle.generation + 1
    if handle.server ~= nil then
        pcall(function()
            require('ai.mcp.client').stop(handle.server)
        end)
    end
    return true
end

---@param handle table
function M.close(handle)
    assert(handle ~= nil, 'handle required')
    handle.closed = true
    if handle.server ~= nil then
        pcall(function()
            require('ai.mcp.client').stop(handle.server)
        end)
        handle.server = nil
    end
end

return M
