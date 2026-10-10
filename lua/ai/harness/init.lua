-- /qompassai/diver/lua/ai/harness/init.lua
-- Qompass AI Agent Harness: narrow public API (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Protocol-neutral control plane for agent runs. The harness owns run
-- lifecycle, cancellation, budgets, policy, context snapshots, structured
-- events, persistence, and evaluation; protocol adapters only translate.
-- Public surface is deliberately narrow: setup(), run(), cancel(),
-- resume(), and the tool surface register_tool(), list_tools(),
-- dispatch_tool(). No provider, transport, UI, or protocol-specific
-- options leak through this entry point; adapter-native fields live
-- under the `extensions` table of the run spec. health() reports the
-- live registry inventory and runtime probes from this state.

local M = {}

M._state = nil

---Set up the harness. Idempotent: repeated calls keep the first state.
---@param opts? table {policy?: table, default_timeout_ms?: number}
---@return boolean|nil ok
---@return string? err
function M.setup(opts)
    if M._state ~= nil then
        return true
    end
    opts = opts or {}
    if type(opts) ~= 'table' then
        return nil, 'setup opts must be a table when given'
    end
    local events = require('ai.harness.events')
    local policy_mod = require('ai.harness.policy')
    local reg = require('ai.harness.registry')
    local store_mod = require('ai.harness.store')
    local supervisor = require('ai.harness.supervisor')
    local telemetry_mod = require('ai.harness.telemetry')

    local sink = events.new_sink()
    local reg_state = reg.new()
    local ok, err = reg.register_builtins(reg_state)
    if not ok then
        return nil, err
    end
    local tools_ok, tools_err = reg.register_builtin_tools(reg_state)
    if not tools_ok then
        return nil, tools_err
    end
    -- Fail closed: without an explicit policy every tool request denies.
    local policy_state, policy_err = policy_mod.new(opts.policy)
    if policy_state == nil then
        return nil, policy_err
    end
    local sup, sup_err = supervisor.new({
        default_timeout_ms = opts.default_timeout_ms,
        policy = policy_state,
        registry = reg_state,
        sink = sink,
        store = store_mod.new(),
        telemetry = telemetry_mod.new(),
    })
    if sup == nil then
        return nil, sup_err
    end
    M._state = {
        policy = policy_state,
        registry = reg_state,
        sink = sink,
        supervisor = sup,
    }
    return true
end

---Start a run. Returns the run id; the run begins in `running` once its
---adapter accepts it, or lands in `failed` with a diagnostic event.
---@param spec table
---@return string? run_id
---@return string? err
function M.run(spec)
    if M._state == nil then
        return nil, 'harness not set up: call require("ai.harness").setup() first'
    end
    local supervisor = require('ai.harness.supervisor')
    local run, err = supervisor.create(M._state.supervisor, spec)
    if run == nil then
        return nil, err
    end
    local ok, start_err = supervisor.start_run(M._state.supervisor, run.id, spec.adapter)
    if not ok then
        supervisor.finish(M._state.supervisor, run.id, 'failed', 'invalid_adapter: ' .. tostring(start_err))
        return nil, start_err
    end
    return run.id
end

---Cancel a live run.
---@param run_id string
---@param reason? string
---@return boolean|nil ok
---@return string? err
function M.cancel(run_id, reason)
    if M._state == nil then
        return nil, 'harness not set up'
    end
    local supervisor = require('ai.harness.supervisor')
    return supervisor.cancel(M._state.supervisor, run_id, reason)
end

---Re-queue a settled run (failed, cancelled, timed out, or interrupted)
---for a fresh attempt. Completed runs are not resumable: re-run the
---spec with run() instead.
---@param run_id string
---@return boolean|nil ok
---@return string? err
function M.resume(run_id)
    if M._state == nil then
        return nil, 'harness not set up'
    end
    local supervisor = require('ai.harness.supervisor')
    return supervisor.resume(M._state.supervisor, run_id)
end

---Register a tool with the harness registry. Producers register into
---the same registry instance the supervisor dispatches from; there is
---no second registry and no implicit discovery.
---@param name string
---@param def table
---@return boolean|nil ok
---@return string? err
function M.register_tool(name, def)
    if M._state == nil then
        return nil, 'harness not set up: call require("ai.harness").setup() first'
    end
    local reg = require('ai.harness.registry')
    return reg.register_tool(M._state.registry, name, def)
end

---Names of all registered tools, in sorted order.
---@return string[]? names
---@return string? err
function M.list_tools()
    if M._state == nil then
        return nil, 'harness not set up: call require("ai.harness").setup() first'
    end
    local reg = require('ai.harness.registry')
    return reg.list_tools(M._state.registry)
end

---Dispatch a registered tool through the policy gate. Deny and
---approval decisions never invoke the tool (fail-closed).
---@param name string
---@param args? table
---@return any result
---@return string? err
function M.dispatch_tool(name, args)
    if M._state == nil then
        return nil, 'harness not set up: call require("ai.harness").setup() first'
    end
    local supervisor = require('ai.harness.supervisor')
    return supervisor.dispatch_tool(M._state.supervisor, name, args)
end

---Runtime health report: adapter availability, the live registry
---inventory (adapters, tools, workflows), storage, and sandbox
---profiles, probed from this harness's own state.
---@return table? report
---@return string? err
function M.health()
    if M._state == nil then
        return nil, 'harness not set up: call require("ai.harness").setup() first'
    end
    local health = require('ai.harness.health')
    return health.check({ registry = M._state.registry, store = M._state.supervisor.store })
end

---@return string
function M.version()
    return '0.1.0'
end

return M
