-- lua/dev/browser/cdp/domains.lua
-- Thin typed wrappers over raw CDP commands. Each wrapper validates its
-- inputs, sends one command on the given session, and passes the raw
-- result (or error) to the callback. No UI, no policy here.
-- Plain words: small named functions like page.navigate so callers never
-- hand-write the JSON-RPC-ish command tables.
-- Copyright (C) 2026 Qompass AI. All rights reserved.
-- SPDX-License-Identifier: Apache-2.0
---@module 'dev.browser.cdp.domains'

local M = {
    target = {},
    page = {},
    runtime = {},
    log = {},
    network = {},
    debugger = {},
    browser = {},
}

local target = M.target
local page = M.page
local runtime = M.runtime
local log = M.log
local network = M.network
local debugger = M.debugger
local browser = M.browser

local EVALUATE_EXPRESSION_MAX = 65536 -- 64 KiB cap on evaluated JS text
local RESPONSE_BODY_MAX = 1048576 -- 1 MiB cap on fetched text bodies
local SCREENSHOT_QUALITY_MIN = 0
local SCREENSHOT_QUALITY_MAX = 100

---@alias CdpCallback fun(result: table|nil, err: string|nil)

---@param session table CDP session with :send() and :is_closed()
---@return boolean|nil ok
---@return string|nil err
local function check_session(session)
    if type(session) ~= 'table' or type(session.send) ~= 'function' then
        return nil, 'invalid CDP session'
    end
    if type(session.is_closed) == 'function' and session:is_closed() then
        return nil, 'session is closed'
    end
    return true
end

---@param session table
---@return boolean|nil ok
---@return string|nil err
local function need_target_session(session)
    local ok, err = check_session(session)
    if not ok then
        return nil, err
    end
    if session.session_id == nil then
        return nil, 'needs an attached target session, not the browser session'
    end
    return true
end

---@param value string|nil
---@param what string
---@return boolean|nil ok
---@return string|nil err
local function need_nonempty_string(value, what)
    if type(value) ~= 'string' or value == '' then
        return nil, what .. ' must be a non-empty string'
    end
    return true
end

-- Target (browser-level session) --------------------------------------

---List all targets known to the browser.
---@param session table browser-level session
---@param callback CdpCallback receives { targetInfos = {...} }
---@return integer|nil id
---@return string|nil err
function target.get_targets(session, callback)
    local ok, err = check_session(session)
    if not ok then
        return nil, err
    end
    return session:send('Target.getTargets', nil, callback)
end

---Attach to a target in flat mode; result carries the sessionId.
---@param session table browser-level session
---@param target_id string
---@param callback CdpCallback receives { sessionId = "..." }
---@return integer|nil id
---@return string|nil err
function target.attach_to_target(session, target_id, callback)
    local ok, err = check_session(session)
    if not ok then
        return nil, err
    end
    local vok, verr = need_nonempty_string(target_id, 'target_id')
    if not vok then
        return nil, verr
    end
    return session:send('Target.attachToTarget', { targetId = target_id, flatten = true }, callback)
end

---Open a new target (tab) at the given URL.
---@param session table browser-level session
---@param url string
---@param callback CdpCallback receives { targetId = "..." }
---@return integer|nil id
---@return string|nil err
function target.create_target(session, url, callback)
    local ok, err = check_session(session)
    if not ok then
        return nil, err
    end
    local vok, verr = need_nonempty_string(url, 'url')
    if not vok then
        return nil, verr
    end
    return session:send('Target.createTarget', { url = url }, callback)
end

---Close a target.
---@param session table browser-level session
---@param target_id string
---@param callback? CdpCallback
---@return integer|nil id
---@return string|nil err
function target.close_target(session, target_id, callback)
    local ok, err = check_session(session)
    if not ok then
        return nil, err
    end
    local vok, verr = need_nonempty_string(target_id, 'target_id')
    if not vok then
        return nil, verr
    end
    return session:send('Target.closeTarget', { targetId = target_id }, callback)
end

-- Page (attached target session) ----------------------------------------

---Enable Page domain events.
---@param session table attached target session
---@param callback? CdpCallback
---@return integer|nil id
---@return string|nil err
function page.enable(session, callback)
    local ok, err = need_target_session(session)
    if not ok then
        return nil, err
    end
    return session:send('Page.enable', nil, callback)
end

---Navigate the page; result carries frameId/loaderId and maybe errorText.
---@param session table attached target session
---@param url string
---@param callback CdpCallback
---@return integer|nil id
---@return string|nil err
function page.navigate(session, url, callback)
    local ok, err = need_target_session(session)
    if not ok then
        return nil, err
    end
    local vok, verr = need_nonempty_string(url, 'url')
    if not vok then
        return nil, verr
    end
    return session:send('Page.navigate', { url = url }, callback)
end

---Reload the page.
---@param session table attached target session
---@param callback? CdpCallback
---@return integer|nil id
---@return string|nil err
function page.reload(session, callback)
    local ok, err = need_target_session(session)
    if not ok then
        return nil, err
    end
    return session:send('Page.reload', nil, callback)
end

---@class CdpScreenshotOpts
---@field format 'png'|'jpeg'
---@field quality? integer 0-100, jpeg only
---@field clip? table { x: number, y: number, width: number, height: number, scale?: number }

---Capture a screenshot; result carries base64 { data }.
---@param session table attached target session
---@param opts CdpScreenshotOpts
---@param callback CdpCallback
---@return integer|nil id
---@return string|nil err
function page.capture_screenshot(session, opts, callback)
    local ok, err = need_target_session(session)
    if not ok then
        return nil, err
    end
    if type(opts) ~= 'table' then
        return nil, 'opts must be a table'
    end
    local format = opts.format or 'png'
    if format ~= 'png' and format ~= 'jpeg' then
        return nil, 'format must be "png" or "jpeg"'
    end
    local params = { format = format }
    if opts.quality ~= nil then
        if format ~= 'jpeg' then
            return nil, 'quality only applies to jpeg'
        end
        local q = opts.quality
        local q_ok = type(q) == 'number'
            and q >= SCREENSHOT_QUALITY_MIN
            and q <= SCREENSHOT_QUALITY_MAX
        if not q_ok then
            return nil, 'quality must be 0..100'
        end
        params.quality = math.floor(opts.quality)
    end
    if opts.clip ~= nil then
        if type(opts.clip) ~= 'table' then
            return nil, 'clip must be a table'
        end
        params.clip = opts.clip
    end
    return session:send('Page.captureScreenshot', params, callback)
end

-- Runtime (attached target session) -------------------------------------

---Enable Runtime domain events (consoleAPICalled, exceptionThrown).
---@param session table attached target session
---@param callback? CdpCallback
---@return integer|nil id
---@return string|nil err
function runtime.enable(session, callback)
    local ok, err = need_target_session(session)
    if not ok then
        return nil, err
    end
    return session:send('Runtime.enable', nil, callback)
end

---Evaluate JS with returnByValue and awaitPromise forced on, so results
---come back as plain values without objectId round-trips.
---@param session table attached target session
---@param expression string JavaScript source
---@param callback CdpCallback receives { result = { type=..., value=... } }
---@return integer|nil id
---@return string|nil err
function runtime.evaluate(session, expression, callback)
    local ok, err = need_target_session(session)
    if not ok then
        return nil, err
    end
    local vok, verr = need_nonempty_string(expression, 'expression')
    if not vok then
        return nil, verr
    end
    if #expression > EVALUATE_EXPRESSION_MAX then
        return nil, 'expression exceeds ' .. EVALUATE_EXPRESSION_MAX .. ' bytes'
    end
    return session:send('Runtime.evaluate', {
        expression = expression,
        returnByValue = true,
        awaitPromise = true,
    }, callback)
end

-- Log (attached target session) -----------------------------------------

---Enable Log domain events (entryAdded).
---@param session table attached target session
---@param callback? CdpCallback
---@return integer|nil id
---@return string|nil err
function log.enable(session, callback)
    local ok, err = need_target_session(session)
    if not ok then
        return nil, err
    end
    return session:send('Log.enable', nil, callback)
end

-- Network (attached target session) --------------------------------------

---Enable Network domain events.
---@param session table attached target session
---@param callback? CdpCallback
---@return integer|nil id
---@return string|nil err
function network.enable(session, callback)
    local ok, err = need_target_session(session)
    if not ok then
        return nil, err
    end
    return session:send('Network.enable', nil, callback)
end

local TEXT_MIME_EXACT = {
    ['application/json'] = true,
    ['application/javascript'] = true,
    ['application/xml'] = true,
    ['application/x-www-form-urlencoded'] = true,
}

---True for text/*, application/json, application/javascript, and +json/+xml.
---@param mime string|nil
---@return boolean
function network.is_text_mime(mime)
    if type(mime) ~= 'string' then
        return false
    end
    local base = mime:match('^%s*([^;%s]+)') or ''
    base = base:lower()
    if base:sub(1, 5) == 'text/' then
        return true
    end
    if TEXT_MIME_EXACT[base] then
        return true
    end
    return base:match('%+json$') ~= nil or base:match('%+xml$') ~= nil
end

---Fetch a response body. Refuses non-text MIME and bodies over
---RESPONSE_BODY_MAX (bounded exfiltration). The caller supplies the
---MIME seen on Network.responseReceived.
---@param session table attached target session
---@param request_id string
---@param mime_type string MIME from the response event
---@param callback CdpCallback receives { body = "...", base64Encoded = bool }
---@return integer|nil id
---@return string|nil err
function network.get_response_body(session, request_id, mime_type, callback)
    local ok, err = need_target_session(session)
    if not ok then
        return nil, err
    end
    local rok, rerr = need_nonempty_string(request_id, 'request_id')
    if not rok then
        return nil, rerr
    end
    if not network.is_text_mime(mime_type) then
        return nil, 'refusing non-text MIME: ' .. tostring(mime_type)
    end
    local function bounded(result, berr)
        if berr ~= nil then
            callback(nil, berr)
            return
        end
        local body = type(result) == 'table' and result.body or nil
        if type(body) == 'string' and #body > RESPONSE_BODY_MAX then
            local limit = tostring(RESPONSE_BODY_MAX)
            callback(nil, 'response body exceeds ' .. limit .. ' bytes')
            return
        end
        callback(result, nil)
    end
    return session:send('Network.getResponseBody', { requestId = request_id }, bounded)
end

-- Debugger (attached target session; awareness only) ----------------------

---Enable Debugger domain events (paused, resumed). No stepping UI lives
---here; diver already has DAP for that.
---@param session table attached target session
---@param callback? CdpCallback
---@return integer|nil id
---@return string|nil err
function debugger.enable(session, callback)
    local ok, err = need_target_session(session)
    if not ok then
        return nil, err
    end
    return session:send('Debugger.enable', nil, callback)
end

---Set a breakpoint by URL regex. lineNumber 0 = first line match.
---@param session table attached target session
---@param url_regex string
---@param callback CdpCallback receives { breakpointId = "...", locations = {...} }
---@return integer|nil id
---@return string|nil err
function debugger.set_breakpoint_by_url(session, url_regex, callback)
    local ok, err = need_target_session(session)
    if not ok then
        return nil, err
    end
    local vok, verr = need_nonempty_string(url_regex, 'url_regex')
    if not vok then
        return nil, verr
    end
    return session:send(
        'Debugger.setBreakpointByUrl',
        { lineNumber = 0, urlRegex = url_regex },
        callback
    )
end

---Resume a paused debugger.
---@param session table attached target session
---@param callback? CdpCallback
---@return integer|nil id
---@return string|nil err
function debugger.resume(session, callback)
    local ok, err = need_target_session(session)
    if not ok then
        return nil, err
    end
    return session:send('Debugger.resume', nil, callback)
end

-- Browser (browser-level session) ------------------------------------------

---Fetch browser version info. Used at connect to confirm a real CDP
---endpoint: a non-JSON body or 404 already failed discovery before this.
---@param session table browser-level session
---@param callback CdpCallback receives { protocolVersion, product, ... }
---@return integer|nil id
---@return string|nil err
function browser.get_version(session, callback)
    local ok, err = check_session(session)
    if not ok then
        return nil, err
    end
    return session:send('Browser.getVersion', nil, callback)
end

return M
