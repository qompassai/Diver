-- Purpose: WebDriver BiDi framing over one WebSocket. Owns NO socket:
-- pure logic, plain-Lua testable. Tracks an id counter, a pending table
-- mapping command ids to callbacks, and a method-keyed event handler
-- table. Matches out-of-order responses to their commands, demuxes
-- success/error/event frames, and drops malformed JSON without ever
-- failing a pending command by accident. Transport injects text via
-- on_text(); the caller sends the returned command text.

local M = {}

---Command ids wrap here (BiDi ids must stay JSON-safe unsigned ints).
M.ID_MAX = 4294967295
---Hard cap on simultaneously pending commands; over it new commands fail.
M.PENDING_MAX = 1024

---@class BidiWireState
---@field seq integer last issued command id
---@field pending table<integer, fun(err: string?, result: table?)>
---@field handlers table<string, fun(params: table)>
---@field on_unknown_event? fun(method: string, params: table)
---@field counters table<string, integer>

local json_encode = nil
local json_decode = nil

---Provide the JSON codec. In Neovim call
---`wire.set_json(vim.json.encode, vim.json.decode)` once from setup().
---@param encode_fn fun(value: any): string
---@param decode_fn fun(text: string): any
function M.set_json(encode_fn, decode_fn)
    assert(type(encode_fn) == 'function', 'encode_fn must be a function')
    assert(type(decode_fn) == 'function', 'decode_fn must be a function')
    json_encode = encode_fn
    json_decode = decode_fn
end

---Fresh wire state. Tests use one per case; sessions own one each.
---@return BidiWireState
function M.new_state()
    return {
        seq = 0,
        pending = {},
        handlers = {},
        on_unknown_event = nil,
        counters = {
            malformed = 0, -- JSON that would not decode
            bad_shape = 0, -- decoded but not a valid BiDi frame
            stale = 0, -- success/error for an unknown id
            unknown_event = 0, -- event with no registered handler
        },
    }
end

---Next command id, wrapping at ID_MAX back to 1 (0 is never issued).
---@param state BidiWireState
---@return integer
function M._next_id(state)
    local id = state.seq + 1
    if id > M.ID_MAX then
        id = 1
    end
    state.seq = id
    return id
end

---Count pending commands.
---@param state BidiWireState
---@return integer
function M.pending_count(state)
    local n = 0
    for _ in pairs(state.pending) do
        n = n + 1
    end
    return n
end

---Build a command frame and register its callback. Returns the id and
---the exact text to hand to the transport, or (nil, err).
---@param state BidiWireState
---@param method string e.g. 'browsingContext.navigate'
---@param params? table
---@param callback? fun(err: string?, result: table?)
---@return integer? id
---@return string? text
---@return string? err
function M.next_command(state, method, params, callback)
    assert(type(state) == 'table', 'state must be a table')
    assert(type(method) == 'string' and method ~= '', 'method must be non-empty')
    if json_encode == nil then
        return nil, nil, 'wire.set_json was not called'
    end
    if M.pending_count(state) >= M.PENDING_MAX then
        return nil, nil, 'too many pending BiDi commands'
    end
    local id = M._next_id(state)
    if callback ~= nil then
        assert(type(callback) == 'function', 'callback must be a function')
        state.pending[id] = callback
    end
    local frame = { id = id, method = method, params = params or {} }
    local ok, text = pcall(json_encode, frame)
    if not ok then
        state.pending[id] = nil
        return nil, nil, 'command encode failed: ' .. tostring(text)
    end
    return id, text, nil
end

---Register an event handler for a BiDi event method, e.g. 'log.entryAdded'.
---@param state BidiWireState
---@param method string
---@param handler fun(params: table)
function M.on_event(state, method, handler)
    assert(type(state) == 'table', 'state must be a table')
    assert(type(method) == 'string' and method ~= '', 'method must be non-empty')
    assert(type(handler) == 'function', 'handler must be a function')
    state.handlers[method] = handler
end

---Remove an event handler.
---@param state BidiWireState
---@param method string
function M.off_event(state, method)
    assert(type(state) == 'table', 'state must be a table')
    state.handlers[method] = nil
end

---Fail every pending command with err and clear the table. Used when the
---socket drops: a dead socket invalidates the whole BiDi session, so no
---command may hang.
---@param state BidiWireState
---@param err string
function M.fail_all(state, err)
    assert(type(state) == 'table', 'state must be a table')
    assert(type(err) == 'string', 'err must be a string')
    local pending = state.pending
    state.pending = {}
    for _, callback in pairs(pending) do
        local ok, _ = pcall(callback, err, nil)
        if not ok then
            state.counters.bad_shape = state.counters.bad_shape + 1
        end
    end
end

---@param state BidiWireState
---@param frame table decoded frame
local function dispatch_response(state, frame)
    local id = frame.id
    if type(id) ~= 'number' then
        state.counters.bad_shape = state.counters.bad_shape + 1
        return
    end
    local callback = state.pending[id]
    if callback == nil then
        state.counters.stale = state.counters.stale + 1
        return
    end
    state.pending[id] = nil
    if frame.type == 'success' then
        local result = frame.result
        if type(result) ~= 'table' then
            result = {}
        end
        pcall(callback, nil, result)
    else
        local name = frame.error
        if type(name) ~= 'string' then
            name = 'unknown error'
        end
        local message = frame.message
        if type(message) == 'string' and message ~= '' then
            name = name .. ': ' .. message
        end
        pcall(callback, name, nil)
    end
end

---@param state BidiWireState
---@param frame table decoded frame
local function dispatch_event(state, frame)
    local method = frame.method
    local params = frame.params
    if type(method) ~= 'string' or type(params) ~= 'table' then
        state.counters.bad_shape = state.counters.bad_shape + 1
        return
    end
    local handler = state.handlers[method]
    if handler == nil then
        state.counters.unknown_event = state.counters.unknown_event + 1
        if state.on_unknown_event ~= nil then
            pcall(state.on_unknown_event, method, params)
        end
        return
    end
    pcall(handler, params)
end

---Handle one text message from the transport. Malformed JSON and
---misshapen frames are counted and dropped; they never touch pending.
---@param state BidiWireState
---@param text string
function M.on_text(state, text)
    assert(type(state) == 'table', 'state must be a table')
    assert(type(text) == 'string', 'text must be a string')
    if json_decode == nil then
        state.counters.malformed = state.counters.malformed + 1
        return
    end
    local ok, frame = pcall(json_decode, text)
    if not ok or type(frame) ~= 'table' then
        state.counters.malformed = state.counters.malformed + 1
        return
    end
    local ftype = frame.type
    if ftype == 'success' or ftype == 'error' then
        dispatch_response(state, frame)
    elseif ftype == 'event' then
        dispatch_event(state, frame)
    else
        state.counters.bad_shape = state.counters.bad_shape + 1
    end
end

return M
