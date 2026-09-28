-- /qompassai/diver/lua/ai/harness/approval.lua
-- Qompass AI Agent Harness: async user approval queue (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Human approval is adaptive: high-impact or irreversible operations wait
-- here; deterministic low-risk work never enters. Requests expire to
-- denied, never to approved. The single approval surface renders from this
-- queue; it is never the source of truth for policy.

local types = require('ai.harness.types')

local M = {}

local PENDING_MAX = 128
local DEFAULT_TIMEOUT_MS = 300000

---@class AiHarnessApproval
---@field id string
---@field run_id string
---@field tool string
---@field risk string
---@field summary string
---@field state 'pending'|'approved'|'denied'|'expired'
---@field created_ns integer
---@field deadline_ns integer
---@field decided_by? string

---Create an approval queue.
---@return table
function M.new()
    return { pending = {}, by_id = {} }
end

---@param queue table
---@param run_id string
---@param request table
---@param opts? table
---@return string? id
---@return string? err
function M.request(queue, run_id, request, opts)
    assert(queue ~= nil, 'approval queue required')
    if type(run_id) ~= 'string' or run_id == '' then
        return nil, 'approval run_id must be a non-empty string'
    end
    if type(request) ~= 'table' then
        return nil, 'approval request must be a table'
    end
    if type(request.tool) ~= 'string' or request.tool == '' then
        return nil, 'approval request.tool must be a non-empty string'
    end
    if not types.is_valid_risk(request.risk) then
        return nil, 'approval request.risk must be a known risk class'
    end
    opts = opts or {}
    if #queue.pending >= PENDING_MAX then
        return nil, 'approval queue is full'
    end
    local timeout_ms = opts.timeout_ms or DEFAULT_TIMEOUT_MS
    if type(timeout_ms) ~= 'number' or timeout_ms <= 0 then
        return nil, 'approval timeout_ms must be positive'
    end
    local now_ns = types.now_ns()
    local approval = {
        id = types.new_id('approval'),
        run_id = run_id,
        tool = request.tool,
        risk = request.risk,
        summary = type(request.summary) == 'string' and request.summary or request.tool,
        argv = request.argv,
        paths = request.paths,
        endpoints = request.endpoints,
        state = 'pending',
        created_ns = now_ns,
        deadline_ns = now_ns + math.floor(timeout_ms * 1000000),
    }
    queue.by_id[approval.id] = approval
    queue.pending[#queue.pending + 1] = approval.id
    return approval.id
end

---Record a human decision. Only pending approvals can be decided.
---@param queue table
---@param id string
---@param decision 'approved'|'denied'
---@param by? string
---@return boolean ok
---@return string? err
function M.decide(queue, id, decision, by)
    assert(queue ~= nil, 'approval queue required')
    if decision ~= 'approved' and decision ~= 'denied' then
        return nil, "approval decision must be 'approved' or 'denied'"
    end
    local approval = queue.by_id[id]
    if approval == nil then
        return nil, 'unknown approval id'
    end
    if approval.state ~= 'pending' then
        return nil, 'approval is already ' .. approval.state
    end
    approval.state = decision
    approval.decided_by = by
    return true
end

---@param queue table
---@param id string
---@return AiHarnessApproval?
function M.get(queue, id)
    assert(queue ~= nil, 'approval queue required')
    return queue.by_id[id]
end

---Pending approvals, oldest first.
---@param queue table
---@return AiHarnessApproval[]
function M.pending(queue)
    assert(queue ~= nil, 'approval queue required')
    local out = {}
    for _, id in ipairs(queue.pending) do
        local approval = queue.by_id[id]
        if approval ~= nil and approval.state == 'pending' then
            out[#out + 1] = approval
        end
    end
    return out
end

---Expire overdue requests. Expiry means denied, never approved.
---@param queue table
---@param now_ns integer
---@return integer expired_count
function M.sweep_expired(queue, now_ns)
    assert(queue ~= nil, 'approval queue required')
    assert(type(now_ns) == 'number', 'now_ns required')
    local expired = 0
    for _, id in ipairs(queue.pending) do
        local approval = queue.by_id[id]
        if approval ~= nil and approval.state == 'pending' and now_ns >= approval.deadline_ns then
            approval.state = 'expired'
            expired = expired + 1
        end
    end
    return expired
end

return M
