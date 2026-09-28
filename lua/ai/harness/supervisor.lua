-- /qompassai/diver/lua/ai/harness/supervisor.lua
-- Qompass AI Agent Harness: run lifecycle supervisor (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Owns all asynchronous run work: structured parent/child ownership,
-- cooperative cancellation, per-run deadlines, concurrency limits, bounded
-- retry with backoff, idempotent finish, and generation tokens that discard
-- stale callbacks. No vim.wait() anywhere; progress is driven by tick(),
-- which Neovim calls from a timer or which tests call directly.

local types = require('ai.harness.types')
local budget = require('ai.harness.budget')
local adapter = require('ai.harness.adapter')
local approval = require('ai.harness.approval')

local M = {}

local RUNS_MAX = 256
local DEFAULT_TIMEOUT_MS = 600000
local RETRY_ATTEMPTS_MAX = 4
local RETRY_BASE_MS = 1000
local RETRY_MAX_MS = 60000
local DEFAULT_BUDGET_LIMITS = {
    turn = 50,
    tool_call = 200,
    token = 200000,
    time_ms = 600000,
    byte = 10000000,
}

---@class AiHarnessRun
---@field id string
---@field parent_id? string
---@field root_id string
---@field workflow string
---@field adapter string
---@field workspace string
---@field state string
---@field attempt integer
---@field created_ns integer
---@field deadline_ns? integer
---@field budget AiHarnessBudget
---@field extensions table

---Create a supervisor. `opts.registry` and `opts.sink` are required;
---policy/approvals/store/telemetry are optional collaborators.
---@param opts table
---@return table? sup
---@return string? err
function M.new(opts)
    if type(opts) ~= 'table' then
        return nil, 'supervisor opts must be a table'
    end
    if type(opts.registry) ~= 'table' then
        return nil, 'supervisor opts.registry is required'
    end
    if type(opts.sink) ~= 'table' then
        return nil, 'supervisor opts.sink is required'
    end
    return {
        registry = opts.registry,
        sink = opts.sink,
        policy = opts.policy,
        approvals = opts.approvals or approval.new(),
        store = opts.store,
        telemetry = opts.telemetry,
        runs = {},
        run_count = 0,
        last_seq = 0,
        last_tick_ns = types.now_ns(),
        default_timeout_ms = opts.default_timeout_ms or DEFAULT_TIMEOUT_MS,
        runs_max = opts.runs_max or RUNS_MAX,
    }
end

---Move a run to a new state. Invalid transitions become diagnostic events,
---never silent mutations. Terminal states emit run.finished exactly once
---per attempt.
---@param sup table
---@param run AiHarnessRun
---@param to string
---@param payload? table
---@return boolean ok
---@return string? err
local function transition(sup, run, to, payload)
    if not types.can_transition(run.state, to) then
        sup.sink:append(run.id, 'diagnostic.observed', {
            kind = 'invalid_transition',
            from = run.state,
            to = to,
        }, { source = 'supervisor' })
        return nil, 'invalid transition ' .. run.state .. ' -> ' .. to
    end
    local from = run.state
    run.state = to
    sup.sink:append(run.id, 'run.state_changed', {
        from = from,
        to = to,
        attempt = run.attempt,
    }, { source = 'supervisor' })
    if types.is_terminal(to) and not run._terminal_emitted then
        run._terminal_emitted = true
        sup.sink:append(run.id, 'run.finished', {
            state = to,
            attempt = run.attempt,
            reason = payload ~= nil and payload.reason or nil,
        }, { source = 'supervisor' })
    end
    return true
end

---@param sup table
---@param spec table
---@return AiHarnessRun? run
---@return string? err
function M.create(sup, spec)
    assert(sup ~= nil, 'supervisor required')
    local valid, err = types.validate_run_spec(spec)
    if not valid then
        return nil, err
    end
    if sup.run_count >= sup.runs_max then
        return nil, 'supervisor run bound exceeded'
    end
    local parent = nil
    if spec.parent_id ~= nil then
        parent = sup.runs[spec.parent_id]
        if parent == nil then
            return nil, 'unknown parent run: ' .. tostring(spec.parent_id)
        end
        if types.is_terminal(parent.state) then
            return nil, 'parent run is already terminal'
        end
    end
    local run_budget, budget_err = budget.new(spec.budget or DEFAULT_BUDGET_LIMITS)
    if run_budget == nil then
        return nil, budget_err
    end
    local now_ns = types.now_ns()
    local timeout_ms = spec.timeout_ms or sup.default_timeout_ms
    local run = {
        id = types.new_id('run'),
        parent_id = spec.parent_id,
        root_id = parent ~= nil and parent.root_id or nil,
        workflow = spec.workflow,
        adapter = spec.adapter,
        workspace = spec.workspace,
        state = 'created',
        attempt = 1,
        created_ns = now_ns,
        deadline_ns = now_ns + math.floor(timeout_ms * 1000000),
        budget = run_budget,
        extensions = spec.extensions or {},
        acceptance = spec.acceptance,
        generation = 0,
        children = {},
        _terminal_emitted = false,
    }
    if run.root_id == nil then
        run.root_id = run.id
    end
    sup.runs[run.id] = run
    sup.run_count = sup.run_count + 1
    if parent ~= nil then
        parent.children[#parent.children + 1] = run.id
    end
    sup.sink:append(run.id, 'run.created', {
        workflow = run.workflow,
        parent_id = run.parent_id,
        workspace = run.workspace,
    }, { source = 'supervisor' })
    return run
end

---Launch a queued run through its adapter. Shared by start_run, resume,
---and retry promotion.
---@param sup table
---@param run AiHarnessRun
---@param adapter_name? string
---@return boolean ok
---@return string? err
local function launch(sup, run, adapter_name)
    local registry = require('ai.harness.registry')
    local name = adapter_name or run.adapter
    local chosen = nil
    if name ~= nil then
        chosen = registry.get_adapter(sup.registry, name)
        if chosen == nil then
            return nil, 'unknown adapter: ' .. tostring(name)
        end
    else
        local adapters = {}
        for _, adapter_n in ipairs(registry.list_adapters(sup.registry)) do
            adapters[adapter_n] = registry.get_adapter(sup.registry, adapter_n)
        end
        local negotiated, negotiate_err = adapter.negotiate(adapters, { cancellation = true })
        if negotiated == nil then
            return nil, negotiate_err
        end
        chosen = negotiated
        name = chosen.name
    end
    run.adapter = name
    local handle, start_err = chosen.start(run, sup.sink)
    if handle == nil then
        transition(sup, run, 'failed', { reason = tostring(start_err) })
        return nil, tostring(start_err)
    end
    run.handle = handle
    local ok, trans_err = transition(sup, run, 'running')
    if not ok then
        return nil, trans_err
    end
    sup.sink:append(run.id, 'run.started', {
        adapter = name,
        attempt = run.attempt,
    }, { source = 'supervisor' })
    return true
end

---@param sup table
---@param run_id string
---@param adapter_name? string
---@return boolean ok
---@return string? err
function M.start_run(sup, run_id, adapter_name)
    assert(sup ~= nil, 'supervisor required')
    local run = sup.runs[run_id]
    if run == nil then
        return nil, 'unknown run: ' .. tostring(run_id)
    end
    local ok, err = transition(sup, run, 'queued')
    if not ok then
        return nil, err
    end
    return launch(sup, run, adapter_name)
end

---@param sup table
---@param run_id string
---@return boolean live
local function has_live_children(sup, run)
    for _, child_id in ipairs(run.children) do
        local child = sup.runs[child_id]
        if child ~= nil and not types.is_terminal(child.state) then
            return true
        end
    end
    return false
end

---Finish a run with a terminal outcome. A parent cannot finish while it
---owns live children.
---@param sup table
---@param run_id string
---@param outcome 'completed'|'failed'|'cancelled'|'timed_out'
---@param reason? string
---@return boolean ok
---@return string? err
function M.finish(sup, run_id, outcome, reason)
    assert(sup ~= nil, 'supervisor required')
    if outcome ~= 'completed' and outcome ~= 'failed' and outcome ~= 'cancelled' and outcome ~= 'timed_out' then
        return nil, 'unknown outcome: ' .. tostring(outcome)
    end
    local run = sup.runs[run_id]
    if run == nil then
        return nil, 'unknown run: ' .. tostring(run_id)
    end
    if has_live_children(sup, run) then
        return nil, 'parent run owns live children'
    end
    if run.handle ~= nil and run.handle.closed ~= true then
        local adapter_mod = require('ai.harness.registry').get_adapter(sup.registry, run.adapter)
        if adapter_mod ~= nil then
            pcall(adapter_mod.close, run.handle)
        end
    end
    return transition(sup, run, outcome, { reason = reason })
end

---Cooperative cancellation: invalidate the generation so stale adapter
---callbacks are dropped, ask the adapter to cancel, then mark cancelled.
---@param sup table
---@param run_id string
---@param reason? string
---@return boolean ok
---@return string? err
function M.cancel(sup, run_id, reason)
    assert(sup ~= nil, 'supervisor required')
    local run = sup.runs[run_id]
    if run == nil then
        return nil, 'unknown run: ' .. tostring(run_id)
    end
    if types.is_terminal(run.state) then
        return nil, 'run is already terminal: ' .. run.state
    end
    run.generation = run.generation + 1
    if run.handle ~= nil then
        local adapter_mod = require('ai.harness.registry').get_adapter(sup.registry, run.adapter)
        if adapter_mod ~= nil then
            pcall(adapter_mod.cancel, run.handle, reason or 'cancelled')
        end
    end
    return transition(sup, run, 'cancelled', { reason = reason })
end

---Re-queue a settled run for a fresh attempt. Attempt counter and
---generation advance; terminal-event guard resets for the new attempt.
---@param sup table
---@param run_id string
---@return boolean ok
---@return string? err
function M.resume(sup, run_id)
    assert(sup ~= nil, 'supervisor required')
    local run = sup.runs[run_id]
    if run == nil then
        return nil, 'unknown run: ' .. tostring(run_id)
    end
    if not types.is_terminal(run.state) then
        return nil, 'resume requires a terminal run'
    end
    run.attempt = run.attempt + 1
    run.generation = run.generation + 1
    run._terminal_emitted = false
    run.handle = nil
    local ok, err = transition(sup, run, 'queued')
    if not ok then
        return nil, err
    end
    return launch(sup, run, run.adapter)
end

---Schedule a retry for a classified transient failure. Bounded attempts
---with exponential backoff and jitter; tick() promotes when due.
---@param sup table
---@param run_id string
---@param reason? string
---@return boolean ok
---@return string? err
function M.retry_run(sup, run_id, reason)
    assert(sup ~= nil, 'supervisor required')
    local run = sup.runs[run_id]
    if run == nil then
        return nil, 'unknown run: ' .. tostring(run_id)
    end
    if run.attempt >= RETRY_ATTEMPTS_MAX then
        return nil, 'retry attempt ceiling exceeded'
    end
    local ok, err = transition(sup, run, 'retry_wait', { reason = reason })
    if not ok then
        return nil, err
    end
    run.attempt = run.attempt + 1
    local backoff_ms = math.min(RETRY_BASE_MS * (2 ^ (run.attempt - 2)), RETRY_MAX_MS)
    local jitter_ms = math.random(0, RETRY_BASE_MS)
    run.retry_at_ns = types.now_ns() + ((backoff_ms + jitter_ms) * 1000000)
    return true
end

---Spawn a child run owned by `parent_id`.
---@param sup table
---@param parent_id string
---@param spec table
---@return AiHarnessRun? run
---@return string? err
function M.spawn_child(sup, parent_id, spec)
    assert(sup ~= nil, 'supervisor required')
    if type(spec) ~= 'table' then
        return nil, 'child spec must be a table'
    end
    spec.parent_id = parent_id
    return M.create(sup, spec)
end

---Consume budget for a run; emits budget.exhausted on overflow.
---@param sup table
---@param run_id string
---@param kind string
---@param amount number
---@return boolean ok
---@return string? err
function M.consume(sup, run_id, kind, amount)
    assert(sup ~= nil, 'supervisor required')
    local run = sup.runs[run_id]
    if run == nil then
        return nil, 'unknown run: ' .. tostring(run_id)
    end
    local ok, err = budget.consume(run.budget, kind, amount)
    if not ok then
        sup.sink:append(run.id, 'budget.exhausted', { kind = kind }, { source = 'supervisor' })
        return nil, err
    end
    return true
end

---Stale-callback guard for async adapter code.
---@param sup table
---@param run_id string
---@param generation integer
---@return boolean fresh
function M.check_generation(sup, run_id, generation)
    assert(sup ~= nil, 'supervisor required')
    local run = sup.runs[run_id]
    if run == nil then
        return false
    end
    return run.generation == generation
end

---@param sup table
---@param run_id string
---@return AiHarnessRun?
function M.get(sup, run_id)
    assert(sup ~= nil, 'supervisor required')
    return sup.runs[run_id]
end

---All runs, oldest first.
---@param sup table
---@return AiHarnessRun[]
function M.list(sup)
    assert(sup ~= nil, 'supervisor required')
    local out = {}
    for _, run in pairs(sup.runs) do
        out[#out + 1] = run
    end
    table.sort(out, function(a, b)
        return a.created_ns < b.created_ns
    end)
    return out
end

---Drain new sink events: adapter completion reports finish their runs.
---@param sup table
---@return integer finished
local function drain_completions(sup)
    local finished = 0
    local events = sup.sink:events()
    for _, event in ipairs(events) do
        if event.seq > sup.last_seq then
            if event.kind == 'model.completed' and type(event.payload) == 'table' then
                local outcome = event.payload.outcome
                if outcome == 'completed' or outcome == 'failed' or outcome == 'cancelled' then
                    local ok, _ = M.finish(sup, event.run_id, outcome, event.payload.error)
                    if ok then
                        finished = finished + 1
                    end
                end
            elseif event.kind == 'budget.exhausted' then
                local ok, _ = M.finish(sup, event.run_id, 'failed', 'budget exhausted')
                if ok then
                    finished = finished + 1
                end
            end
        end
        if event.seq > sup.last_seq then
            sup.last_seq = event.seq
        end
    end
    return finished
end

---Drive time-based supervision: deadlines, retry promotion, approval
---expiry, wall-time budget accounting, and adapter completion reports.
---@param sup table
---@param now_ns integer
---@return integer acted
function M.tick(sup, now_ns)
    assert(sup ~= nil, 'supervisor required')
    assert(type(now_ns) == 'number', 'now_ns required')
    local acted = 0
    local expired = approval.sweep_expired(sup.approvals, now_ns)
    acted = acted + expired
    local elapsed_ms = math.floor((now_ns - sup.last_tick_ns) / 1000000)
    sup.last_tick_ns = now_ns
    for _, run in pairs(sup.runs) do
        if not types.is_terminal(run.state) then
            if elapsed_ms > 0 then
                M.consume(sup, run.id, 'time_ms', elapsed_ms)
            end
            if run.deadline_ns ~= nil and now_ns >= run.deadline_ns then
                local ok, _ = M.finish(sup, run.id, 'timed_out', 'deadline exceeded')
                if ok then
                    acted = acted + 1
                end
            elseif run.state == 'retry_wait' and run.retry_at_ns ~= nil and now_ns >= run.retry_at_ns then
                local ok, trans_err = transition(sup, run, 'queued')
                if ok then
                    local launched, launch_err = launch(sup, run, run.adapter)
                    if launched then
                        acted = acted + 1
                    else
                        _ = launch_err
                    end
                else
                    _ = trans_err
                end
            end
        end
    end
    acted = acted + drain_completions(sup)
    return acted
end

return M
