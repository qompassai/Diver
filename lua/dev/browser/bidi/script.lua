-- Purpose: BiDi script module. Evaluates JS in a browsing context
-- (confirmation is enforced by the commands layer, not here) and converts
-- RemoteValue results to Lua. Conversion is depth-bounded and item-bounded:
-- a hostile page cannot make us recurse or allocate without limit.

local config = require('dev.browser.bidi.config')

local M = {}

---Convert an array RemoteValue's items. Leaf helper for _from_remote.
---@param items table
---@param depth integer
---@return table
local function from_array(items, depth)
    local out = {}
    local n = math.min(#items, config.remote_value_items_max)
    for i = 1, n do
        out[i] = M._from_remote(items[i], depth + 1)
    end
    return out
end

---Convert an object/map RemoteValue. The wire form is a list of [key,
---value] RemoteValue pairs; a plain map is also accepted for fixtures.
---@param v table
---@param depth integer
---@return table
local function from_object(v, depth)
    local out = {}
    if #v > 0 and type(v[1]) == 'table' and v[1][1] ~= nil then
        local n = math.min(#v, config.remote_value_items_max)
        for i = 1, n do
            local pair = v[i]
            if type(pair) == 'table' then
                local key = M._from_remote(pair[1], depth + 1)
                if type(key) == 'string' then
                    out[key] = M._from_remote(pair[2], depth + 1)
                end
            end
        end
        return out
    end
    local count = 0
    for k, item in pairs(v) do
        count = count + 1
        if count > config.remote_value_items_max then
            break
        end
        if type(k) == 'string' then
            out[k] = M._from_remote(item, depth + 1)
        end
    end
    return out
end

---Convert one RemoteValue to a Lua value. Pure and total: unknown or
---over-budget shapes become nil, never an error.
---@param rv any decoded RemoteValue-ish table
---@param depth integer current nesting depth
---@return any
function M._from_remote(rv, depth)
    if type(rv) ~= 'table' then
        return nil
    end
    if depth > config.remote_value_depth_max then
        return nil
    end
    local rtype = rv.type
    if rtype == 'undefined' or rtype == 'null' then
        return nil
    end
    if rtype == 'string' or rtype == 'number' or rtype == 'boolean' then
        return rv.value
    end
    if rtype == 'bigint' then
        -- BigInts do not fit Lua numbers; keep the exact decimal text.
        return type(rv.value) == 'string' and rv.value or nil
    end
    if rtype == 'date' then
        return rv.value -- ISO string from the browser
    end
    if rtype == 'regexp' then
        local v = rv.value
        if type(v) ~= 'table' then
            return nil
        end
        return { pattern = v.pattern, flags = v.flags }
    end
    if rtype == 'array' or rtype == 'set' then
        if type(rv.value) ~= 'table' then
            return nil
        end
        return from_array(rv.value, depth)
    end
    if rtype == 'object' or rtype == 'map' then
        if type(rv.value) ~= 'table' then
            return nil
        end
        return from_object(rv.value, depth)
    end
    if rtype == 'node' or rtype == 'window' or rtype == 'symbol' or rtype == 'function' then
        -- Handles stay opaque; never serialize the remote object itself.
        return { bidi_type = rtype, handle = rv.handle, sharedId = rv.sharedId }
    end
    return nil
end

---@param conn table BidiConn facade
---@param target table e.g. { context = 'ctx-id' }
---@param callback fun(err: string?, result: table?)
local function check_eval_args(conn, target, callback)
    if conn == nil or type(conn.send) ~= 'function' then
        return nil, 'conn.send must be a function'
    end
    if type(target) ~= 'table' then
        return nil, 'target must be a table like { context = id }'
    end
    if type(callback) ~= 'function' then
        return nil, 'callback must be a function'
    end
    return true, nil
end

---script.evaluate with awaitPromise. The result RemoteValue is converted
---to Lua before the callback fires.
---@param conn table BidiConn facade
---@param target table { context = 'ctx-id' }
---@param expression string JS source
---@param callback fun(err: string?, value: any)
function M.evaluate(conn, target, expression, callback)
    local ok, cerr = check_eval_args(conn, target, callback)
    if not ok then
        error(cerr, 2) -- programmer error: invalid facade, not user input
    end
    if type(expression) ~= 'string' or expression == '' then
        callback('expression must be a non-empty string', nil)
        return
    end
    local sok, serr = conn:send('script.evaluate', {
        expression = expression,
        target = target,
        awaitPromise = true,
    }, function(err, result)
        if err ~= nil then
            callback(err, nil)
            return
        end
        local rv = type(result) == 'table' and result.result or nil
        if rv == nil then
            callback('script.evaluate returned no result', nil)
            return
        end
        if rv.type == 'exception' then
            local detail = rv.exceptionDetails
            local text = type(detail) == 'table' and detail.text or 'unknown'
            callback('JS exception: ' .. tostring(text), nil)
            return
        end
        callback(nil, M._from_remote(rv, 0))
    end)
    if not sok then
        callback(serr, nil)
    end
end

---script.callFunction on a RemoteValue handle or declaration.
---@param conn table BidiConn facade
---@param target table { context = 'ctx-id' }
---@param function_declaration string JS function source
---@param args table[] RemoteValues
---@param callback fun(err: string?, value: any)
function M.call_function(conn, target, function_declaration, args, callback)
    local ok, cerr = check_eval_args(conn, target, callback)
    if not ok then
        error(cerr, 2)
    end
    if type(function_declaration) ~= 'string' or function_declaration == '' then
        callback('function_declaration must be a non-empty string', nil)
        return
    end
    if type(args) ~= 'table' then
        callback('args must be an array of RemoteValues', nil)
        return
    end
    local sok, serr = conn:send('script.callFunction', {
        functionDeclaration = function_declaration,
        target = target,
        arguments = args,
        awaitPromise = true,
    }, function(err, result)
        if err ~= nil then
            callback(err, nil)
            return
        end
        local rv = type(result) == 'table' and result.result or nil
        callback(nil, M._from_remote(rv, 0))
    end)
    if not sok then
        callback(serr, nil)
    end
end

return M
