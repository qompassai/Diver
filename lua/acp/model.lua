-- Normalized, bounded task/run state. Remote content is data, never executable code.
-- Copyright (C) 2025 Qompass AI, All rights reserved
local util = require('acp.util')
local M = {}
M.terminal = { completed = true, failed = true, canceled = true, rejected = true }
M.interrupted = { ['input-required'] = true, ['auth-required'] = true, awaiting = true }
M.states = {
    submitted = true,
    working = true,
    completed = true,
    failed = true,
    canceled = true,
    rejected = true,
    ['input-required'] = true,
    ['auth-required'] = true,
    awaiting = true,
    cancelling = true,
}

function M.list(value, maximum)
    return type(value) == 'table' and vim.islist(value) and #value <= maximum
end

function M.parts(parts, protocol, version)
    if not M.list(parts, 256) or #parts < 1 then
        return nil, 'Invalid message parts'
    end
    local result = {}
    for _, part in ipairs(parts) do
        if type(part) ~= 'table' then
            return nil, 'Part must be an object'
        end
        local value
        if protocol == 'acp-communication' then
            if not util.string(part.content_type, 256) then
                return nil, 'Missing Communication ACP content_type'
            end
            if part.content and part.content_url then
                return nil, 'Communication ACP part has both inline and URL content'
            end
            value =
                { mediaType = part.content_type, filename = part.name, metadata = part.metadata }
            if part.content_url then
                value.url = part.content_url
            elseif part.content_encoding == 'base64' then
                value.raw = part.content
            elseif part.content then
                value.text = part.content
            else
                value.data = part.metadata or vim.empty_dict()
            end
        elseif version == '0.3' then
            if part.kind == 'text' then
                value = { text = part.text }
            elseif part.kind == 'data' then
                value = { data = part.data }
            elseif part.kind == 'file' and type(part.file) == 'table' then
                value = {
                    url = part.file.uri,
                    raw = part.file.bytes,
                    filename = part.file.name,
                    mediaType = part.file.mimeType,
                }
            else
                return nil, 'Unknown A2A 0.3 part kind'
            end
        else
            value = vim.deepcopy(part)
        end
        local present = 0
        for _, key in ipairs({ 'text', 'raw', 'url', 'data' }) do
            if value[key] ~= nil then
                present = present + 1
                if key ~= 'data' and type(value[key]) ~= 'string' then
                    return nil, 'Invalid part content type'
                end
            end
        end
        if present ~= 1 then
            return nil, 'Part requires exactly one content field'
        end
        result[#result + 1] = value
    end
    local encoded, err = util.json(result)
    if not encoded or #encoded > 1024 * 1024 then
        return nil, err or 'Message part byte limit'
    end
    return result
end

function M.message(value, protocol, version)
    if type(value) ~= 'table' or not util.string(value.role, 128) then
        return nil, 'Invalid message role'
    end
    local parts, err = M.parts(value.parts, protocol, version)
    if not parts then
        return nil, err
    end
    local role = value.role == 'ROLE_USER' and 'user' or value.role
    role = role == 'ROLE_AGENT' and 'agent' or role
    if role ~= 'user' and role ~= 'agent' and not role:match('^agent/[%w_-]+$') then
        return nil, 'Unknown message role'
    end
    if protocol == 'a2a' and not util.string(value.messageId, 1024) then
        return nil, 'A2A message is missing messageId'
    end
    return { id = value.messageId, role = role, parts = parts }
end

---@return AgentModel
function M.new()
    return { messages = {}, artifacts = {}, artifact_order = {}, state = 'submitted', bytes = 0 }
end

local function message(state, value)
    if value.id then
        for index, previous in ipairs(state.messages) do
            if previous.id == value.id then
                state.messages[index] = value
                return true
            end
        end
    end
    if #state.messages >= 256 then
        return nil, 'Message count limit'
    end
    state.messages[#state.messages + 1] = value
    return true
end

local function artifact(state, value, append)
    if not util.string(value.id, 1024) then
        return nil, 'Missing artifact ID'
    end
    local previous = state.artifacts[value.id]
    if not previous then
        if #state.artifact_order >= 64 then
            return nil, 'Artifact count limit'
        end
        state.artifact_order[#state.artifact_order + 1] = value.id
    elseif append then
        local parts = vim.deepcopy(previous.parts)
        for _, part in ipairs(value.parts) do
            local last = parts[#parts]
            if last and last.text and part.text then
                last.text = last.text .. part.text
            else
                parts[#parts + 1] = part
            end
        end
        if #parts > 1024 then
            return nil, 'Artifact part count limit'
        end
        value.parts = parts
    end
    state.artifacts[value.id] = value
    return true
end

local function mutate(state, event)
    if event.id then
        if state.id and state.id ~= event.id then
            return nil, 'Task/run ID changed within an operation'
        end
        state.id = event.id
    end
    if event.context_id then
        if state.context_id and state.context_id ~= event.context_id then
            return nil, 'Context ID changed within an operation'
        end
        state.context_id = event.context_id
    end
    if event.state then
        if not M.states[event.state] then
            return nil, 'Unknown remote state'
        end
        if M.terminal[state.state] and event.state ~= state.state then
            return nil, 'Remote task changed after a terminal state'
        end
        state.state = event.state
    end
    if event.kind == 'snapshot' then
        state.messages, state.artifacts, state.artifact_order = {}, {}, {}
        for _, item in ipairs(event.messages or {}) do
            local ok, err = message(state, item)
            if not ok then
                return nil, err
            end
        end
        for _, item in ipairs(event.artifacts or {}) do
            local ok, err = artifact(state, item, false)
            if not ok then
                return nil, err
            end
        end
    elseif event.kind == 'message' then
        return message(state, event.message)
    elseif event.kind == 'artifact' then
        return artifact(state, event.artifact, event.append)
    end
    state.await_request = event.await_request
    return true
end

function M.apply(state, event)
    -- Transactional copy is bounded (4 MiB); rejected remote data cannot corrupt current state.
    local candidate = vim.deepcopy(state)
    local ok, err = mutate(candidate, event)
    if not ok then
        return nil, err
    end
    local encoded, failure = util.json(candidate)
    if not encoded or #encoded > 4 * 1024 * 1024 then
        return nil, failure or 'Task model byte limit'
    end
    for key in pairs(state) do
        state[key] = nil
    end
    for key, value in pairs(candidate) do
        state[key] = value
    end
    return true
end

function M.text(parts)
    local lines = {}
    for _, part in ipairs(parts or {}) do
        if type(part.text) == 'string' then
            lines[#lines + 1] = part.text
        elseif part.url then
            lines[#lines + 1] = '[Remote content URL, not fetched: ' .. part.url .. ']'
        elseif part.raw then
            lines[#lines + 1] = '[Inline binary content: ' .. tostring(part.mediaType) .. ']'
        else
            lines[#lines + 1] = '[Structured data] ' .. (util.json(part.data) or 'unavailable')
        end
    end
    return table.concat(lines, '\n')
end
return M
