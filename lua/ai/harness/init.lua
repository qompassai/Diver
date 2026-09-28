-- /qompassai/diver/lua/ai/harness/init.lua
-- Qompass AI Agent Harness: narrow public API (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Protocol-neutral control plane for agent runs. The harness owns run
-- lifecycle, cancellation, budgets, policy, context snapshots, structured
-- events, persistence, and evaluation; protocol adapters only translate.
-- Public surface is deliberately narrow: setup(), run(), cancel(),
-- resume(). No provider, transport, UI, or protocol-specific options leak
-- through this entry point; adapter-native fields live under the
-- `extensions` table of the run spec.

local M = {}

M._state = nil

---Set up the harness. Idempotent: repeated calls keep the first state.
---@param opts? table {policy?: table, default_timeout_ms?: number}
---@return boolean ok
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
    local reg = require('ai.harness.registry')
    local supervisor = require('ai.harness.supervisor')
    local policy_mod = require('ai.harness.policy')
    local store_mod = require('ai.harness.store')
    local telemetry_mod = require('ai.harness.telemetry')

    local sink = events.new_sink()
    local reg_state = reg.new()
    local ok, err = reg.register_builtins(reg_state)
    if not ok then
        return nil, err
    end
    -- Fail closed: without an explicit policy every tool request denies.
    local policy_state, policy_err = policy_mod.new(opts.policy)
    if policy_state == nil then
        return nil, policy_err
    end
    local sup, sup_err = supervisor.new({
        registry = reg_state,
        sink = sink,
        policy = policy_state,
        store = store_mod.new(),
        telemetry = telemetry_mod.new(),
        default_timeout_ms = opts.default_timeout_ms,
    })
    if sup == nil then
        return nil, sup_err
    end
    M._state = {
        sink = sink,
        registry = reg_state,
        supervisor = sup,
        policy = policy_state,
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
---@return boolean ok
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
---@return boolean ok
---@return string? err
function M.resume(run_id)
    if M._state == nil then
        return nil, 'harness not set up'
    end
    local supervisor = require('ai.harness.supervisor')
    return supervisor.resume(M._state.supervisor, run_id)
end

---@return string
function M.version()
    return '0.1.0'
end

return M
