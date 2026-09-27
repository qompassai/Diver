-- Purpose: BiDi network observation for the MVP. Installs an
-- observe-only intercept (no blocking, no response mocking -- that is
-- phase 2) and normalizes network events into small stable Lua tables for
-- the :BidiNetwork log sink. _normalize is pure and unit-tested.

local M = {}

local OBSERVE_PHASES = { 'beforeRequestSent', 'responseStarted', 'responseCompleted' }

---Normalize one network event into a stable shape. Pure.
---Returns (nil, err) for unknown methods or misshapen params.
---@param method string e.g. 'network.beforeRequestSent'
---@param params table
---@return table? event {kind, id, method, url, status?, ts}
---@return string? err
function M._normalize(method, params)
    if type(params) ~= 'table' then
        return nil, 'network event params must be a table'
    end
    local request = params.request or {}
    local response = params.response or {}
    local url = request.url or response.url
    if method == 'network.beforeRequestSent' then
        return {
            kind = 'request',
            id = params.requestId,
            method = request.method,
            url = url,
            ts = params.timestamp,
        }, nil
    end
    if method == 'network.responseStarted' then
        return {
            kind = 'response-start',
            id = params.requestId,
            method = request.method,
            url = url,
            ts = params.timestamp,
        }, nil
    end
    if method == 'network.responseCompleted' then
        return {
            kind = 'response-done',
            id = params.requestId,
            method = request.method,
            url = url,
            status = response.status,
            ts = params.timestamp,
        }, nil
    end
    return nil, 'unknown network event method: ' .. tostring(method)
end

---Install the observe-only intercept and subscribe to the three phases.
---@param conn table BidiConn facade
---@param contexts? string[] scope to these browsing contexts
---@param callback fun(err: string?)
function M.observe(conn, contexts, callback)
    assert(type(callback) == 'function', 'callback must be a function')
    if conn == nil or type(conn.send) ~= 'function' then
        callback('conn.send must be a function', nil)
        return
    end
    local intercept_params = { phases = OBSERVE_PHASES }
    if contexts ~= nil then
        intercept_params.contexts = contexts
    end
    local function on_intercept(err)
        if err ~= nil then
            callback('network.addIntercept failed: ' .. err)
            return
        end
        local sub_params = { events = OBSERVE_PHASES }
        local sok, sserr = conn:send('session.subscribe', sub_params, function(serr2)
            if serr2 ~= nil then
                callback('network subscribe failed: ' .. serr2)
                return
            end
            callback(nil)
        end)
        if not sok then
            callback(sserr)
        end
    end
    local ok, serr = conn:send('network.addIntercept', intercept_params, on_intercept)
    if not ok then
        callback(serr)
    end
end

return M
