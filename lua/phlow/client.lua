-- /qompassai/Diver/lua/phlow/client.lua
-- Phlow API client: requests, notifications, events over a transport.
-- Copyright (C) 2026 Qompass AI, All rights reserved.
-- ----------------------------------------
--
-- Plain words: this is the clerk who talks to Phlow. You hand it a
-- command and the details; it checks the menu (schemas), sends the
-- letter, and waits for the stamped reply. Every letter carries a
-- number so replies cannot get mixed up, and nobody waits forever:
-- each request has its own timer. Presentation side only: it keeps
-- no workflow state, it just delivers messages and announcements.
---@module 'phlow.client'

local schemas = require('phlow.schemas')

local M = {}

---Default bound for one request round-trip.
---@type integer milliseconds
M.DEFAULT_TIMEOUT_MS = 30000

---Cap on in-flight requests; the oldest is evicted with an error.
---@type integer
M.MAX_PENDING = 256

---Cap on one buffered wire frame; larger lines are dropped as garbage.
---@type integer bytes
M.MAX_FRAME_BYTES = 1048576

---@class PhlowClientOpts
---@field timeout_ms? integer per-request timeout (default 30000)

---@class PhlowPendingEntry
---@field finished boolean set when the request resolved
---@field result any decoded result on success
---@field err string? failure reason
---@field timer userdata? uv timer for the request timeout

---@class PhlowClient
---@field _transport PhlowTransportHandle
---@field _timeout_ms integer
---@field _seq integer next request id
---@field _pending table<string, PhlowPendingEntry>
---@field _pending_order string[] ids, oldest first
---@field _listeners table<string, fun(name: string, params: any)[]>
---@field _buf string partial wire frame
---@field _closed boolean
local Client = {}
Client.__index = Client

---Build a client over a connected transport handle.
---@param transport PhlowTransportHandle connected handle
---@param opts? PhlowClientOpts
---@return PhlowClient
function M.new(transport, opts)
    assert(transport ~= nil, 'transport is required')
    opts = opts or {}
    assert(type(opts) == 'table', 'opts must be a table')
    local timeout_ms = opts.timeout_ms or M.DEFAULT_TIMEOUT_MS
    assert(type(timeout_ms) == 'number' and timeout_ms > 0, 'timeout_ms must be positive')
    local self = setmetatable({
        _transport = transport,
        _timeout_ms = timeout_ms,
        _seq = 0,
        _pending = {},
        _pending_order = {},
        _listeners = {},
        _buf = '',
        _closed = false,
    }, Client)
    transport:on_data(function(chunk)
        self:_on_chunk(chunk)
    end)
    return self
end

---Remove a pending request's id from the tracking tables.
---@param id string
function Client:_drop_pending(id)
    self._pending[id] = nil
    for i, other in ipairs(self._pending_order) do
        if other == id then
            table.remove(self._pending_order, i)
            break
        end
    end
end

---Release a pending request: forget the id and stop its timer, once.
---@param id string
function Client:_release_pending(id)
    local entry = self._pending[id]
    if entry == nil then
        return
    end
    if entry.timer ~= nil then
        local timer = entry.timer
        entry.timer = nil
        pcall(timer.stop, timer)
        pcall(timer.close, timer)
    end
    self:_drop_pending(id)
end

---Fail one pending entry with an error and mark it finished.
---@param id string
---@param err string
function Client:_fail_pending(id, err)
    local entry = self._pending[id]
    if entry == nil then
        return
    end
    self:_release_pending(id)
    entry.err = err
    entry.finished = true
end

---Keep the pending table bounded: evict the oldest with an error.
function Client:_enforce_pending_cap()
    while #self._pending_order > M.MAX_PENDING do
        local oldest = table.remove(self._pending_order, 1)
        if oldest ~= nil then
            self:_fail_pending(oldest, 'pending queue full; oldest request evicted')
        end
    end
end

---Route one decoded wire frame to a pending request or event listeners.
---@param frame table decoded JSON frame
function Client:_on_frame(frame)
    if type(frame.id) == 'string' then
        self:_on_response(frame)
    elseif type(frame.event) == 'string' then
        self:_on_event_frame(frame)
    end
end

---Match a response frame to its request by id.
---@param frame table
function Client:_on_response(frame)
    local id = frame.id --[[@as string]]
    local entry = self._pending[id]
    if entry == nil then
        return -- stale or unknown id; ignore
    end
    local err = nil
    local result = nil
    if frame.v ~= nil and frame.v ~= '1' then
        err = 'api version mismatch: ' .. tostring(frame.v)
    elseif frame.ok == false or frame.error ~= nil then
        err = tostring(frame.error or 'request failed')
    else
        result = frame.result
    end
    self:_release_pending(id)
    entry.err = err
    entry.result = result
    entry.finished = true
end

---Fan a server event out to its subscribers.
---@param frame table
function Client:_on_event_frame(frame)
    local name = frame.event
    local list = self._listeners[name]
    if list == nil then
        return
    end
    local snapshot = {} -- listeners may unsubscribe during dispatch
    for i, fn in ipairs(list) do
        snapshot[i] = fn
    end
    for _, fn in ipairs(snapshot) do
        fn(name, frame.params)
    end
end

---Accumulate wire bytes and dispatch complete newline-delimited frames.
---@param chunk string
function Client:_on_chunk(chunk)
    if self._closed then
        return
    end
    self._buf = self._buf .. chunk
    if #self._buf > M.MAX_FRAME_BYTES and self._buf:find('\n', 1, true) == nil then
        self._buf = '' -- oversized garbage line; drop it rather than grow
        return
    end
    while true do
        local eol = self._buf:find('\n', 1, true)
        if eol == nil then
            return
        end
        local line = self._buf:sub(1, eol - 1)
        self._buf = self._buf:sub(eol + 1)
        if line ~= '' then
            local ok, frame = pcall(vim.json.decode, line)
            if ok and type(frame) == 'table' then
                self:_on_frame(frame)
            end
        end
    end
end

---Send a command and wait for its response, bounded by timeout_ms.
---@param cmd string command name, e.g. 'session.start'
---@param params table? command params (validated against the schema)
---@return any result
---@return string? err
function Client:request(cmd, params)
    assert(type(cmd) == 'string', 'cmd must be a string')
    if self._closed then
        return nil, 'client is closed'
    end
    local valid, verr = schemas.validate(cmd, params)
    if not valid then
        return nil, verr
    end
    self._seq = self._seq + 1
    local id = tostring(self._seq)
    local payload = vim.json.encode({ v = '1', id = id, cmd = cmd, params = params }) .. '\n'
    local sent, send_err = self._transport:send(payload)
    if not sent then
        return nil, send_err
    end
    ---@type PhlowPendingEntry
    local entry = { finished = false, result = nil, err = nil, timer = nil }
    self._pending[id] = entry
    table.insert(self._pending_order, id)
    self:_enforce_pending_cap()
    local timer = vim.uv and vim.uv.new_timer()
    assert(timer ~= nil, 'could not create request timer')
    entry.timer = timer
    local self_ref = self
    local timeout_ms = self._timeout_ms
    timer:start(timeout_ms, 0, function()
        self_ref:_fail_pending(id, 'request timed out after ' .. timeout_ms .. 'ms')
    end)
    local completed = vim.wait(timeout_ms + 1000, function()
        return entry.finished
    end, 50)
    if completed ~= true or not entry.finished then
        self:_fail_pending(id, 'request did not complete')
        return nil, entry.err or 'request did not complete'
    end
    if entry.err ~= nil and entry.err ~= '' then
        return nil, entry.err
    end
    return entry.result, nil
end

---Fire-and-forget: send a command, expect no response.
---@param cmd string command name
---@param params table? command params (validated against the schema)
---@return boolean? ok
---@return string? err
function Client:notify(cmd, params)
    assert(type(cmd) == 'string', 'cmd must be a string')
    if self._closed then
        return nil, 'client is closed'
    end
    local valid, verr = schemas.validate(cmd, params)
    if not valid then
        return nil, verr
    end
    local payload = vim.json.encode({ v = '1', cmd = cmd, params = params }) .. '\n'
    return self._transport:send(payload)
end

---Subscribe to a server event. The listener gets (name, params).
---@param name string event name, e.g. 'session.output'
---@param fn fun(name: string, params: any)
function Client:on_event(name, fn)
    assert(type(name) == 'string', 'name must be a string')
    assert(type(fn) == 'function', 'fn must be a function')
    local list = self._listeners[name]
    if list == nil then
        list = {}
        self._listeners[name] = list
    end
    table.insert(list, fn)
end

---Unsubscribe. With fn == nil, removes all listeners for the event.
---@param name string event name
---@param fn? fun(name: string, params: any) specific listener to remove
function Client:off_event(name, fn)
    assert(type(name) == 'string', 'name must be a string')
    local list = self._listeners[name]
    if list == nil then
        return
    end
    if fn == nil then
        self._listeners[name] = nil
        return
    end
    assert(type(fn) == 'function', 'fn must be a function')
    for i, other in ipairs(list) do
        if other == fn then
            table.remove(list, i)
            break
        end
    end
    if #list == 0 then
        self._listeners[name] = nil
    end
end

---Close the client. Idempotent: everything is released exactly once.
function Client:close()
    if self._closed then
        return
    end
    self._closed = true
    local ids = {}
    for id in pairs(self._pending) do
        ids[#ids + 1] = id
    end
    for _, id in ipairs(ids) do
        self:_fail_pending(id, 'client closed')
    end
    self._listeners = {}
    self._buf = ''
    self._transport:close()
end

return M
