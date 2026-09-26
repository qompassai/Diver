-- /qompassai/Diver/lua/ai/recon/gate.lua
-- Execution gate for recon/pentest tooling.
-- Copyright (C) 2026 Qompass AI, All rights reserved.
-- ----------------------------------------
--
-- Plain words: before any recon skill or CLI tool runs, it passes
-- through this gate. Two things always happen: the call is written
-- to the audit log (who, what, which target, when), and the safety
-- labels decide whether a human must confirm first.
--
-- Matt's standing rule for this tooling: it is authorized by
-- default. He only runs it against targets he is engaged to test,
-- so the gate does not nag him with a confirmation prompt on
-- every call. Set auto_authorize = false in setup() to get the
-- prompt back. The audit log stays on either way.
---@module 'ai.recon.gate'

local M = {}

local config = {
    auto_authorize = true,
}

---Configure the gate. Pass { auto_authorize = false } to require
---an explicit confirmation prompt before consequential tools run.
---@param opts? table
function M.setup(opts)
    opts = opts or {}
    if opts.auto_authorize ~= nil then
        assert(type(opts.auto_authorize) == 'boolean', 'auto_authorize must be a boolean')
        config.auto_authorize = opts.auto_authorize
    end
end

---Current authorization mode.
---@return boolean
function M.auto_authorize()
    return config.auto_authorize
end

---Check whether a tool call may proceed. The callback receives
---(allowed, reason). Logging happens for every call, allowed or not.
---@param tool string Tool or skill name
---@param target string Target host/scope the tool will touch
---@param annotations table WebMCP annotations for the tool
---@param via string Where the call comes from ('bridge', 'command', 'agent')
---@param callback fun(allowed: boolean, reason: string)
function M.check(tool, target, annotations, via, callback)
    assert(type(tool) == 'string', 'tool must be a string')
    assert(type(target) == 'string', 'target must be a string')
    assert(type(annotations) == 'table', 'annotations must be a table')
    assert(type(via) == 'string', 'via must be a string')
    assert(type(callback) == 'function', 'callback must be a function')

    local auditlog = require('ai.security.auditlog')
    local ann = require('ai.security.annotations')

    local needs_confirm = ann.needs_confirmation(annotations)
    if not needs_confirm then
        auditlog.append({ tool = tool, target = target, via = via, decision = 'allowed: read-only' })
        callback(true, 'allowed: read-only tool')
        return
    end
    if config.auto_authorize then
        auditlog.append({ tool = tool, target = target, via = via, decision = 'allowed: auto-authorized' })
        callback(true, 'allowed: auto-authorized for engaged targets')
        return
    end
    local security = require('ai.security')
    security.confirm_tool_call('recon', tool, { target = target }, function(allowed, reason)
        auditlog.append({
            tool = tool,
            target = target,
            via = via,
            decision = (allowed and 'allowed: ' or 'denied: ') .. reason,
        })
        callback(allowed, reason)
    end)
end

return M
