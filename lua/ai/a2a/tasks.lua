-- /qompassai/Diver/lua/ai/a2a/tasks.lua
-- Qompass AI A2A Task Supervisor (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Owns the local lifecycle of every agent task Neovim dispatches: a
-- bounded number run concurrently, overflow waits in a FIFO queue,
-- every task carries a timeout and a generation token so stale
-- callbacks from canceled tasks are ignored, and a subscriber list
-- lets the monitor UI stay live. This is the piece that makes many
-- async agents manageable instead of a pile of orphaned curl calls.

local uv = vim.uv

local agent_card = require('ai.a2a.agent_card')
local client = require('ai.a2a.client')

local M = {}

local MAX_CONCURRENT_TASKS = 8
local MAX_QUEUE_LEN = 64
local MAX_EVENTS_PER_TASK = 512
local MAX_ARTIFACTS_PER_TASK = 64
local MAX_RETAINED_TASKS = 128
local DEFAULT_TIMEOUT_MS = 600000

---@class A2aTask
---@field id integer Local task id.
---@field agent string Directory name or card name.
---@field card A2aAgentCard
---@field state string One of the A2A task states.
---@field remote_id? string Remote task id, once known.
---@field message string The prompt text sent.
---@field events table[] Bounded ring of raw stream events.
---@field artifacts table[] Bounded list of produced artifacts.
---@field error? string Failure or cancel reason.
---@field created_ms integer uv.now() at submit.
---@field generation integer Bumped on cancel; stale callbacks bail.
---@field started boolean True once dispatched (not merely queued).
---@field torn boolean True once teardown ran.
---@field handle any? Stream proc handle, while streaming.
---@field timer any? Timeout timer, while running.
---@field on_event? fun(task: A2aTask, event: table)
---@field on_done? fun(task: A2aTask)
---@field timeout_ms integer

local TERMINAL = { completed = true, failed = true, canceled = true }

local TRANSITIONS = {
    submitted = {
        working = true,
        ['input-required'] = true,
        completed = true,
        failed = true,
        canceled = true,
    },
    working = {
        working = true,
        ['input-required'] = true,
        completed = true,
        failed = true,
        canceled = true,
    },
    ['input-required'] = {
        working = true,
        completed = true,
        failed = true,
        canceled = true,
    },
}

---@type table<integer, A2aTask>
local tasks = {}
local queue = {}
local subscribers = {}
local running = 0
local next_id = 1

---@param event table
local function notify(event)
    for _, fn in ipairs(subscribers) do
        pcall(fn, event)
    end
end

---@param task A2aTask
---@param new_state string
local function set_state(task, new_state)
    if task.state == new_state then
        return
    end
    local allowed = TRANSITIONS[task.state]
    if allowed and allowed[new_state] then
        task.state = new_state
        notify({ type = 'state', id = task.id, state = new_state })
    end
    -- Unknown or illegal transitions are ignored: remote agents vary,
    -- and a stray state must never corrupt the supervisor.
end

---@param agent string|table Directory name or inline card.
---@return A2aAgentCard?, string?
local function resolve_agent(agent)
    if type(agent) == 'string' then
        local card = agent_card.get(agent)
        if not card then
            return nil, 'unknown A2A agent: ' .. agent
        end
        return card
    end
    local ok, err = agent_card.validate(agent)
    if not ok then
        return nil, err
    end
    return agent
end

---@param task A2aTask
local function teardown(task)
    if task.torn then
        return
    end
    task.torn = true
    if task.handle then
        pcall(task.handle.kill, task.handle, 15)
        task.handle = nil
    end
    if task.timer then
        task.timer:stop()
        task.timer:close()
        task.timer = nil
    end
    if task.started and running > 0 then
        running = running - 1
    end
end

-- Forward declarations: pump and finish_task call start_task and
-- evict_finished, which are defined further down. The locals must be
-- declared before any function that references them.
local start_task, evict_finished

local function pump()
    while running < MAX_CONCURRENT_TASKS and #queue > 0 do
        local entry = table.remove(queue, 1)
        start_task(entry.task, entry.card)
    end
end

---@param task A2aTask
---@param state string Terminal state to record.
---@param err? string
local function finish_task(task, state, err)
    -- Guard on teardown, not on state: a stream event may already
    -- have moved the task to a terminal state before this runs, and
    -- the teardown, queue pump, and callbacks must still run exactly
    -- once.
    if task.torn then
        return
    end
    set_state(task, state)
    task.error = err
    teardown(task)
    pump()
    evict_finished()
    notify({ type = 'settled', id = task.id, state = task.state })
    local on_done = task.on_done
    task.on_done = nil
    if on_done then
        vim.schedule(function()
            on_done(task)
        end)
    end
end

-- Forward declarations are above; no duplicates here.
---@param task A2aTask
---@param event table
local function on_stream_event(task, event)
    if #task.events >= MAX_EVENTS_PER_TASK then
        table.remove(task.events, 1)
    end
    task.events[#task.events + 1] = event

    local node = event.status or (event.result and event.result.status)
    if type(node) == 'table' and type(node.state) == 'string' then
        set_state(task, node.state)
    end

    local artifact = event.artifact or (event.result and event.result.artifact)
    if type(artifact) == 'table' then
        if #task.artifacts >= MAX_ARTIFACTS_PER_TASK then
            table.remove(task.artifacts, 1)
        end
        task.artifacts[#task.artifacts + 1] = artifact
    end

    local result_node = event.result
    local remote = event.taskId
    if remote == nil and type(result_node) == 'table' then
        remote = result_node.taskId or result_node.id
    end
    if type(remote) == 'string' and not task.remote_id then
        task.remote_id = remote
    end

    if task.on_event then
        task.on_event(task, event)
    end
    if TERMINAL[task.state] then
        finish_task(task, task.state, nil)
    end
end

---@param task A2aTask
---@param card A2aAgentCard
---@param alive fun(): boolean Generation-checked liveness probe.
local function dispatch_request(task, card, alive)
    local streaming = card.capabilities and card.capabilities.streaming
    if streaming == true then
        local handle = client.message_stream(card, task.message, function(event)
            if alive() then
                on_stream_event(task, event)
            end
        end, function(ok, err)
            if alive() then
                if ok then
                    -- Stream closed without a terminal state: treat a
                    -- task that was making progress as done.
                    finish_task(task, 'completed', nil)
                else
                    finish_task(task, 'failed', err)
                end
            end
        end)
        if handle then
            task.handle = handle
        else
            finish_task(task, 'failed', 'stream failed to start')
        end
    else
        client.message_send(card, task.message, {}, function(ok, result, err)
            if not alive() then
                return
            end
            if not ok then
                finish_task(task, 'failed', err)
                return
            end
            if type(result) == 'table' then
                local rid = result.taskId or result.id
                if type(rid) == 'string' then
                    task.remote_id = rid
                end
                local status = result.status
                local state_ok = type(status) == 'table' and type(status.state) == 'string'
                if state_ok then
                    set_state(task, status.state)
                end
                if type(result.artifacts) == 'table' then
                    for _, artifact in ipairs(result.artifacts) do
                        if #task.artifacts < MAX_ARTIFACTS_PER_TASK then
                            task.artifacts[#task.artifacts + 1] = artifact
                        end
                    end
                end
            end
            finish_task(task, 'completed', nil)
        end)
    end
end

start_task = function(task, card)
    task.started = true
    running = running + 1
    set_state(task, 'working')
    local gen = task.generation

    local function alive()
        local current = tasks[task.id]
        return current ~= nil and current.generation == gen and not TERMINAL[current.state]
    end

    local timer = uv.new_timer()
    if not timer then
        finish_task(task, 'failed', 'uv timer unavailable')
        return
    end
    task.timer = timer
    timer:start(task.timeout_ms, 0, function()
        vim.schedule(function()
            if alive() then
                M.cancel(task.id, 'timeout')
            end
        end)
    end)

    dispatch_request(task, card, alive)
    notify({ type = 'started', id = task.id })
end

evict_finished = function()
    local finished_ids = {}
    for id, task in pairs(tasks) do
        if TERMINAL[task.state] then
            finished_ids[#finished_ids + 1] = id
        end
    end
    if #finished_ids > MAX_RETAINED_TASKS then
        table.sort(finished_ids)
        for i = 1, #finished_ids - MAX_RETAINED_TASKS do
            tasks[finished_ids[i]] = nil
        end
    end
end

---@param opts table Submit options: agent, message, on_event?,
---  on_done?, timeout_ms?
---@return integer? Local task id, or nil plus an error.
---@return string?
function M.submit(opts)
    assert(type(opts) == 'table', 'opts must be a table')
    assert(type(opts.message) == 'string' and opts.message ~= '', 'message must be nonempty')
    local card, err = resolve_agent(opts.agent)
    if not card then
        return nil, err
    end
    if running >= MAX_CONCURRENT_TASKS and #queue >= MAX_QUEUE_LEN then
        return nil, 'A2A task queue is full'
    end
    local id = next_id
    next_id = next_id + 1
    ---@type A2aTask
    local task = {
        id = id,
        agent = card.name,
        card = card,
        state = 'submitted',
        message = opts.message,
        events = {},
        artifacts = {},
        created_ms = uv.now(),
        generation = 1,
        started = false,
        torn = false,
        timeout_ms = opts.timeout_ms or DEFAULT_TIMEOUT_MS,
        on_event = opts.on_event,
        on_done = opts.on_done,
    }
    tasks[id] = task
    if running < MAX_CONCURRENT_TASKS then
        start_task(task, card)
    else
        queue[#queue + 1] = { task = task, card = card }
    end
    notify({ type = 'submitted', id = id })
    return id
end

---@param id integer
---@param reason? string
---@return boolean True when a live task was canceled.
function M.cancel(id, reason)
    local task = tasks[id]
    if not task or TERMINAL[task.state] then
        return false
    end
    task.generation = task.generation + 1
    for i, entry in ipairs(queue) do
        if entry.task.id == id then
            table.remove(queue, i)
            break
        end
    end
    -- Best-effort remote cancel; the local state moves on regardless.
    if task.remote_id then
        client.task_cancel(task.card, task.remote_id, function() end)
    end
    finish_task(task, 'canceled', reason or 'canceled')
    return true
end

function M.cancel_all()
    local ids = {}
    for id, task in pairs(tasks) do
        if not TERMINAL[task.state] then
            ids[#ids + 1] = id
        end
    end
    table.sort(ids)
    for _, id in ipairs(ids) do
        M.cancel(id, 'canceled')
    end
end

---@param id integer
---@return A2aTask?
function M.get(id)
    return tasks[id]
end

---@return A2aTask[] All known tasks, oldest first.
function M.list()
    local out = {}
    for _, task in pairs(tasks) do
        out[#out + 1] = task
    end
    table.sort(out, function(a, b)
        return a.id < b.id
    end)
    return out
end

---@param fn fun(event: table)
function M.subscribe(fn)
    assert(type(fn) == 'function', 'subscriber must be a function')
    subscribers[#subscribers + 1] = fn
end

---@param fn fun(event: table)
function M.unsubscribe(fn)
    for i, sub in ipairs(subscribers) do
        if sub == fn then
            table.remove(subscribers, i)
            return
        end
    end
end

return M
