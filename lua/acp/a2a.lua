-- A2A 1.0 / explicitly selected 0.3 JSON-RPC binding; Agent Cards are data only.
-- Copyright (C) 2025 Qompass AI, All rights reserved
local http, model, util = require('acp.http'), require('acp.model'), require('acp.util')
local M = {}
local METHODS = {
    ['1.0'] = {
        send = 'SendMessage',
        stream = 'SendStreamingMessage',
        get = 'GetTask',
        cancel = 'CancelTask',
        subscribe = 'SubscribeToTask',
        list = 'ListTasks',
        extended = 'GetExtendedAgentCard',
    },
    ['0.3'] = {
        send = 'message/send',
        stream = 'message/stream',
        get = 'tasks/get',
        cancel = 'tasks/cancel',
        subscribe = 'tasks/resubscribe',
        extended = 'agent/getAuthenticatedExtendedCard',
    },
}
local STATES = {
    TASK_STATE_SUBMITTED = 'submitted',
    TASK_STATE_WORKING = 'working',
    TASK_STATE_COMPLETED = 'completed',
    TASK_STATE_FAILED = 'failed',
    TASK_STATE_CANCELED = 'canceled',
    TASK_STATE_REJECTED = 'rejected',
    TASK_STATE_INPUT_REQUIRED = 'input-required',
    TASK_STATE_AUTH_REQUIRED = 'auth-required',
}

function M.card(agent, card)
    if
        type(card) ~= 'table'
        or not util.string(card.name)
        or type(card.capabilities) ~= 'table'
        or not model.list(card.skills, 256)
    then
        return nil, 'Malformed Agent Card'
    end
    local interfaces = card.supportedInterfaces
    if agent.version == '0.3' then
        if card.protocolVersion ~= '0.3' and card.protocolVersion ~= '0.3.0' then
            return nil, 'Agent Card does not advertise A2A 0.3'
        end
        interfaces = {
            {
                url = card.url,
                protocolBinding = card.preferredTransport or 'JSONRPC',
                protocolVersion = '0.3',
            },
        }
        if not model.list(card.additionalInterfaces or {}, 31) then
            return nil, 'Invalid additional Agent Card interfaces'
        end
        for _, item in ipairs(card.additionalInterfaces or {}) do
            if type(item) ~= 'table' then
                return nil, 'Invalid Agent Card interface'
            end
            interfaces[#interfaces + 1] = {
                url = item.url,
                protocolBinding = item.transport,
                protocolVersion = '0.3',
            }
        end
    end
    if not model.list(interfaces, 32) then
        return nil, 'Missing or excessive Agent Card interfaces'
    end
    local chosen
    for _, item in ipairs(interfaces) do
        if
            type(item) == 'table'
            and type(item.url) == 'string'
            and item.url:gsub('/$', '') == agent.url
            and item.protocolBinding == 'JSONRPC'
            and item.protocolVersion == agent.version
        then
            chosen = item
            break
        end
    end
    if not chosen then
        return nil, 'Card must advertise the configured URL, JSONRPC binding, and protocol version'
    end
    if not model.list(card.capabilities.extensions or {}, 64) then
        return nil, 'Invalid Agent Card extensions'
    end
    for _, extension in ipairs(card.capabilities.extensions or {}) do
        if type(extension) ~= 'table' or extension.required then
            return nil, 'Agent requires an unsupported A2A extension'
        end
    end
    if chosen.tenant and not util.string(chosen.tenant, 1024) then
        return nil, 'Invalid tenant in Agent Card'
    end
    return { card = card, tenant = chosen.tenant, streaming = card.capabilities.streaming == true }
end

function M.discover(agent, callback)
    return http.request(agent, { url = agent.card_url }, function(value, err)
        if err then
            callback(nil, err)
            return
        end
        local peer, failure = M.card(agent, value)
        callback(peer, failure)
    end)
end

local function rpc_result(value, id)
    if type(value) ~= 'table' or value.jsonrpc ~= '2.0' or value.id ~= id then
        return nil, 'JSON-RPC response ID or version mismatch'
    end
    if value.error then
        if type(value.error) ~= 'table' then
            return nil, 'Malformed JSON-RPC error'
        end
        return nil,
            'A2A error ' .. tostring(value.error.code) .. ': ' .. util.display(value.error.message)
                :sub(1, 2048)
    end
    if type(value.result) ~= 'table' then
        return nil, 'Missing JSON-RPC result'
    end
    return value.result
end

function M.call(agent, peer, operation, params, callback, event)
    local method = METHODS[agent.version][operation]
    if not method then
        return nil, operation .. ' is unavailable in A2A ' .. agent.version
    end
    if operation == 'extended' then
        local available = agent.version == '1.0' and peer.card.capabilities.extendedAgentCard
            or peer.card.supportsAuthenticatedExtendedCard
        if not available then
            return nil, 'Extended Agent Card is not advertised'
        end
    end
    local streaming = operation == 'stream' or operation == 'subscribe'
    if streaming and not peer.streaming then
        return nil, 'Agent does not advertise streaming'
    end
    local id, err = util.id()
    if not id then
        return nil, err
    end
    params = vim.deepcopy(params or vim.empty_dict())
    if peer.tenant then
        params.tenant = peer.tenant
    end
    return http.request(agent, {
        url = agent.url,
        method = 'POST',
        stream = streaming,
        body = { jsonrpc = '2.0', id = id, method = method, params = params },
    }, function(value, failure, streamed)
        if failure or streamed then
            callback(nil, failure, streamed)
            return
        end
        local result, problem = rpc_result(value, id)
        callback(result, problem, false)
    end, streaming and function(value)
        local result, failure = rpc_result(value, id)
        if not result then
            return nil, failure
        end
        return event(result)
    end or nil)
end

local function status(value, version)
    if type(value) ~= 'table' then
        return nil, 'Missing task status'
    end
    local state = version == '0.3' and value.state or STATES[value.state]
    if not model.states[state] then
        return nil, 'Unknown A2A task status'
    end
    return state
end

local function artifact(value, version)
    if type(value) ~= 'table' or not util.string(value.artifactId, 1024) then
        return nil, 'Invalid A2A artifact'
    end
    local parts, err = model.parts(value.parts, 'a2a', version)
    if not parts then
        return nil, err
    end
    return { id = value.artifactId, name = value.name, parts = parts }
end

local function task(value, version)
    if
        type(value) ~= 'table'
        or not util.string(value.id, 1024)
        or not util.string(value.contextId, 1024)
    then
        return nil, 'Invalid A2A task identifiers'
    end
    local state, err = status(value.status, version)
    if not state then
        return nil, err
    end
    if not model.list(value.history or {}, 256) or not model.list(value.artifacts or {}, 64) then
        return nil, 'A2A task collection limit'
    end
    local event = {
        kind = 'snapshot',
        id = value.id,
        context_id = value.contextId,
        state = state,
        messages = {},
        artifacts = {},
    }
    for _, item in ipairs(value.history or {}) do
        local message, failure = model.message(item, 'a2a', version)
        if not message then
            return nil, failure
        end
        event.messages[#event.messages + 1] = message
    end
    if value.status.message then
        local message, failure = model.message(value.status.message, 'a2a', version)
        if not message then
            return nil, failure
        end
        event.messages[#event.messages + 1] = message
    end
    for _, item in ipairs(value.artifacts or {}) do
        local content, failure = artifact(item, version)
        if not content then
            return nil, failure
        end
        event.artifacts[#event.artifacts + 1] = content
    end
    return event
end

function M.decode(value, version, direct_task)
    if type(value) ~= 'table' then
        return nil, 'Invalid A2A response object'
    end
    if direct_task then
        return task(value, version)
    end
    local kind, item
    if version == '0.3' then
        kind, item = value.kind, value
    else
        local count = 0
        for _, key in ipairs({ 'task', 'message', 'statusUpdate', 'artifactUpdate' }) do
            if value[key] then
                kind, item, count = key, value[key], count + 1
            end
        end
        if count ~= 1 then
            return nil, 'A2A response requires exactly one payload'
        end
    end
    if kind == 'task' then
        return task(item, version)
    end
    if type(item) ~= 'table' then
        return nil, 'Missing A2A payload'
    end
    if kind == 'message' then
        if version == '1.0' and not util.string(item.contextId, 1024) then
            return nil, 'A2A server message is missing contextId'
        end
        local message, err = model.message(item, 'a2a', version)
        if not message then
            return nil, err
        end
        local result = {
            kind = 'message',
            message = message,
            context_id = item.contextId,
            id = item.taskId,
        }
        if not item.taskId then
            result.state = 'completed'
        end
        return result
    end
    if not util.string(item.taskId, 1024) or not util.string(item.contextId, 1024) then
        return nil, 'Missing A2A update identifiers'
    end
    local event = { id = item.taskId, context_id = item.contextId }
    if kind == 'statusUpdate' or kind == 'status-update' then
        local state, err = status(item.status, version)
        if not state then
            return nil, err
        end
        event.kind, event.state = 'status', state
        if item.status.message then
            event.message, err = model.message(item.status.message, 'a2a', version)
            if not event.message then
                return nil, err
            end
            event.kind = 'message'
        end
    elseif kind == 'artifactUpdate' or kind == 'artifact-update' then
        local content, err = artifact(item.artifact, version)
        if not content then
            return nil, err
        end
        event.kind, event.artifact, event.append = 'artifact', content, item.append == true
    else
        return nil, 'Unsupported A2A event kind'
    end
    return event
end

function M.send(agent, peer, text_parts, previous, callback, event)
    local id, err = util.id()
    if not id then
        return nil, err
    end
    local parts = {}
    for _, part in ipairs(text_parts) do
        parts[#parts + 1] = agent.version == '0.3' and { kind = 'text', text = part.text }
            or { text = part.text, mediaType = 'text/plain' }
    end
    local message = { messageId = id, role = 'ROLE_USER', parts = parts }
    local configuration = {
        acceptedOutputModes = { 'text/plain', 'application/json' },
        historyLength = 64,
        returnImmediately = true,
    }
    if agent.version == '0.3' then
        message.role, message.kind = 'user', 'message'
        configuration.returnImmediately, configuration.blocking = nil, false
    end
    if previous then
        message.contextId = previous.context_id
        if model.interrupted[previous.state] then
            message.taskId = previous.id
        end
    end
    local operation = agent.streaming and peer.streaming and 'stream' or 'send'
    return M.call(
        agent,
        peer,
        operation,
        { message = message, configuration = configuration },
        callback,
        event
    )
end
return M
