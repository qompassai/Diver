-- /qompassai/diver/lua/ai/harness/adapters/a2a.lua
-- Qompass AI Agent Harness: A2A adapter (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Thin translator over ai.a2a.tasks / ai.a2a.client. Preserves A2A native
-- semantics: Agent Cards, task ids, artifacts, input-required, task
-- lifecycle with polling/streaming/push. Wraps; does not modify ai/a2a.

local M = {}

M.name = 'a2a'

local generation_counter = 0

---@return AiHarnessCapabilities
function M.probe()
    local ok_tasks = pcall(require, 'ai.a2a.tasks')
    local ok_client = pcall(require, 'ai.a2a.client')
    return {
        available = ok_tasks and ok_client,
        streaming = true,
        cancellation = true,
        resume = true,
        permissions = false,
        artifacts = true,
        remote = true,
        tools = false,
        wired_start = true,
        notes = 'permissions unwired: A2A consent stays native in Phase 1',
    }
end

---Submit a task to a remote agent. Requires run.extensions.a2a.agent
---(agent card reference accepted by ai.a2a.tasks.submit).
---@param run table
---@param sink AiHarnessSink
---@return table? handle
---@return string? err
function M.start(run, sink)
    assert(run ~= nil, 'run required')
    assert(sink ~= nil, 'sink required')
    local ext = (run.extensions ~= nil and run.extensions.a2a) or {}
    if ext.agent == nil then
        return nil, 'a2a adapter requires run.extensions.a2a.agent'
    end
    local found, tasks = pcall(require, 'ai.a2a.tasks')
    if not found then
        return nil, 'ai.a2a.tasks unavailable: ' .. tostring(tasks)
    end
    generation_counter = generation_counter + 1
    local handle = {
        adapter = 'a2a',
        generation = generation_counter,
        run_id = run.id,
        task_id = nil,
        closed = false,
    }
    local my_generation = handle.generation
    local task_id, err = tasks.submit({
        agent = ext.agent,
        message = run.goal,
        timeout_ms = ext.timeout_ms,
        on_done = function(result, task_err)
            if my_generation ~= handle.generation or handle.closed then
                return
            end
            sink:append(run.id, 'model.completed', {
                adapter = 'a2a',
                outcome = task_err == nil and 'completed' or 'failed',
                error = task_err,
                result = result,
            }, { source = 'a2a' })
        end,
    })
    if task_id == nil then
        return nil, 'a2a submit failed: ' .. tostring(err)
    end
    handle.task_id = task_id
    return handle
end

---@param handle table
---@param reason string
---@return boolean
function M.cancel(handle, reason)
    assert(handle ~= nil, 'handle required')
    handle.generation = handle.generation + 1
    if handle.task_id ~= nil then
        pcall(function()
            require('ai.a2a.tasks').cancel(handle.task_id, reason)
        end)
    end
    return true
end

---@param handle table
function M.close(handle)
    assert(handle ~= nil, 'handle required')
    handle.closed = true
    handle.task_id = nil
end

return M
