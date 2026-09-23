-- Historical Agent Communication Protocol REST adapter (OpenAPI 0.2.0 snapshot).
-- Copyright (C) 2025 Qompass AI, All rights reserved
local http, model, util = require('acp.http'), require('acp.model'), require('acp.util')
local M = {}
local STATES = {
    created = 'submitted',
    ['in-progress'] = 'working',
    awaiting = 'awaiting',
    cancelling = 'cancelling',
    cancelled = 'canceled',
    completed = 'completed',
    failed = 'failed',
}

function M.discover(agent, callback)
    return http.request(
        agent,
        { url = agent.url .. '/agents/' .. util.escape(agent.agent_name) },
        function(value, err)
            if err then
                callback(nil, err)
                return
            end
            if type(value) ~= 'table' or value.name ~= agent.agent_name then
                callback(nil, 'Agent manifest does not match configured agent_name')
                return
            end
            callback({ card = value, streaming = agent.streaming })
        end
    )
end

function M.call(agent, _, operation, params, callback, event)
    local paths = {
        agents = '/agents',
        get = '/runs/',
        cancel = '/runs/',
        events = '/runs/',
        session = '/session/',
    }
    if not paths[operation] then
        return nil, 'Unsupported Communication ACP operation'
    end
    local path = paths[operation]
    if operation ~= 'agents' then
        if not util.string(params.id, 1024) then
            return nil, 'Missing run/session ID'
        end
        path = path .. util.escape(params.id)
    end
    if operation == 'cancel' then
        path = path .. '/cancel'
    end
    if operation == 'events' then
        path = path .. '/events'
    end
    return http.request(agent, {
        url = agent.url .. path,
        method = operation == 'cancel' and 'POST' or 'GET',
    }, callback, event)
end

function M.decode(value)
    if type(value) ~= 'table' then
        return nil, 'Invalid Communication ACP response'
    end
    if value.type then
        if value.type == 'error' then
            return nil, 'Communication ACP stream error'
        end
        if
            value.type == 'message.created'
            or value.type == 'message.part'
            or value.type == 'generic'
        then
            -- Run snapshots are authoritative; partial messages are retained in the wire inspector.
            return { kind = 'progress', detail = value }
        end
        if value.type == 'message.completed' then
            local message, err = model.message(value.message, 'acp-communication')
            if not message then
                return nil, err
            end
            return { kind = 'message', message = message }
        end
        if type(value.run) ~= 'table' then
            return nil, 'Unknown Communication ACP event'
        end
        value = value.run
    end
    if
        not util.string(value.run_id, 1024)
        or not STATES[value.status]
        or not model.list(value.output, 256)
    then
        return nil, 'Invalid Communication ACP run'
    end
    if
        value.await_request ~= nil
        and value.await_request ~= vim.NIL
        and type(value.await_request) ~= 'table'
    then
        return nil, 'Invalid Communication ACP await_request'
    end
    local event = {
        kind = 'snapshot',
        id = value.run_id,
        context_id = value.session_id,
        state = STATES[value.status],
        messages = {},
        await_request = value.await_request,
    }
    for _, item in ipairs(value.output) do
        local message, err = model.message(item, 'acp-communication')
        if not message then
            return nil, err
        end
        event.messages[#event.messages + 1] = message
    end
    if event.await_request == vim.NIL then
        event.await_request = nil
    end
    return event
end

function M.send(agent, _, text_parts, previous, callback, event, resume)
    local parts = {}
    for _, part in ipairs(text_parts) do
        parts[#parts + 1] = { content_type = 'text/plain', content = part.text }
    end
    local body = {
        agent_name = agent.agent_name,
        input = { { role = 'user', parts = parts } },
        mode = agent.run_mode or (agent.streaming and 'stream' or 'async'),
    }
    local path = '/runs'
    if previous then
        body.session_id = previous.context_id
    end
    if resume then
        if not previous or previous.state ~= 'awaiting' or not previous.id then
            return nil, 'Only awaiting runs can be resumed'
        end
        body = { run_id = previous.id, await_resume = resume, mode = body.mode }
        path = path .. '/' .. util.escape(previous.id)
    elseif previous and previous.state == 'awaiting' then
        return nil, 'Use AcpResume with the agent-specific await_resume JSON object'
    end
    return http.request(
        agent,
        { url = agent.url .. path, method = 'POST', body = body, stream = body.mode == 'stream' },
        callback,
        event
    )
end
return M
