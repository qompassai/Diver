-- /qompassai/diver/lua/ai/harness/policy.lua
-- Qompass AI Agent Harness: one authorization decision point (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- The only path from a model proposal to a side effect. Risk classes, not
-- a single confirmation boolean. Default-deny: a missing policy, a missing
-- rule, or an out-of-workspace path all deny. No adapter, provider, or MCP
-- server may bypass this module.

local types = require('ai.harness.types')

local M = {}

local RULES_MAX = 256

---@class AiHarnessToolRequest
---@field risk string one of types.RISK_CLASSES
---@field tool string namespaced tool name, e.g. 'fs.read'
---@field argv? string[] exact argv, never a shell string
---@field paths? string[] filesystem paths touched
---@field endpoints? string[] network endpoints touched
---@field workspace string run workspace root

---@class AiHarnessDecision
---@field decision 'allow'|'deny'|'approval'
---@field reason string
---@field risk string

---Create a policy. `config.default` is 'deny' unless explicitly 'allow';
---fail-closed is the default posture.
---@param config? table
---@return table? policy
---@return string? err
function M.new(config)
    config = config or {}
    if type(config) ~= 'table' then
        return nil, 'policy config must be a table when given'
    end
    local default = config.default or 'deny'
    if default ~= 'deny' and default ~= 'allow' then
        return nil, "policy default must be 'deny' or 'allow'"
    end
    local rules = config.rules or {}
    if type(rules) ~= 'table' then
        return nil, 'policy rules must be a table when given'
    end
    if #rules > RULES_MAX then
        return nil, 'policy rule count exceeds bound'
    end
    for i, rule in ipairs(rules) do
        local ok, err = M.validate_rule(rule)
        if not ok then
            return nil, 'policy rule ' .. i .. ': ' .. tostring(err)
        end
    end
    return {
        default = default,
        rules = rules,
        workspace = config.workspace,
    }
end

---Validate one rule: risk + decision required, optional tool/path/endpoint
---scopes as allowlists.
---@param rule table
---@return boolean ok
---@return string? err
function M.validate_rule(rule)
    if type(rule) ~= 'table' then
        return nil, 'rule must be a table'
    end
    if not types.is_valid_risk(rule.risk) then
        return nil, 'rule.risk must be a known risk class'
    end
    if rule.decision ~= 'allow' and rule.decision ~= 'deny' and rule.decision ~= 'approval' then
        return nil, "rule.decision must be 'allow', 'deny' or 'approval'"
    end
    for _, key in ipairs({ 'tools', 'paths', 'endpoints' }) do
        if rule[key] ~= nil and type(rule[key]) ~= 'table' then
            return nil, 'rule.' .. key .. ' must be a table when given'
        end
    end
    return true
end

---True when `path` stays inside `root`. Both must be absolute; lexical
---check only, no filesystem access.
---@param path string
---@param root string
---@return boolean
function M.path_in_workspace(path, root)
    if type(path) ~= 'string' or type(root) ~= 'string' then
        return false
    end
    if path:sub(1, 1) ~= '/' or root:sub(1, 1) ~= '/' then
        return false
    end
    if path == root then
        return true
    end
    local prefix = root:sub(-1) == '/' and root or (root .. '/')
    return path:sub(1, #prefix) == prefix
end

---Does `rule` match `request`? Risk must match; each present scope must
---contain at least one matching entry.
---@param rule table
---@param request AiHarnessToolRequest
---@return boolean
local function rule_matches(rule, request)
    if rule.risk ~= request.risk then
        return false
    end
    if rule.tools ~= nil then
        local hit = false
        for _, tool in ipairs(rule.tools) do
            if tool == request.tool then
                hit = true
                break
            end
        end
        if not hit then
            return false
        end
    end
    if rule.paths ~= nil then
        if request.paths == nil then
            return false
        end
        local hit = false
        for _, wanted in ipairs(rule.paths) do
            for _, got in ipairs(request.paths) do
                if M.path_in_workspace(got, wanted) then
                    hit = true
                    break
                end
            end
            if hit then
                break
            end
        end
        if not hit then
            return false
        end
    end
    if rule.endpoints ~= nil then
        if request.endpoints == nil then
            return false
        end
        local hit = false
        for _, wanted in ipairs(rule.endpoints) do
            for _, got in ipairs(request.endpoints) do
                if got == wanted then
                    hit = true
                    break
                end
            end
            if hit then
                break
            end
        end
        if not hit then
            return false
        end
    end
    return true
end

---Decide a tool request. First matching rule wins; no match falls back to
---the policy default. A nil policy denies: absence of policy is never
---implicit authorization.
---@param policy? table
---@param request AiHarnessToolRequest
---@return AiHarnessDecision
function M.decide(policy, request)
    if type(request) ~= 'table' then
        return { decision = 'deny', reason = 'malformed request', risk = 'irreversible' }
    end
    if not types.is_valid_risk(request.risk) then
        return { decision = 'deny', reason = 'unknown risk class', risk = 'irreversible' }
    end
    if policy == nil then
        return { decision = 'deny', reason = 'no policy configured', risk = request.risk }
    end
    local workspace = request.workspace or policy.workspace
    if request.paths ~= nil and workspace ~= nil then
        for _, path in ipairs(request.paths) do
            if not M.path_in_workspace(path, workspace) then
                return { decision = 'deny', reason = 'path escapes workspace: ' .. path, risk = request.risk }
            end
        end
    end
    for _, rule in ipairs(policy.rules) do
        if rule_matches(rule, request) then
            return { decision = rule.decision, reason = 'matched rule', risk = request.risk }
        end
    end
    return { decision = policy.default, reason = 'no rule matched', risk = request.risk }
end

return M
