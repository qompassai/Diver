-- /qompassai/Diver/lua/phlow/schemas.lua
-- Versioned Phlow API schemas: command names, required params, event names.
-- Copyright (C) 2026 Qompass AI, All rights reserved.
-- ----------------------------------------
--
-- Plain words: this is the menu of everything Diver is allowed to ask
-- Phlow to do. Every command lists the details it must have; if a call
-- is missing one, the client refuses it before anything goes on the
-- wire. Event names are the announcements Phlow can send back.
---@module 'phlow.schemas'

local M = {}

---Command name constants (API v1).
M.CMD = {
    APPROVAL_REQUEST = 'approval.request',
    ARTIFACT_GET = 'artifact.get',
    DEBUG_EVENT = 'debug.event',
    DEBUG_START = 'debug.start',
    SESSION_START = 'session.start',
    SESSION_STOP = 'session.stop',
    WORKFLOW_SUBMIT = 'workflow.submit',
}

---@class PhlowCommandSchema
---@field required string[] param names the server requires

---Validation table: command name -> schema. Mirrors schemas/commands.
---@type table<string, PhlowCommandSchema>
M.COMMANDS = {
    ['approval.request'] = { required = { 'session_id', 'prompt' } },
    ['artifact.get'] = { required = { 'session_id', 'name' } },
    ['debug.event'] = { required = { 'session_id', 'event' } },
    ['debug.start'] = { required = { 'session_id' } },
    ['session.start'] = { required = { 'task' } },
    ['session.stop'] = { required = { 'session_id' } },
    ['workflow.submit'] = { required = { 'workflow' } },
}

---Event name constants (API v1). Mirrors schemas/events.
M.EVENT = {
    APPROVAL_REQUESTED = 'approval.requested',
    APPROVAL_RESOLVED = 'approval.resolved',
    ARTIFACT_READY = 'artifact.ready',
    DEBUG_EVENT = 'debug.event',
    ERROR = 'error',
    SESSION_OUTPUT = 'session.output',
    SESSION_STARTED = 'session.started',
    SESSION_STOPPED = 'session.stopped',
    WORKFLOW_COMPLETED = 'workflow.completed',
}

---Check a command's params against its schema, before sending.
---@param cmd string command name
---@param params any caller-supplied params (must be a table)
---@return boolean ok
---@return string? err
function M.validate(cmd, params)
    assert(type(cmd) == 'string', 'cmd must be a string')
    local schema = M.COMMANDS[cmd]
    if schema == nil then
        return false, 'unknown command: ' .. cmd
    end
    if type(params) ~= 'table' then
        return false, 'params must be a table for command: ' .. cmd
    end
    for _, name in ipairs(schema.required) do
        if params[name] == nil then
            return false, 'missing required param "' .. name .. '" for command: ' .. cmd
        end
    end
    return true, nil
end

return M
