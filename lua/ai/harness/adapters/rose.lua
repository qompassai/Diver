-- /qompassai/diver/lua/ai/harness/adapters/rose.lua
-- Qompass AI Agent Harness: Rose adapter (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Thin translator over ai.rose.agent. Preserves Rose native semantics:
-- provider-native request/response fields travel through
-- run.extensions.rose.config untouched. Wraps; does not modify ai/rose.

local M = {}

M.name = 'rose'

local generation_counter = 0

---@return AiHarnessCapabilities
function M.probe()
    local ok_agent = pcall(require, 'ai.rose.agent')
    return {
        available = ok_agent,
        streaming = false,
        cancellation = true,
        resume = false,
        permissions = false,
        artifacts = false,
        remote = false,
        tools = true,
        wired_start = true,
        notes = 'streaming unwired: delta streaming not verified in ai.rose.agent',
    }
end

---Run a local Rose agent loop. Requires run.extensions.rose.config
---(provider/model table for ai.rose.agent.run); the goal becomes the task.
---@param run table
---@param sink AiHarnessSink
---@return table? handle
---@return string? err
function M.start(run, sink)
    assert(run ~= nil, 'run required')
    assert(sink ~= nil, 'sink required')
    local ext = (run.extensions ~= nil and run.extensions.rose) or {}
    if type(ext.config) ~= 'table' then
        return nil, 'rose adapter requires run.extensions.rose.config table'
    end
    local found, agent = pcall(require, 'ai.rose.agent')
    if not found then
        return nil, 'ai.rose.agent unavailable: ' .. tostring(agent)
    end
    generation_counter = generation_counter + 1
    local handle = {
        adapter = 'rose',
        generation = generation_counter,
        run_id = run.id,
        closed = false,
    }
    local my_generation = handle.generation
    local ok, err = pcall(agent.run, ext.config, run.goal, function(report)
        if my_generation ~= handle.generation or handle.closed then
            return
        end
        local outcome = 'completed'
        local report_err = nil
        if type(report) == 'table' and report.status ~= 'completed' then
            outcome = 'failed'
            report_err = tostring(report.status)
        end
        sink:append(run.id, 'model.completed', {
            adapter = 'rose',
            outcome = outcome,
            error = report_err,
        }, { source = 'rose' })
    end, ext.opts or {})
    if not ok then
        return nil, 'ai.rose.agent.run raised: ' .. tostring(err)
    end
    return handle
end

---@param handle table
---@param reason string
---@return boolean
function M.cancel(handle, _reason)
    assert(handle ~= nil, 'handle required')
    handle.generation = handle.generation + 1
    pcall(function()
        require('ai.rose').stop()
    end)
    return true
end

---@param handle table
function M.close(handle)
    assert(handle ~= nil, 'handle required')
    handle.closed = true
end

return M
