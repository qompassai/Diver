-- Purpose: BiDi session module commands over a conn facade.
-- conn = { wire_state, send(method, params, cb) }. Keeps the set of
-- subscribed events so unsubscribe/teardown know what is active. All
-- commands are async via callback(err, result).

local M = {}

---@alias BidiCallback fun(err: string?, result: table?)
---@alias BidiSend fun(self: BidiConn, method: string, params: table?, cb: BidiCallback?)
---@class BidiConn
---@field wire_state table wire.new_state() table
---@field subscribed table<string, boolean> active event subscriptions
---@field send BidiSend

---@param conn BidiConn
---@param callback fun(err: string?, result: table?)
local function send(conn, method, params, callback)
    assert(conn ~= nil and type(conn.send) == 'function', 'conn.send must be a function')
    return conn:send(method, params, callback)
end

---session.status: driver/browser readiness and versions.
---@param conn BidiConn
---@param callback fun(err: string?, result: table?)
function M.status(conn, callback)
    assert(type(callback) == 'function', 'callback must be a function')
    return send(conn, 'session.status', {}, callback)
end

---Subscribe to BiDi events, optionally scoped to browsing contexts.
---Tracks the subscription set on conn.subscribed.
---@param conn BidiConn
---@param events string[] e.g. {'log.entryAdded'}
---@param contexts? string[] browsing context ids
---@param callback? fun(err: string?, result: table?)
---@return boolean? ok
---@return string? err
function M.subscribe(conn, events, contexts, callback)
    if type(events) ~= 'table' or #events == 0 then
        return nil, 'events must be a non-empty array of strings'
    end
    for i = 1, #events do
        if type(events[i]) ~= 'string' or events[i] == '' then
            return nil, 'events[' .. i .. '] must be a non-empty string'
        end
    end
    local params = { events = events }
    if contexts ~= nil then
        if type(contexts) ~= 'table' then
            return nil, 'contexts must be an array of strings'
        end
        params.contexts = contexts
    end
    local ok, serr = send(conn, 'session.subscribe', params, function(err, result)
        if err == nil then
            for i = 1, #events do
                conn.subscribed[events[i]] = true
            end
        end
        if callback ~= nil then
            callback(err, result)
        end
    end)
    if not ok then
        return nil, serr
    end
    return true, nil
end

---Unsubscribe from events; untracks them on success.
---@param conn BidiConn
---@param events string[]
---@param callback? fun(err: string?, result: table?)
---@return boolean? ok
---@return string? err
function M.unsubscribe(conn, events, callback)
    if type(events) ~= 'table' or #events == 0 then
        return nil, 'events must be a non-empty array of strings'
    end
    local ok, serr = send(conn, 'session.unsubscribe', { events = events }, function(err, result)
        if err == nil then
            for i = 1, #events do
                conn.subscribed[events[i]] = nil
            end
        end
        if callback ~= nil then
            callback(err, result)
        end
    end)
    if not ok then
        return nil, serr
    end
    return true, nil
end

---session.end: ends the BiDi session on the browser side.
---@param conn BidiConn
---@param callback? fun(err: string?, result: table?)
function M.finish(conn, callback)
    return send(conn, 'session.end', {}, callback)
end

return M
