-- /qompassai/diver/lua/ai/harness/adapters/herd.lua
-- Qompass AI Agent Harness: Herd adapter (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Thin translator over ai.herd. Preserves Herd native semantics: worker
-- identity, process ownership, remote topology. A run maps to one herd
-- worker agent; killing the worker cancels the run. Wraps; does not
-- modify ai/herd.

local M = {}

M.name = 'herd'

local generation_counter = 0

---@return AiHarnessCapabilities
function M.probe()
    local ok_herd = pcall(require, 'ai.herd')
    local ok_api = pcall(require, 'ai.herd.api')
    return {
        available = ok_herd and ok_api,
        streaming = false,
        cancellation = true,
        resume = false,
        permissions = false,
        artifacts = false,
        remote = true,
        tools = false,
        wired_start = true,
        notes = 'run maps to one herd worker; remote topology via ai.herd.remotes',
    }
end

---Spawn a herd worker agent. Uses run.extensions.herd.cli when given;
---falls back to the herd default CLI.
---@param run table
---@param sink AiHarnessSink
---@return table? handle
---@return string? err
function M.start(run, sink)
    assert(run ~= nil, 'run required')
    assert(sink ~= nil, 'sink required')
    local found, herd = pcall(require, 'ai.herd')
    if not found then
        return nil, 'ai.herd unavailable: ' .. tostring(herd)
    end
    local ext = (run.extensions ~= nil and run.extensions.herd) or {}
    local cli_name = ext.cli
    if cli_name ~= nil and (type(cli_name) ~= 'string' or cli_name == '') then
        return nil, 'herd adapter run.extensions.herd.cli must be a non-empty string'
    end
    generation_counter = generation_counter + 1
    local worker_name = 'harness-' .. run.id
    local spawned, spawn_err = herd.spawn_agent(worker_name, cli_name, run.goal, run.workspace)
    if not spawned then
        return nil, 'herd spawn_agent failed: ' .. tostring(spawn_err)
    end
    local handle = {
        adapter = 'herd',
        generation = generation_counter,
        run_id = run.id,
        worker = worker_name,
        closed = false,
    }
    sink:append(run.id, 'diagnostic.observed', {
        adapter = 'herd',
        kind = 'worker_spawned',
        worker = worker_name,
    }, { source = 'herd' })
    return handle
end

---@param handle table
---@param reason string
---@return boolean
function M.cancel(handle, _reason)
    assert(handle ~= nil, 'handle required')
    handle.generation = handle.generation + 1
    if handle.worker ~= nil then
        pcall(function()
            require('ai.herd').kill_agent(handle.worker)
        end)
    end
    return true
end

---@param handle table
function M.close(handle)
    assert(handle ~= nil, 'handle required')
    handle.closed = true
    if handle.worker ~= nil then
        pcall(function()
            require('ai.herd').kill_agent(handle.worker)
        end)
        handle.worker = nil
    end
end

return M
