-- /qompassai/diver/lua/ai/harness/supervisor.lua
-- Qompass AI Agent Harness: run lifecycle supervisor (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Owns all asynchronous run work: structured parent/child ownership,
-- cooperative cancellation, per-run deadlines, concurrency limits, bounded
-- retry with backoff, idempotent finish, and generation tokens that discard
-- stale callbacks. No vim.wait() anywhere; progress is driven by tick(),
-- which Neovim calls from a timer or which tests call directly. Also owns
-- the tool dispatch path: the only route from a registered tool name to
-- its run function, gated by policy on every call.

local adapter = require('ai.harness.adapter')
local approval = require('ai.harness.approval')
local budget = require('ai.harness.budget')
local types = require('ai.harness.types')

local M = {}

local DEFAULT_BUDGET_LIMITS = {
    byte = 10000000,
    time_ms = 600000,
    token = 200000,
    tool_call = 200,
    turn = 50,
}
local DEFAULT_TIMEOUT_MS = 600000
local RETRY_ATTEMPTS_MAX = 4
local RETRY_BASE_MS = 1000
local RETRY_MAX_MS = 60000
local RUNS_MAX = 256

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
---@field _terminal_emitted boolean
---@field acceptance? table
---@field children string[]
---@field generation integer
---@field handle? table
---@field retry_at_ns? integer

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
        approvals = opts.approvals or approval.new(),
        default_timeout_ms = opts.default_timeout_ms or DEFAULT_TIMEOUT_MS,
        last_seq = 0,
        last_tick_ns = types.now_ns(),
        policy = opts.policy,
        registry = opts.registry,
        run_count = 0,
        runs = {},
        runs_max = opts.runs_max or RUNS_MAX,
        sink = opts.sink,
        store = opts.store,
        telemetry = opts.telemetry,
    }
end

---Move a run to a new state. Invalid transitions become diagnostic events,
---never silent mutations. Terminal states emit run.finished exactly once
---per attempt.
---@param sup table
---@param run AiHarnessRun
---@param to string
---@param payload? table
---@return boolean|nil ok
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

---Create a run. The spec's workflow must resolve in the registry: an
---unknown workflow name fails closed and no run is created. Resolution
---is an existence check only; adapter selection is unchanged (the
---spec's adapter, never the workflow definition's, launches the run).
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
    local registry = require('ai.harness.registry')
    if registry.get_workflow(sup.registry, spec.workflow) == nil then
        return nil, 'unknown workflow: ' .. spec.workflow
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
    ---@cast run AiHarnessRun
    return run
end

---Launch a queued run through its adapter. Shared by start_run, resume,
---and retry promotion.
---@param sup table
---@param run AiHarnessRun
---@param adapter_name? string
---@return boolean|nil ok
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
---@return boolean|nil ok
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
---@param run AiHarnessRun
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
---@return boolean|nil ok
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
---@return boolean|nil ok
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
---@return boolean|nil ok
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
---@return boolean|nil ok
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
---@return boolean|nil ok
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

---@param t table
---@return string[] keys Keys in sorted order for deterministic iteration.
local function sorted_keys(t)
    local keys = {}
    for key in pairs(t) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)
    return keys
end

---Validate dispatch args against a tool's input_schema. The schema maps
---field names to { type = ..., required = ... }; types are the Lua type
---names plus 'integer'. Unknown arguments are rejected: a misspelled
---field must fail here, never be silently dropped.
---@param name string
---@param def table
---@param args table
---@return boolean|nil ok
---@return string? err
local function validate_tool_args(name, def, args)
    local schema = def.input_schema
    for _, field in ipairs(sorted_keys(schema)) do
        local spec = schema[field]
        if type(spec) ~= 'table' or type(spec.type) ~= 'string' then
            return nil, 'tool ' .. name .. ' has a malformed input_schema at field: ' .. field
        end
        local value = args[field]
        if value == nil then
            if spec.required then
                return nil, 'missing required argument: ' .. field
            end
        elseif spec.type == 'integer' then
            if type(value) ~= 'number' or value % 1 ~= 0 then
                return nil, 'argument ' .. field .. ' must be an integer'
            end
        elseif type(value) ~= spec.type then
            return nil, 'argument ' .. field .. ' must be a ' .. spec.type
        end
    end
    for _, field in ipairs(sorted_keys(args)) do
        if schema[field] == nil then
            return nil, 'unknown argument: ' .. tostring(field)
        end
    end
    return true
end

---Names of all registered tools, in sorted order.
---@param sup table
---@return string[]
function M.list_tools(sup)
    assert(sup ~= nil, 'supervisor required')
    local registry = require('ai.harness.registry')
    return registry.list_tools(sup.registry)
end

---Dispatch one registered tool by name: the only path from a tool name
---to a side effect. Registry lookup, input_schema validation, then the
---policy gate; fail-closed at every step. An unknown tool, malformed
---args, a missing policy, a deny, or an approval decision all return a
---structured error and the tool's run is never invoked (approval routing
---belongs to run-scoped callers, not this synchronous path). A tool
---without a declared risk class is decided as 'process'.
---@param sup table
---@param name string
---@param args? table
---@return any result
---@return string? err
function M.dispatch_tool(sup, name, args)
    assert(sup ~= nil, 'supervisor required')
    if type(name) ~= 'string' or name == '' then
        return nil, 'tool name must be a non-empty string'
    end
    if args ~= nil and type(args) ~= 'table' then
        return nil, 'tool args must be a table when given'
    end
    args = args or {}
    local policy = require('ai.harness.policy')
    local registry = require('ai.harness.registry')
    local def = registry.get_tool(sup.registry, name)
    if def == nil then
        return nil, 'unknown tool: ' .. name
    end
    local valid, validation_err = validate_tool_args(name, def, args)
    if not valid then
        return nil, validation_err
    end
    local risk = type(def.risk) == 'string' and def.risk or 'process'
    local paths = nil
    if type(args.path) == 'string' then
        paths = { args.path }
    end
    local decision = policy.decide(sup.policy, { paths = paths, risk = risk, tool = name })
    if decision.decision == 'deny' then
        return nil, 'tool request denied by policy: ' .. decision.reason
    end
    if decision.decision ~= 'allow' then
        return nil, 'tool request requires approval: ' .. decision.reason
    end
    local ok, result, run_err = pcall(def.run, args)
    if not ok then
        return nil, 'tool run failed: ' .. tostring(result)
    end
    return result, run_err
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
                local ok, _ = transition(sup, run, 'queued')
                if ok then
                    local launched, _ = launch(sup, run, run.adapter)
                    if launched then
                        acted = acted + 1
                    end
                end
            end
        end
    end
    acted = acted + drain_completions(sup)
    return acted
end

return M
