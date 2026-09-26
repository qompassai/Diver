-- /qompassai/Diver/lua/ai/bulk.lua
-- Bulk execution lane for the ai/ socket servers (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved.
-- ----------------------------------------
--
-- Plain words: ai.sched decides the ORDER requests run in; this
-- module decides HOW bulk requests run. A bulk backend function
-- takes (params, cb) and must call cb exactly once with
-- (backend_ok, result_or_err). The waiting happens off the main
-- loop (async vim.system, uv timers), so control requests keep
-- flowing while bulk work is in flight. Use
-- bulk.assert_callback_fn in set_backend to wire the contract:
-- a sync function here would never call cb and its requests would
-- hang, so the mismatch fails fast with a clear message.
--
-- Two bounds keep the lane honest:
-- * max_inflight: at most this many bulk requests run at once.
-- * max_waiting: at most this many extra requests wait their turn
--   in a FIFO queue; beyond that the server answers 'server busy'
--   instead of growing memory without limit. Waiting work is
--   drained only when an in-flight request completes — nothing is
--   requeued or retried, so there is no busy loop.
-- * watchdog_ms: a request whose backend never calls back is failed
--   with a timeout, so one hung backend cannot wedge the lane
--   forever. Must exceed the slowest legitimate bulk backend.

local M = {}

---@class AiBulkLane
---@field send_reply fun(client: uv.uv_pipe_t, state: table, reply: table, close: boolean)
---@field send_backend_result fun(client: uv.uv_pipe_t, state: table, pcall_ok: boolean,
---    backend_ok: boolean, result: any)
---@field max_inflight integer
---@field max_waiting integer
---@field watchdog_ms integer
---@field inflight integer
---@field waiting table<integer, table> FIFO of {client, state, line, params, backend_fn}

local AiBulkLane = {}
AiBulkLane.__index = AiBulkLane

---@param opts table
---@field opts.send_reply function
---@field opts.send_backend_result function
---@field opts.max_inflight integer
---@field opts.max_waiting? integer
---@field opts.watchdog_ms integer
---@field opts.client_closed_fn? fun(client: uv.uv_pipe_t): boolean
---@return AiBulkLane
function M.new(opts)
    assert(type(opts) == 'table', 'opts must be a table')
    assert(type(opts.send_reply) == 'function', 'opts.send_reply is required')
    assert(type(opts.send_backend_result) == 'function', 'opts.send_backend_result is required')
    assert(type(opts.max_inflight) == 'number' and opts.max_inflight >= 1, 'opts.max_inflight must be >= 1')
    assert(type(opts.watchdog_ms) == 'number' and opts.watchdog_ms >= 1, 'opts.watchdog_ms must be >= 1')
    local max_waiting = opts.max_waiting or 64
    assert(type(max_waiting) == 'number' and max_waiting >= 1, 'opts.max_waiting must be >= 1')
    return setmetatable({
        send_reply = opts.send_reply,
        send_backend_result = opts.send_backend_result,
        max_inflight = math.floor(opts.max_inflight),
        max_waiting = math.floor(max_waiting),
        watchdog_ms = math.floor(opts.watchdog_ms),
        client_closed_fn = opts.client_closed_fn,
        inflight = 0,
        waiting = {},
    }, AiBulkLane)
end

---Fail fast when a bulk backend function does not take (params, cb).
---@param fn any
---@param name string backend table key, for the error message
function M.assert_callback_fn(fn, name)
    assert(type(fn) == 'function', 'backend.' .. name .. ' must be a function')
    local info = debug.getinfo(fn, 'u')
    local takes_callback = info ~= nil and info.nparams == 2 and info.isvararg == false
    assert(takes_callback, 'backend.' .. name .. ' must take (params, cb)')
end

---@param client uv.uv_pipe_t
---@return boolean closed
local function client_is_closed(self, client, state)
    if state ~= nil and state.closed then
        return true
    end
    if self.client_closed_fn ~= nil then
        local ok, closed = pcall(self.client_closed_fn, client)
        return ok and closed == true
    end
    return false
end

---Start one bulk request now. The backend runs and calls cb exactly
---once, off the main loop; the reply is sent when it fires.
---@param client uv.uv_pipe_t
---@param state table
---@param params table validated request params
---@param backend_fn fun(params: table, cb: fun(backend_ok: boolean, result_or_err: any))
local function start_one(self, client, state, params, backend_fn)
    self.inflight = self.inflight + 1
    local finished = false
    local timer = vim.uv.new_timer()
    local function done(backend_ok, result_or_err)
        if finished then
            return
        end
        finished = true
        if timer ~= nil then
            timer:stop()
            timer:close()
        end
        self.inflight = self.inflight - 1
        -- Drain one waiting request, if any, now that a slot is free.
        -- Closed clients are discarded without running their backend.
        while #self.waiting > 0 and self.inflight < self.max_inflight do
            local next_req = table.remove(self.waiting, 1)
            if not client_is_closed(self, next_req.client, next_req.state) then
                start_one(self, next_req.client, next_req.state, next_req.params, next_req.backend_fn)
                break
            end
        end
        if client_is_closed(self, client, state) then
            return
        end
        self.send_backend_result(client, state, true, backend_ok, result_or_err)
    end
    if timer ~= nil then
        local watchdog_ms = self.watchdog_ms
        timer:start(watchdog_ms, 0, function()
            -- The timer fires in fast-event context; the reply path
            -- (JSON encode + socket write) runs on the main loop.
            vim.schedule(function()
                done(false, 'bulk request timed out after ' .. tostring(watchdog_ms) .. 'ms')
            end)
        end)
    end
    local ok, err = pcall(backend_fn, params, done)
    if not ok then
        done(false, 'backend raised: ' .. tostring(err))
    end
end

---Queue one bulk request. At the in-flight cap the request waits in
---a bounded FIFO; at the waiting cap the server answers 'server
---busy'. Safe to call from a pump turn: the waiting path only
---appends, never recurses or retries.
---@param client uv.uv_pipe_t
---@param state table
---@param line string the framed request, kept for error context
---@param params table validated request params
---@param backend_fn fun(params: table, cb: fun(backend_ok: boolean, result_or_err: any))
function AiBulkLane:run(client, state, line, params, backend_fn)
    assert(type(line) == 'string', 'line must be a string')
    assert(type(params) == 'table', 'params must be a table')
    assert(type(backend_fn) == 'function', 'backend_fn must be a function')
    if self.inflight >= self.max_inflight then
        if #self.waiting >= self.max_waiting then
            self.send_reply(client, state, { ok = false, error = 'server busy' }, false)
            return
        end
        self.waiting[#self.waiting + 1] = {
            client = client,
            state = state,
            line = line,
            params = params,
            backend_fn = backend_fn,
        }
        return
    end
    start_one(self, client, state, params, backend_fn)
end

---How many requests are waiting for a free in-flight slot.
---@return integer
function AiBulkLane:waiting_count()
    return #self.waiting
end

return M
