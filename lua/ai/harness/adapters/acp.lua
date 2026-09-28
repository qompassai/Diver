-- /qompassai/diver/lua/ai/harness/adapters/acp.lua
-- Qompass AI Agent Harness: ACP adapter (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Thin translator over ai.acp.session / ai.acp.permissions. Preserves ACP
-- native semantics: session/turn separation, permission requests,
-- streaming session/update notifications, cancellation. This module wraps;
-- it does not modify ai/acp. Phase 1 limitation: permission prompts use
-- the native ai.acp.permissions flow; harness policy mediation for ACP
-- tool calls lands in Phase 3.

local M = {}

M.name = 'acp'

local generation_counter = 0

---@return AiHarnessCapabilities
function M.probe()
    local ok_session = pcall(require, 'ai.acp.session')
    local ok_permissions = pcall(require, 'ai.acp.permissions')
    local available = ok_session and ok_permissions
    return {
        available = available,
        streaming = true,
        cancellation = true,
        resume = false,
        permissions = true,
        artifacts = false,
        remote = false,
        tools = true,
        wired_start = true,
        notes = 'resume unwired: ACP session resumption not verified in ai.acp',
    }
end

---Start a coding-agent session. Requires run.extensions.acp.agent naming a
---registered ACP agent. Native session/update traffic is bridged to
---diagnostic.observed (raw payload preserved); completion arrives via the
---start callback as model.completed and the supervisor finishes the run.
---@param run table
---@param sink AiHarnessSink
---@return table? handle
---@return string? err
function M.start(run, sink)
    assert(run ~= nil, 'run required')
    assert(sink ~= nil, 'sink required')
    local ext = (run.extensions ~= nil and run.extensions.acp) or {}
    if type(ext.agent) ~= 'string' or ext.agent == '' then
        return nil, 'acp adapter requires run.extensions.acp.agent'
    end
    local found, session = pcall(require, 'ai.acp.session')
    if not found then
        return nil, 'ai.acp.session unavailable: ' .. tostring(session)
    end
    generation_counter = generation_counter + 1
    local handle = {
        adapter = 'acp',
        generation = generation_counter,
        run_id = run.id,
        session_key = nil,
        closed = false,
    }
    local my_generation = handle.generation
    local opts = {
        cwd = run.workspace,
        on_update = function(params)
            if my_generation ~= handle.generation or handle.closed then
                return
            end
            sink:append(run.id, 'diagnostic.observed', {
                adapter = 'acp',
                kind = 'session_update',
                update = params,
            }, { source = 'acp' })
        end,
    }
    local started = false
    local start_err = nil
    session.start(ext.agent, opts, function(session_key, err)
        if my_generation ~= handle.generation or handle.closed then
            return
        end
        if session_key == nil then
            sink:append(run.id, 'model.completed', {
                adapter = 'acp',
                outcome = 'failed',
                error = tostring(err),
            }, { source = 'acp' })
            return
        end
        handle.session_key = session_key
        started = true
        session.prompt(session_key, run.goal, function(prompt_err)
            if my_generation ~= handle.generation or handle.closed then
                return
            end
            sink:append(run.id, 'model.completed', {
                adapter = 'acp',
                outcome = prompt_err == nil and 'completed' or 'failed',
                error = prompt_err,
            }, { source = 'acp' })
        end)
    end)
    if not started and start_err ~= nil then
        return nil, tostring(start_err)
    end
    return handle
end

---Send follow-up input to a live session via session/prompt.
---@param handle table
---@param input table
---@return boolean? ok
---@return string? err
function M.send_input(handle, input)
    assert(handle ~= nil, 'handle required')
    if type(input) ~= 'table' or type(input.text) ~= 'string' or input.text == '' then
        return nil, 'acp send_input requires input.text'
    end
    if handle.session_key == nil then
        return nil, 'acp session not started yet'
    end
    local found, session = pcall(require, 'ai.acp.session')
    if not found then
        return nil, 'ai.acp.session unavailable'
    end
    local ok, err = pcall(session.prompt, handle.session_key, input.text)
    if not ok then
        return nil, tostring(err)
    end
    return true
end

---@param handle table
---@param reason string
---@return boolean
function M.cancel(handle, reason)
    assert(handle ~= nil, 'handle required')
    handle.generation = handle.generation + 1
    if handle.session_key ~= nil then
        pcall(function()
            require('ai.acp.session').cancel(handle.session_key, reason)
        end)
    end
    return true
end

---@param handle table
function M.close(handle)
    assert(handle ~= nil, 'handle required')
    handle.closed = true
    if handle.session_key ~= nil then
        pcall(function()
            require('ai.acp.session').stop(handle.session_key)
        end)
        handle.session_key = nil
    end
end

return M
