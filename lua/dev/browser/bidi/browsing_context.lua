-- Purpose: BiDi browsingContext module. Creates tabs, navigates them,
-- captures screenshots (base64 PNG, bounded -- oversize data is rejected,
-- never kept), and reads the context tree. Keeps a small registry of
-- known context ids so teardown and commands can enumerate them.

local config = require('dev.browser.bidi.config')

local M = {}

---@type table<string, boolean> known browsing context ids
local registry = {}

---All context ids this module has seen. Order is unspecified.
---@return string[]
function M.contexts()
    local out = {}
    for id in pairs(registry) do
        out[#out + 1] = id
    end
    return out
end

---Forget every known context (session teardown).
function M.reset()
    registry = {}
end

---@param conn table BidiConn facade
---@param context string
---@return boolean? ok
---@return string? err
local function check_context(conn, context)
    if conn == nil or type(conn.send) ~= 'function' then
        return nil, 'conn.send must be a function'
    end
    if type(context) ~= 'string' or context == '' then
        return nil, 'context must be a non-empty string'
    end
    return true, nil
end

---browsingContext.create. Registers the new id.
---@param conn table BidiConn facade
---@param context_type? string 'tab' (default) or 'window'
---@param callback fun(err: string?, context_id: string?)
function M.create(conn, context_type, callback)
    assert(type(callback) == 'function', 'callback must be a function')
    context_type = context_type or 'tab'
    if context_type ~= 'tab' and context_type ~= 'window' then
        callback("context_type must be 'tab' or 'window'", nil)
        return
    end
    local create_params = { type = context_type }
    local ok, serr = conn:send('browsingContext.create', create_params, function(err, result)
        if err ~= nil then
            callback(err, nil)
            return
        end
        local id = type(result) == 'table' and result.context or nil
        if type(id) ~= 'string' or id == '' then
            callback('browsingContext.create returned no context id', nil)
            return
        end
        registry[id] = true
        callback(nil, id)
    end)
    if not ok then
        callback(serr, nil)
    end
end

---browsingContext.navigate with wait:'complete'.
---@param conn table BidiConn facade
---@param context string
---@param url string
---@param callback fun(err: string?, navigation: table?)
function M.navigate(conn, context, url, callback)
    assert(type(callback) == 'function', 'callback must be a function')
    local ok, cerr = check_context(conn, context)
    if not ok then
        callback(cerr, nil)
        return
    end
    if type(url) ~= 'string' or url == '' then
        callback('url must be a non-empty string', nil)
        return
    end
    local sok, serr = conn:send('browsingContext.navigate', {
        context = context,
        url = url,
        wait = 'complete',
    }, function(err, result)
        callback(err, err == nil and result or nil)
    end)
    if not sok then
        callback(serr, nil)
    end
end

---Pure size gate for decoded screenshot bytes. The 50MB adversarial case
---must be rejected here, before anything is kept or displayed.
---@param byte_len integer
---@return boolean? ok
---@return string? err
function M._check_image_bytes(byte_len)
    if type(byte_len) ~= 'number' then
        return nil, 'byte_len must be a number'
    end
    if byte_len > config.screenshot_bytes_max then
        return nil,
            'screenshot rejected: ' .. byte_len .. ' bytes exceeds '
                .. config.screenshot_bytes_max .. ' byte bound'
    end
    return true, nil
end

---browsingContext.captureScreenshot. Decodes base64 PNG, enforces the
---size bound, then calls back with raw PNG bytes (never written to disk
---or uploaded by this module).
---@param conn table BidiConn facade
---@param context string
---@param callback fun(err: string?, png_bytes: string?)
function M.capture_screenshot(conn, context, callback)
    assert(type(callback) == 'function', 'callback must be a function')
    local ok, cerr = check_context(conn, context)
    if not ok then
        callback(cerr, nil)
        return
    end
    local shot_params = { context = context }
    local function on_shot(err, result)
        if err ~= nil then
            callback(err, nil)
            return
        end
        local data = type(result) == 'table' and result.data or nil
        if type(data) ~= 'string' or data == '' then
            callback('captureScreenshot returned no data', nil)
            return
        end
        local dok, png = pcall(vim.base64.decode, data)
        if not dok or type(png) ~= 'string' then
            callback('captureScreenshot data is not valid base64', nil)
            return
        end
        local bok, berr = M._check_image_bytes(#png)
        if not bok then
            callback(berr, nil)
            return
        end
        callback(nil, png)
    end
    local sok, serr = conn:send('browsingContext.captureScreenshot', shot_params, on_shot)
    if not sok then
        callback(serr, nil)
    end
end

---browsingContext.getTree. Returns the raw tree; callers bound depth.
---@param conn table BidiConn facade
---@param context string
---@param callback fun(err: string?, tree: table?)
function M.get_tree(conn, context, callback)
    assert(type(callback) == 'function', 'callback must be a function')
    local ok, cerr = check_context(conn, context)
    if not ok then
        callback(cerr, nil)
        return
    end
    local tree_params = { root = { context = context } }
    local sok, serr = conn:send('browsingContext.getTree', tree_params, function(err, result)
        callback(err, err == nil and result or nil)
    end)
    if not sok then
        callback(serr, nil)
    end
end

return M
