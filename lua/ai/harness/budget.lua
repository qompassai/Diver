-- /qompassai/diver/lua/ai/harness/budget.lua
-- Qompass AI Agent Harness: run budgets (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Hard loop limits per run: turns, tool calls, tokens, wall time, bytes,
-- and optional monetary cost. Exhausting a budget is a distinct terminal
-- result, not a generic failure. Pure data; the supervisor decides.

local types = require('ai.harness.types')

local M = {}

---@class AiHarnessBudget
---@field limits table<string, number>
---@field used table<string, number>

---Create a budget from explicit limits. Every limit must be a positive
---number; unknown kinds are rejected.
---@param limits table<string, number>
---@return AiHarnessBudget? budget
---@return string? err
function M.new(limits)
    if type(limits) ~= 'table' then
        return nil, 'budget limits must be a table'
    end
    local clean_limits = {}
    local clean_used = {}
    for kind, value in pairs(limits) do
        if not types.is_valid_budget_kind(kind) then
            return nil, 'unknown budget kind: ' .. tostring(kind)
        end
        if type(value) ~= 'number' or value <= 0 then
            return nil, 'budget limit for ' .. kind .. ' must be a positive number'
        end
        clean_limits[kind] = value
        clean_used[kind] = 0
    end
    return { limits = clean_limits, used = clean_used }
end

---Check whether consuming `amount` of `kind` would stay within budget.
---@param budget AiHarnessBudget
---@param kind string
---@param amount number
---@return boolean ok
---@return string? err
function M.check(budget, kind, amount)
    assert(budget ~= nil, 'budget required')
    if not types.is_valid_budget_kind(kind) then
        return false, 'unknown budget kind: ' .. tostring(kind)
    end
    if type(amount) ~= 'number' or amount < 0 then
        return false, 'budget amount must be a non-negative number'
    end
    local limit = budget.limits[kind]
    if limit == nil then
        return true
    end
    if budget.used[kind] + amount > limit then
        return false, 'budget exhausted: ' .. kind
    end
    return true
end

---Consume `amount` of `kind`. Fails without mutating when over budget.
---@param budget AiHarnessBudget
---@param kind string
---@param amount number
---@return boolean ok
---@return string? err
function M.consume(budget, kind, amount)
    local ok, err = M.check(budget, kind, amount)
    if not ok then
        return false, err
    end
    if budget.limits[kind] ~= nil then
        budget.used[kind] = budget.used[kind] + amount
    end
    return true
end

---Remaining headroom for a limited kind; nil when unlimited.
---@param budget AiHarnessBudget
---@param kind string
---@return number?
function M.remaining(budget, kind)
    assert(budget ~= nil, 'budget required')
    local limit = budget.limits[kind]
    if limit == nil then
        return nil
    end
    return limit - budget.used[kind]
end

---True when any limited kind is fully consumed.
---@param budget AiHarnessBudget
---@return boolean exhausted
---@return string? kind
function M.exhausted(budget)
    assert(budget ~= nil, 'budget required')
    local kinds = {}
    for kind in pairs(budget.limits) do
        kinds[#kinds + 1] = kind
    end
    table.sort(kinds)
    for _, kind in ipairs(kinds) do
        if budget.used[kind] >= budget.limits[kind] then
            return true, kind
        end
    end
    return false
end

---Copy of limits and usage for persistence and status views.
---@param budget AiHarnessBudget
---@return table
function M.snapshot(budget)
    assert(budget ~= nil, 'budget required')
    local out = { limits = {}, used = {} }
    for kind, value in pairs(budget.limits) do
        out.limits[kind] = value
    end
    for kind, value in pairs(budget.used) do
        out.used[kind] = value
    end
    return out
end

return M
