-- /qompassai/diver/lua/ai/harness/types.lua
-- Qompass AI Agent Harness: canonical contracts (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Canonical run/event/budget/capability contracts for the protocol-neutral
-- agent harness. Every protocol adapter (acp, a2a, mcp, phlow, rose, herd)
-- translates its native messages into these types; no protocol string ever
-- leaks past the adapter boundary. Pure Lua: safe to require without Neovim.

local M = {}

---Schema version stamped on every event envelope.
M.SCHEMA_VERSION = 1

---Ordered run lifecycle. Hierarchical state machine; free-form status
---strings are not allowed past this module.
M.RUN_STATES = {
    'created',
    'queued',
    'running',
    'waiting_input',
    'waiting_approval',
    'retry_wait',
    'completed',
    'failed',
    'cancelled',
    'timed_out',
    'interrupted',
}

---Terminal states: exactly one terminal event per run.
---@type table<string, boolean>
M.TERMINAL_STATES = {
    completed = true,
    failed = true,
    cancelled = true,
    timed_out = true,
    interrupted = true,
}

---Explicit transition table. Missing edges are rejected, never coerced.
---@type table<string, string[]>
M.TRANSITIONS = {
    created = { 'queued', 'cancelled' },
    queued = { 'running', 'cancelled', 'timed_out', 'failed' },
    running = {
        'waiting_input',
        'waiting_approval',
        'retry_wait',
        'completed',
        'failed',
        'cancelled',
        'timed_out',
    },
    waiting_input = { 'running', 'cancelled', 'timed_out' },
    waiting_approval = { 'running', 'cancelled', 'timed_out' },
    retry_wait = { 'queued', 'cancelled', 'timed_out' },
    -- Resume re-queues a settled run for a fresh attempt.
    completed = {},
    failed = { 'queued' },
    cancelled = { 'queued' },
    timed_out = { 'queued' },
    interrupted = { 'queued' },
}

---Typed event vocabulary for the append-only stream.
M.EVENT_KINDS = {
    'run.created',
    'run.started',
    'run.state_changed',
    'run.finished',
    'model.requested',
    'model.stream_delta',
    'model.completed',
    'tool.proposed',
    'tool.approval_requested',
    'tool.started',
    'tool.completed',
    'context.attached',
    'context.truncated',
    'artifact.created',
    'diagnostic.observed',
    'verdict.recorded',
    'budget.warning',
    'budget.exhausted',
    'security.denied',
    'security.violation',
}

---Risk classes for the policy engine. Ordered low to high impact.
M.RISK_CLASSES = {
    'observe',
    'local_reversible',
    'process',
    'network',
    'irreversible',
}

---Capability keys every adapter probe must answer.
M.CAPABILITY_KEYS = {
    'streaming',
    'cancellation',
    'resume',
    'permissions',
    'artifacts',
    'remote',
    'tools',
}

---Budget dimensions tracked per run.
M.BUDGET_KINDS = {
    'turn',
    'tool_call',
    'token',
    'time_ms',
    'byte',
    'cost',
}

local ID_COUNTER = 0
local ID_COUNTER_MAX = 1000000

local _event_kind_set = nil ---@type table<string, boolean>?
local _state_set = nil ---@type table<string, boolean>?
local _risk_set = nil ---@type table<string, boolean>?
local _budget_kind_set = nil ---@type table<string, boolean>?

---Build a set from a list once, then reuse. Bounded: input lists are fixed.
---@param list string[]
---@return table<string, boolean>
local function make_set(list)
    local set = {}
    for _, v in ipairs(list) do
        set[v] = true
    end
    return set
end

---Monotonic nanosecond clock. Prefers libuv; falls back to os.clock so the
---module stays testable outside Neovim.
---@return integer
function M.now_ns()
    if vim ~= nil and vim.uv ~= nil and vim.uv.hrtime ~= nil then
        return vim.uv.hrtime()
    end
    return math.floor(os.clock() * 1000000000)
end

---Generate a unique run-scoped id. Counter wraps defensively; uniqueness
---also rests on the timestamp and random suffix.
---@param prefix string
---@return string
function M.new_id(prefix)
    assert(type(prefix) == 'string' and #prefix > 0, 'new_id: prefix required')
    ID_COUNTER = (ID_COUNTER + 1) % ID_COUNTER_MAX
    return string.format('%s-%d-%d-%06d', prefix, M.now_ns(), ID_COUNTER, math.random(0, 999999))
end

---@param state string
---@return boolean
function M.is_valid_state(state)
    if _state_set == nil then
        _state_set = make_set(M.RUN_STATES)
    end
    return _state_set[state] == true
end

---@param state string
---@return boolean
function M.is_terminal(state)
    return M.TERMINAL_STATES[state] == true
end

---Explicit transition check. Invalid or stale transitions must become
---diagnostic events, never silent mutations.
---@param from string
---@param to string
---@return boolean
function M.can_transition(from, to)
    if not M.is_valid_state(from) or not M.is_valid_state(to) then
        return false
    end
    for _, next_state in ipairs(M.TRANSITIONS[from]) do
        if next_state == to then
            return true
        end
    end
    return false
end

---@param kind string
---@return boolean
function M.is_valid_event_kind(kind)
    if _event_kind_set == nil then
        _event_kind_set = make_set(M.EVENT_KINDS)
    end
    return _event_kind_set[kind] == true
end

---@param risk string
---@return boolean
function M.is_valid_risk(risk)
    if _risk_set == nil then
        _risk_set = make_set(M.RISK_CLASSES)
    end
    return _risk_set[risk] == true
end

---@param kind string
---@return boolean
function M.is_valid_budget_kind(kind)
    if _budget_kind_set == nil then
        _budget_kind_set = make_set(M.BUDGET_KINDS)
    end
    return _budget_kind_set[kind] == true
end

---Validate a harness.run() spec before any state is created.
---@param spec table
---@return boolean ok
---@return string? err
function M.validate_run_spec(spec)
    if type(spec) ~= 'table' then
        return nil, 'run spec must be a table'
    end
    if type(spec.workflow) ~= 'string' or spec.workflow == '' then
        return nil, 'run spec.workflow must be a non-empty string'
    end
    if type(spec.goal) ~= 'string' or spec.goal == '' then
        return nil, 'run spec.goal must be a non-empty string'
    end
    if type(spec.workspace) ~= 'string' or spec.workspace == '' then
        return nil, 'run spec.workspace must be a non-empty string'
    end
    if spec.adapter ~= nil and (type(spec.adapter) ~= 'string' or spec.adapter == '') then
        return nil, 'run spec.adapter must be a non-empty string when given'
    end
    if spec.timeout_ms ~= nil and (type(spec.timeout_ms) ~= 'number' or spec.timeout_ms <= 0) then
        return nil, 'run spec.timeout_ms must be a positive number when given'
    end
    if spec.budget ~= nil and type(spec.budget) ~= 'table' then
        return nil, 'run spec.budget must be a table when given'
    end
    if spec.extensions ~= nil and type(spec.extensions) ~= 'table' then
        return nil, 'run spec.extensions must be a table when given'
    end
    if spec.acceptance ~= nil and type(spec.acceptance) ~= 'table' then
        return nil, 'run spec.acceptance must be a table when given'
    end
    return true
end

return M
