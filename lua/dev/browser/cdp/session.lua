-- lua/dev/browser/cdp/session.lua
-- CDP session: per-session id allocation, pending-request matching with
-- timeouts, and event dispatch keyed by "Domain.event".
-- Plain words: one session is one conversation on the wire. It numbers
-- outgoing commands (starting at 1, independently per session), remembers
-- which callback each answer belongs to, fails requests that take too
-- long, and routes incoming events to registered handlers.
-- Copyright (C) 2026 Qompass AI. All rights reserved.
-- SPDX-License-Identifier: Apache-2.0
---@module 'dev.browser.cdp.session'

local M = {}

local ID_FIRST = 1
local PENDING_MAX = 256 -- cap on in-flight requests per session
local HANDLERS_PER_EVENT_MAX = 32 -- cap on handlers for one "Domain.event"
local TIMEOUT_MS_DEFAULT = 30000
local TIMEOUT_MS_MIN = 1000
local TIMEOUT_MS_MAX = 120000
local METHOD_PATTERN = '^[A-Za-z][A-Za-z0-9]*%.[A-Za-z][A-Za-z0-9]*$'

---@class CdpPendingRequest
---@field method string CDP method, e.g. "Page.navigate"
---@field callback fun(result: table|nil, err: string|nil)
---@field deadline_ms integer absolute expiry on the session clock

---@class CdpSessionOpts
---@field session_id? string CDP sessionId; nil means browser-level session
---@field transport? { send: fun(text: string): boolean?, string? }
---@field json_encode? fun(value: table): string
---@field json_decode? fun(text: string): table
---@field timeout_ms? integer per-request timeout, default 30000
---@field clock? fun(): integer current time in milliseconds
---@field on_error? fun(err: string) protocol-level problems (not request errors)

---@class CdpSession
---@field session_id string|nil
---@field closed boolean
local CdpSession = {}
CdpSession.__index = CdpSession
M.CdpSession = CdpSession

---Default JSON decode through the host vim.
---@param text string
---@return table
local function default_decode(text)
    return rawget(_G, 'vim').json.decode(text)
end

---Default JSON encode through the host vim.
---@param value table
---@return string
local function default_encode(value)
    return rawget(_G, 'vim').json.encode(value)
end

---Default millisecond clock: vim.uv.now() when available, os.clock fallback.
---@return integer
local function default_clock()
    local v = rawget(_G, 'vim')
    if v ~= nil and v.uv ~= nil and v.uv.now ~= nil then
        return v.uv.now()
    end
    return math.floor(os.clock() * 1000)
end

---Report a protocol-level problem without raising.
---@param self CdpSession
---@param err string
local function report(self, err)
    if self.on_error ~= nil then
        pcall(self.on_error, err)
    end
end

---Create a session. Does not send anything; attach a transport to go live.
---@param opts CdpSessionOpts
---@return CdpSession
function M.new(opts)
    assert(type(opts) == 'table', 'opts must be a table')
    assert(
        opts.session_id == nil or type(opts.session_id) == 'string',
        'session_id must be a string'
    )
    assert(opts.transport == nil or type(opts.transport) == 'table', 'transport must be a table')
    assert(
        opts.json_encode == nil or type(opts.json_encode) == 'function',
        'json_encode must be a function'
    )
    assert(
        opts.json_decode == nil or type(opts.json_decode) == 'function',
        'json_decode must be a function'
    )
    assert(
        opts.timeout_ms == nil or type(opts.timeout_ms) == 'number',
        'timeout_ms must be a number'
    )
    assert(opts.clock == nil or type(opts.clock) == 'function', 'clock must be a function')
    assert(opts.on_error == nil or type(opts.on_error) == 'function', 'on_error must be a function')
    local timeout_ms = opts.timeout_ms or TIMEOUT_MS_DEFAULT
    assert(timeout_ms >= TIMEOUT_MS_MIN and timeout_ms <= TIMEOUT_MS_MAX, 'timeout_ms out of range')
    return setmetatable({
        session_id = opts.session_id,
        transport = opts.transport,
        json_encode = opts.json_encode or default_encode,
        json_decode = opts.json_decode or default_decode,
        timeout_ms = timeout_ms,
        clock = opts.clock or default_clock,
        on_error = opts.on_error,
        next_id_value = ID_FIRST,
        pending = {},
        pending_count_value = 0,
        handlers = {},
        closed = false,
    }, CdpSession)
end

---Attach or replace the transport after construction.
---@param transport { send: fun(text: string): boolean?, string? }
function CdpSession:set_transport(transport)
    assert(type(transport) == 'table', 'transport must be a table')
    assert(type(transport.send) == 'function', 'transport.send must be a function')
    self.transport = transport
end

---True after close(); the session rejects new work.
---@return boolean
function CdpSession:is_closed()
    return self.closed
end

---Allocate the next command id. Ids restart at 1 per session.
---@return integer
function CdpSession:next_id()
    local id = self.next_id_value
    self.next_id_value = id + 1
    return id
end

---How many requests are waiting for a response.
---@return integer
function CdpSession:pending_count()
    return self.pending_count_value
end

---@param method string
---@return boolean
local function valid_method(method)
    return type(method) == 'string' and method:match(METHOD_PATTERN) ~= nil
end

---Send a CDP command. The callback fires once with (result, nil) or
---(nil, err). Returns the allocated id, or nil plus an error.
---@param method string e.g. "Page.navigate"
---@param params? table command parameters
---@param callback? fun(result: table|nil, err: string|nil)
---@return integer|nil id
---@return string|nil err
function CdpSession:send(method, params, callback)
    if self.closed then
        return nil, 'session is closed'
    end
    if not valid_method(method) then
        return nil, 'method must look like "Domain.command", got: ' .. tostring(method)
    end
    if params ~= nil and type(params) ~= 'table' then
        return nil, 'params must be a table'
    end
    if callback ~= nil and type(callback) ~= 'function' then
        return nil, 'callback must be a function'
    end
    if self.pending_count_value >= PENDING_MAX then
        return nil, 'pending request limit reached (' .. PENDING_MAX .. ')'
    end
    if self.transport == nil then
        return nil, 'no transport attached'
    end
    local id = self:next_id()
    local command = { id = id, method = method }
    if params ~= nil then
        command.params = params
    end
    if self.session_id ~= nil then
        command.sessionId = self.session_id
    end
    local encode_ok, text = pcall(self.json_encode, command)
    if not encode_ok then
        return nil, 'encode failed: ' .. tostring(text)
    end
    self.pending[id] = {
        method = method,
        callback = callback or function() end,
        deadline_ms = self.clock() + self.timeout_ms,
    }
    self.pending_count_value = self.pending_count_value + 1
    local call_ok, sent_ok, send_err = pcall(self.transport.send, text)
    -- A raised error lands in sent_ok; a (nil, err) return lands in send_err.
    -- The transport contract is `true` on success, so anything else fails.
    local send_err_text = nil
    if not call_ok then
        send_err_text = 'transport send raised: ' .. tostring(sent_ok)
    elseif sent_ok ~= true then
        send_err_text = 'transport send failed: ' .. tostring(send_err)
    end
    if send_err_text ~= nil then
        self.pending[id] = nil
        self.pending_count_value = self.pending_count_value - 1
        return nil, send_err_text
    end
    return id
end

---Deliver one decoded incoming frame to this session. Responses are
---matched to pending requests by id; frames with a method are dispatched
---to event handlers. Returns true when the frame was consumed.
---@param msg table decoded JSON frame
---@return boolean handled
function CdpSession:handle_message(msg)
    if type(msg) ~= 'table' then
        report(self, 'ignoring non-table frame')
        return false
    end
    if msg.id ~= nil then
        return self:_handle_response(msg)
    end
    if msg.method ~= nil then
        return self:_handle_event(msg)
    end
    report(self, 'ignoring frame with neither id nor method')
    return false
end

---Match a response frame to its pending request.
---@param msg table
---@return boolean handled
function CdpSession:_handle_response(msg)
    if type(msg.id) ~= 'number' or msg.id ~= math.floor(msg.id) then
        report(self, 'ignoring response with non-integer id')
        return false
    end
    local pending = self.pending[msg.id]
    if pending == nil then
        report(self, 'ignoring response for unknown id ' .. tostring(msg.id))
        return false
    end
    self.pending[msg.id] = nil
    self.pending_count_value = self.pending_count_value - 1
    local callback = pending.callback
    if msg.error ~= nil then
        local detail = msg.error
        local text = 'cdp error'
        if type(detail) == 'table' then
            text = text .. ' ' .. tostring(detail.code) .. ': ' .. tostring(detail.message)
        else
            text = text .. ': ' .. tostring(detail)
        end
        pcall(callback, nil, text)
        return true
    end
    if msg.result ~= nil and type(msg.result) ~= 'table' then
        pcall(callback, nil, 'cdp response result is not a table')
        return true
    end
    pcall(callback, msg.result, nil)
    return true
end

---Dispatch an event frame to registered handlers.
---@param msg table
---@return boolean handled
function CdpSession:_handle_event(msg)
    if type(msg.method) ~= 'string' or msg.method:match(METHOD_PATTERN) == nil then
        report(self, 'ignoring event with bad method')
        return false
    end
    local list = self.handlers[msg.method]
    if list == nil or #list == 0 then
        return false -- unsubscribed CDP chatter is normal; ignore quietly
    end
    local params = msg.params
    if params == nil then
        params = {}
    elseif type(params) ~= 'table' then
        report(self, 'ignoring event with non-table params: ' .. msg.method)
        return false
    end
    for i = 1, #list do
        local ok, err = pcall(list[i], params)
        if not ok then
            report(self, 'event handler failed for ' .. msg.method .. ': ' .. tostring(err))
        end
    end
    return true
end

---Register a handler for a "Domain.event". Returns an unsubscribe
---function, or nil plus an error when the per-event cap is hit.
---@param event_name string e.g. "Runtime.consoleAPICalled"
---@param handler fun(params: table)
---@return fun()|nil unsubscribe
---@return string|nil err
function CdpSession:on(event_name, handler)
    if self.closed then
        return nil, 'session is closed'
    end
    if type(event_name) ~= 'string' or event_name:match(METHOD_PATTERN) == nil then
        return nil, 'event name must look like "Domain.event"'
    end
    if type(handler) ~= 'function' then
        return nil, 'handler must be a function'
    end
    local list = self.handlers[event_name]
    if list == nil then
        list = {}
        self.handlers[event_name] = list
    end
    if #list >= HANDLERS_PER_EVENT_MAX then
        return nil, 'too many handlers for ' .. event_name .. ' (' .. HANDLERS_PER_EVENT_MAX .. ')'
    end
    list[#list + 1] = handler
    local removed = false
    local session_ref = self
    return function()
        if removed then
            return
        end
        removed = true
        local current = session_ref.handlers[event_name]
        if current == nil then
            return
        end
        for i = 1, #current do
            if current[i] == handler then
                table.remove(current, i)
                return
            end
        end
    end
end

---Fail requests whose deadline passed. Returns the expired count.
---@param now_ms integer current time in milliseconds
---@return integer expired_count
function CdpSession:check_timeouts(now_ms)
    assert(type(now_ms) == 'number', 'now_ms must be a number')
    local expired = {}
    for id, pending in pairs(self.pending) do
        if now_ms >= pending.deadline_ms then
            expired[#expired + 1] = id
        end
    end
    -- Sort so expiry order is deterministic in tests and logs.
    table.sort(expired)
    for i = 1, #expired do
        local id = expired[i]
        local pending = self.pending[id]
        if pending ~= nil then
            self.pending[id] = nil
            self.pending_count_value = self.pending_count_value - 1
            pcall(pending.callback, nil, 'request timed out: ' .. pending.method)
        end
    end
    return #expired
end

---Idempotent teardown: fail all pending requests, drop handlers.
function CdpSession:close()
    if self.closed then
        return
    end
    self.closed = true
    for id, pending in pairs(self.pending) do
        self.pending[id] = nil
        pcall(pending.callback, nil, 'session closed')
    end
    self.pending_count_value = 0
    self.handlers = {}
    self.transport = nil
end

return M
