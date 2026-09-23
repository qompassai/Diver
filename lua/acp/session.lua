-- One owner for each conversation, HTTP request, polling timer and generation.
-- Copyright (C) 2025 Qompass AI, All rights reserved
local config, model, util = require('acp.config'), require('acp.model'), require('acp.util')
local M = { sessions = {} }
local SESSIONS_MAX, POLLS_MAX, WIRE_RECORDS_MAX = 16, 300, 128

local function adapter(state)
    return require(state.agent.protocol == 'a2a' and 'acp.a2a' or 'acp.communication')
end

local function changed(state)
    if state.render_pending or state.closed then
        return
    end
    state.render_pending = true
    vim.schedule(function()
        state.render_pending = false
        if not state.closed then
            require('acp.ui').render(state)
        end
    end)
end

local function stop_observing(state)
    state.generation = state.generation + 1
    util.close_timer(state.timer)
    util.close_timer(state.deadline)
    state.timer, state.deadline = nil, nil
    local request = state.request
    state.request = nil
    if request then
        request.cancel()
    end
end

local function finish(state, err)
    state.busy, state.error = false, err
    util.close_timer(state.timer)
    util.close_timer(state.deadline)
    state.timer, state.deadline, state.request = nil, nil, nil
    local callback = state.callback
    state.callback = nil
    local saved, failure = require('acp.store').save(state)
    if not saved then
        util.notify(failure)
    end
    changed(state)
    util.call(callback, err and nil or state, err)
end

local function begin(state, callback)
    if state.closed or state.busy then
        return nil, 'Conversation is closed or busy'
    end
    state.generation = state.generation + 1
    state.busy, state.error, state.callback, state.polls = true, nil, callback, 0
    local generation = state.generation
    state.deadline = util.timer(config.options.timeouts.turn_ms, function()
        if state.generation == generation and state.busy then
            stop_observing(state)
            finish(state, 'Observation deadline reached; remote work may continue. Use AcpRefresh.')
        end
    end)
    changed(state)
    return generation
end

---@param name string
---@param cwd? string
---@return AgentSession? state
---@return string? error
function M.create(name, cwd)
    if vim.tbl_count(M.sessions) >= SESSIONS_MAX then
        return nil, 'Conversation limit (16)'
    end
    local agent = config.options.agents[name]
    if not agent then
        return nil, 'Configure a trusted HTTP agent first'
    end
    local root, err = util.root(cwd or require('acp.context').root())
    if not root then
        return nil, err
    end
    local key, failure = util.id()
    if not key then
        return nil, failure
    end
    local state = {
        key = key,
        agent_name = name,
        agent = vim.deepcopy(agent),
        cwd = root,
        generation = 0,
        busy = false,
        closed = false,
        remote = model.new(),
        wire = {},
        wire_bytes = 0,
        depth = 0,
        prompt_parts = {},
    }
    M.sessions[key], M.current = state, key
    return state
end

---@param key? string
---@return AgentSession?
function M.get(key)
    return M.sessions[key or M.current]
end

function M.discover(state, callback)
    local generation, err = begin(state, callback)
    if not generation then
        return nil, err
    end
    local request, failure = adapter(state).discover(state.agent, function(peer, problem)
        if state.closed or state.generation ~= generation then
            return
        end
        if peer then
            state.peer = peer
        end
        finish(state, problem)
    end)
    if not request then
        finish(state, failure)
        return nil, failure
    end
    state.request = request
    return true
end

local function receive(state, value, direct)
    local event, err = adapter(state).decode(value, state.agent.version, direct)
    if not event then
        return nil, err
    end
    local ok, failure = model.apply(state.remote, event)
    if not ok then
        return nil, failure
    end
    local encoded = util.json(value)
    if
        encoded
        and state.wire_bytes + #encoded <= 1024 * 1024
        and #state.wire < WIRE_RECORDS_MAX
    then
        state.wire[#state.wire + 1] = value
        state.wire_bytes = state.wire_bytes + #encoded
    end
    changed(state)
    return true
end

local poll
local function response(state, generation, direct)
    return function(value, err, streamed)
        if state.closed or state.generation ~= generation then
            return
        end
        state.request = nil
        if err then
            finish(state, err)
            return
        end
        if not streamed then
            local ok, failure = receive(state, value, direct)
            if not ok then
                finish(state, failure)
                return
            end
        end
        if model.terminal[state.remote.state] or model.interrupted[state.remote.state] then
            finish(state)
        elseif state.remote.id then
            state.timer = util.timer(config.options.timeouts.poll_ms, function()
                if state.generation == generation and state.busy and not state.closed then
                    poll(state, generation)
                end
            end)
        else
            finish(state, 'Response ended without a task/run ID or a completed message')
        end
    end
end

poll = function(state, generation)
    state.polls = state.polls + 1
    if state.polls > POLLS_MAX then
        finish(state, 'Polling limit; use AcpRefresh')
        return
    end
    local request, err = adapter(state).call(
        state.agent,
        state.peer,
        'get',
        { id = state.remote.id, historyLength = 64 },
        response(state, generation, true)
    )
    if not request then
        finish(state, err)
        return
    end
    state.request = request
end

local function validate_parts(parts)
    if not model.list(parts, 32) or #parts == 0 then
        return nil, 'Select 1–32 text parts'
    end
    local bytes = 0
    for _, part in ipairs(parts) do
        if type(part) ~= 'table' or not util.string(part.text, 1024 * 1024) then
            return nil, 'Prompt parts must contain nonempty text'
        end
        bytes = bytes + #part.text
    end
    if bytes > 1024 * 1024 then
        return nil, 'Prompt exceeds 1 MiB'
    end
    return true
end

---@param state AgentSession
---@param parts AgentTextPart[]
---@param callback? AgentCallback
---@param resume? table
---@return boolean? ok
---@return string? error
function M.send(state, parts, callback, resume)
    if not state.peer then
        return nil, 'Discover this agent before sending'
    end
    if
        state.remote.id
        and not model.terminal[state.remote.state]
        and not model.interrupted[state.remote.state]
    then
        return nil, 'Refresh or cancel the unfinished remote task/run before sending again'
    end
    local valid, err = validate_parts(parts)
    if not valid then
        return nil, err
    end
    local previous = vim.deepcopy(state.remote)
    if resume and (type(resume) ~= 'table' or vim.islist(resume)) then
        return nil, 'await_resume must be a JSON object'
    end
    local generation, failure = begin(state, callback)
    if not generation then
        return nil, failure
    end
    state.prompt_parts, state.wire, state.wire_bytes = vim.deepcopy(parts), {}, 0
    state.remote = model.new()
    if model.interrupted[previous.state] then
        state.remote.id, state.remote.context_id = previous.id, previous.context_id
    end
    local request, problem = adapter(state).send(
        state.agent,
        state.peer,
        parts,
        previous,
        response(state, generation, false),
        function(value)
            if state.closed or state.generation ~= generation then
                return true
            end
            return receive(state, value, false)
        end,
        resume
    )
    if not request then
        state.remote = previous
        finish(state, problem)
        return nil, problem
    end
    state.request = request
    return true
end

function M.refresh(state, callback)
    if not state.peer or not state.remote.id then
        return nil, 'No remote task/run to inspect'
    end
    local generation, err = begin(state, callback)
    if not generation then
        return nil, err
    end
    poll(state, generation)
    return true
end

function M.cancel(state, callback)
    if state.closed then
        return nil, 'Conversation is closed'
    end
    stop_observing(state)
    if state.busy then
        finish(state, 'Local observation stopped')
    end
    if not state.remote.id then
        return nil, 'Remote ID is unknown; remote cancellation cannot be confirmed'
    end
    local generation, err = begin(state, callback)
    if not generation then
        return nil, err
    end
    local request, failure = adapter(state).call(
        state.agent,
        state.peer,
        'cancel',
        { id = state.remote.id },
        response(state, generation, true)
    )
    if not request then
        finish(state, failure)
        return nil, failure
    end
    state.request = request
    return true
end

function M.subscribe(state, callback)
    if state.agent.protocol ~= 'a2a' or not state.peer or not state.remote.id then
        return nil, 'Subscription requires a discovered A2A peer and task ID'
    end
    local generation, err = begin(state, callback)
    if not generation then
        return nil, err
    end
    local request, failure = adapter(state).call(
        state.agent,
        state.peer,
        'subscribe',
        { id = state.remote.id },
        response(state, generation, false),
        function(value)
            if state.closed or state.generation ~= generation then
                return true
            end
            return receive(state, value, false)
        end
    )
    if not request then
        finish(state, failure)
        return nil, failure
    end
    state.request = request
    return true
end

function M.inspect(state, operation, params, callback, event)
    if not state.peer then
        return nil, 'Discover this agent first'
    end
    local generation, err = begin(state, function(_, failure)
        if failure then
            util.call(callback, nil, failure)
        end
    end)
    if not generation then
        return nil, err
    end
    local request, failure = adapter(state).call(
        state.agent,
        state.peer,
        operation,
        params,
        function(value, problem, streamed)
            if state.closed or state.generation ~= generation then
                return
            end
            if not problem then
                state.callback = nil
                util.call(callback, value, nil, streamed)
            end
            finish(state, problem)
        end,
        event
    )
    if not request then
        finish(state, failure)
        return nil, failure
    end
    state.request = request
    return true
end

---@param state? AgentSession
---@return boolean
function M.close(state)
    if not state or state.closed then
        return true
    end
    stop_observing(state)
    if state.busy then
        finish(state, 'Conversation closed; remote work may continue')
    end
    state.closed = true
    require('acp.ui').close(state)
    M.sessions[state.key] = nil
    if M.current == state.key then
        M.current = nil
    end
    return true
end

function M.stop_all()
    for _, state in pairs(M.sessions) do
        M.close(state)
    end
end
return M
