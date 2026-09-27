-- Purpose: public BiDi session API. Owns the session lifecycle: open
-- (verify driver -> spawn -> /status -> POST /session -> WebSocket ->
-- session.status -> create tab), the conn facade handed to the protocol
-- modules, and exactly-once teardown (browser.close, socket close, driver
-- reap, ephemeral profile removal, VimLeavePre guarantee). Reconnect is
-- never attempted: a dropped socket invalidates the session.

local wire = require('dev.browser.bidi.wire')
local transport_mod = require('dev.browser.bidi.transport')
local driver = require('dev.browser.bidi.driver')
local bsession = require('dev.browser.bidi.session')
local bctx = require('dev.browser.bidi.browsing_context')
local bscript = require('dev.browser.bidi.script')
local bnetwork = require('dev.browser.bidi.network')
local blog = require('dev.browser.bidi.log')
local config = require('dev.browser.bidi.config')

local M = {}

---Run fn now, or deferred via vim.schedule when inside a fast event
---context (transport/socket callbacks run on the uv read thread).
---nvim_* API calls raise E5560 in fast context; deferring keeps them
---legal. Outside fast context (commands, tests) this runs synchronously.
---@param fn fun()
local function defer(fn)
    local v = rawget(_G, 'vim')
    if v ~= nil and v.in_fast_event ~= nil and v.in_fast_event() then
        v.schedule(fn)
    else
        fn()
    end
end

---@class BidiSessionState
---@field kind string 'chrome' | 'firefox'
---@field profile_dir string ephemeral user-data dir
---@field proc table? driver proc from driver.spawn
---@field session_id string?
---@field wire_state table
---@field transport table? BidiTransport
---@field context_id string?
---@field torn_down boolean
---@field last_screenshot string? base64 PNG of the last capture

---Fresh session state. Exposed for unit tests of teardown.
---@return BidiSessionState
function M._new_state()
    return {
        kind = '',
        profile_dir = '',
        proc = nil,
        session_id = nil,
        wire_state = wire.new_state(),
        transport = nil,
        context_id = nil,
        torn_down = false,
        last_screenshot = nil,
    }
end

---@type BidiSessionState? the live session, if any
local current = nil

---Idempotent module setup: JSON codec for the wire, one VimLeavePre
---autocmd guaranteeing teardown.
function M.setup()
    if M._setup_done then
        return
    end
    M._setup_done = true
    wire.set_json(vim.json.encode, vim.json.decode, vim.empty_dict)
    vim.api.nvim_create_autocmd('VimLeavePre', {
        desc = 'BiDi: tear down browser session exactly once',
        callback = function()
            M.close()
        end,
    })
end

---Build the conn facade the protocol modules program against.
---@param state BidiSessionState
---@return table conn
function M._make_conn(state)
    local conn = {
        _state = state,
        wire_state = state.wire_state,
        subscribed = {},
    }
    function conn:send(method, params, callback)
        local st = self._state
        if st.torn_down then
            return nil, 'bidi session is closed'
        end
        if st.transport == nil then
            return nil, 'bidi transport is not connected'
        end
        local id, text, err = wire.next_command(st.wire_state, method, params, callback)
        if id == nil then
            return nil, err
        end
        if #text > config.command_bytes_max then
            st.wire_state.pending[id] = nil
            return nil, 'command exceeds command_bytes_max'
        end
        return st.transport:send_text(text)
    end
    return conn
end

---Exactly-once teardown over injected deps. Each step is best-effort;
---a failing step never blocks the rest. Returns true on the first call,
---false when already torn down.
---@param state BidiSessionState
---@param deps table {session_finish?, close_transport?, kill_driver?, remove_profile?}
---@return boolean first_call
function M._teardown_state(state, deps)
    assert(type(state) == 'table', 'state must be a table')
    assert(type(deps) == 'table', 'deps must be a table')
    if state.torn_down then
        return false
    end
    state.torn_down = true
    wire.fail_all(state.wire_state, 'bidi session closed')
    if deps.session_finish ~= nil then
        pcall(deps.session_finish)
    end
    if deps.close_transport ~= nil then
        pcall(deps.close_transport)
    end
    if deps.kill_driver ~= nil then
        pcall(deps.kill_driver)
    end
    if deps.remove_profile ~= nil then
        pcall(deps.remove_profile)
    end
    return true
end

---Real teardown deps for a live state.
---@param state BidiSessionState
---@return table
local function real_deps(state)
    return {
        session_finish = function()
            if state.transport ~= nil and state.transport:is_active() then
                local _, text = wire.next_command(state.wire_state, 'browser.close', {}, nil)
                if text ~= nil then
                    state.transport:send_text(text)
                end
            end
        end,
        close_transport = function()
            if state.transport ~= nil then
                state.transport:close()
            end
        end,
        kill_driver = function()
            driver.kill(state.proc)
        end,
        remove_profile = function()
            if state.profile_dir ~= '' then
                vim.fn.delete(state.profile_dir, 'rf')
            end
        end,
    }
end

---Close the current session: browser.close, socket teardown, driver
---reaped, ephemeral profile removed. Idempotent.
---@param callback? fun()
function M.close(callback)
    local state = current
    current = nil
    if state == nil then
        if callback ~= nil then
            callback()
        end
        return
    end
    bctx.reset()
    M._teardown_state(state, real_deps(state))
    if callback ~= nil then
        callback()
    end
end

---True when a live, non-torn-down session exists.
---@return boolean
function M.is_open()
    return current ~= nil and not current.torn_down
end

---Second half of M.open: spawn driver, wait, New Session, connect the
---BiDi socket, session.status, create a tab. aborts tear down and report.
---@param state BidiSessionState
---@param abort fun(err: string)
---@param callback fun(err: string?, info: table?)
local function continue_open(state, abort, callback)
    local kind = state.kind
    -- The open callback fires exactly once. Sequential failures fail it
    -- directly; a transport error mid-handshake also fails it instead of
    -- leaving the caller hanging until its own timeout.
    local done = false
    local function fail_open(err)
        if done then
            return
        end
        done = true
        abort(err)
    end
    local proc, serr = driver.spawn(kind, state.profile_dir)
    if proc == nil then
        fail_open(serr)
        return
    end
    state.proc = proc
    local rok, rerr = driver.wait_ready(kind)
    if not rok then
        fail_open(rerr)
        return
    end
    local session, nerr = driver.new_session(kind, state.profile_dir)
    if session == nil then
        fail_open(nerr)
        return
    end
    state.session_id = session.session_id
    local conn = M._make_conn(state)
    local transport, terr = transport_mod.connect(session.websocket_url, {
        on_text = function(text)
            wire.on_text(state.wire_state, text)
        end,
        on_disconnect = function()
            -- Dropped socket invalidates the session: fail fast, tear down.
            -- Runs on the uv read thread: defer out of fast event context
            -- (teardown calls vim.fn.delete; notify needs the main loop).
            defer(function()
                if current == state then
                    current = nil
                    M._teardown_state(state, real_deps(state))
                    vim.notify('bidi: socket dropped, session closed', vim.log.levels.WARN)
                end
            end)
        end,
        on_error = function(err)
            -- Handshake failure surfaces here, on the uv read thread:
            -- defer out of fast event context and fail the open so the
            -- caller's callback fires instead of hanging. After a
            -- successful open this is notify-only (done is true).
            defer(function()
                vim.notify('bidi transport error: ' .. err, vim.log.levels.ERROR)
                fail_open('bidi transport error during open: ' .. err)
            end)
        end,
    })
    if transport == nil then
        fail_open(terr)
        return
    end
    state.transport = transport
    bsession.status(conn, function(serr2, result)
        if serr2 ~= nil then
            fail_open('session.status failed: ' .. serr2)
            return
        end
        bctx.create(conn, 'tab', function(cerr, context_id)
            if cerr ~= nil then
                fail_open(cerr)
                return
            end
            state.context_id = context_id
            local ready = type(result) == 'table' and result.ready
            done = true
            callback(nil, {
                kind = kind,
                session_id = state.session_id,
                context_id = context_id,
                ready = ready,
            })
        end)
    end)
end

---Open a browser: verify + spawn driver, New Session, connect BiDi,
---session.status, create a tab. callback(err, info).
---@param kind string 'chrome' | 'firefox'
---@param callback fun(err: string?, info: table?)
function M.open(kind, callback)
    assert(type(callback) == 'function', 'callback must be a function')
    if current ~= nil and not current.torn_down then
        callback('a BiDi session is already open; :BidiClose first', nil)
        return
    end
    if kind ~= 'chrome' and kind ~= 'firefox' then
        callback("kind must be 'chrome' or 'firefox'", nil)
        return
    end
    local state = M._new_state()
    state.kind = kind
    state.profile_dir = vim.fn.tempname() .. '-bidi-profile'
    vim.fn.mkdir(state.profile_dir, 'p')
    current = state
    local function abort(err)
        current = nil
        M._teardown_state(state, real_deps(state))
        callback(err, nil)
    end
    continue_open(state, abort, callback)
end

---@param state BidiSessionState
---@return table? conn
---@return string? err
local function live_conn(state)
    if state == nil or state.torn_down then
        return nil, 'no BiDi session open (:BidiOpen first)'
    end
    if state.context_id == nil then
        return nil, 'BiDi session has no browsing context'
    end
    return M._make_conn(state), nil
end

---Navigate the session tab. callback(err, result).
---@param url string
---@param callback fun(err: string?, result: table?)
function M.navigate(url, callback)
    assert(type(callback) == 'function', 'callback must be a function')
    local conn, cerr = live_conn(current)
    if conn == nil then
        callback(cerr, nil)
        return
    end
    bctx.navigate(conn, current.context_id, url, callback)
end

---Evaluate JS in the session tab. Confirmation is the caller's job.
---callback(err, value) with value converted to Lua.
---@param expression string
---@param callback fun(err: string?, value: any)
function M.evaluate(expression, callback)
    assert(type(callback) == 'function', 'callback must be a function')
    local conn, cerr = live_conn(current)
    if conn == nil then
        callback(cerr, nil)
        return
    end
    bscript.evaluate(conn, { context = current.context_id }, expression, callback)
end

---Capture a screenshot into a scratch buffer as base64 (line-safe, never
---uploaded, never written to disk by this module). callback(err, bufnr).
---@param callback fun(err: string?, bufnr: integer?)
function M.screenshot(callback)
    assert(type(callback) == 'function', 'callback must be a function')
    local conn, cerr = live_conn(current)
    if conn == nil then
        callback(cerr, nil)
        return
    end
    bctx.capture_screenshot(conn, current.context_id, function(err, png)
        if err ~= nil then
            callback(err, nil)
            return
        end
        -- Response callbacks run in fast event context: creating the
        -- scratch buffer needs the main loop, so defer it.
        defer(function()
            local b64 = vim.base64.encode(png)
            current.last_screenshot = b64
            local buf = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_name(buf, 'bidi-screenshot://' .. current.session_id)
            local lines = { '# BiDi screenshot (base64 PNG, ' .. #png .. ' bytes)', '' }
            for i = 1, #b64, 76 do
                lines[#lines + 1] = b64:sub(i, i + 75)
            end
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
            vim.bo[buf].filetype = 'bidi-screenshot'
            vim.bo[buf].modifiable = false
            callback(nil, buf)
        end)
    end)
end

---Stream console entries to the quickfix list. callback(err).
---@param callback fun(err: string?)
function M.console(callback)
    assert(type(callback) == 'function', 'callback must be a function')
    local conn, cerr = live_conn(current)
    if conn == nil then
        callback(cerr)
        return
    end
    vim.fn.setqflist({}, 'r', { title = 'BiDi console' })
    blog.stream(conn, { current.context_id }, blog.append_qf, callback)
end

---Observe network traffic into the quickfix list. callback(err).
---@param callback fun(err: string?)
function M.network_log(callback)
    assert(type(callback) == 'function', 'callback must be a function')
    local conn, cerr = live_conn(current)
    if conn == nil then
        callback(cerr)
        return
    end
    local wire_mod = wire
    wire_mod.on_event(current.wire_state, 'network.beforeRequestSent', function(params)
        M._network_sink('network.beforeRequestSent', params)
    end)
    wire_mod.on_event(current.wire_state, 'network.responseStarted', function(params)
        M._network_sink('network.responseStarted', params)
    end)
    wire_mod.on_event(current.wire_state, 'network.responseCompleted', function(params)
        M._network_sink('network.responseCompleted', params)
    end)
    bnetwork.observe(conn, { current.context_id }, callback)
end

---Normalize one network event into a quickfix line. Exposed for tests.
---@param method string
---@param params table
function M._network_sink(method, params)
    -- Event handlers run in fast event context: setqflist needs the
    -- main loop, so defer it.
    defer(function()
        local event, nerr = bnetwork._normalize(method, params)
        if event == nil then
            vim.fn.setqflist({}, 'a', {
                title = 'BiDi network',
                items = { { text = 'unparseable network event: ' .. nerr, type = 'E' } },
            })
            return
        end
        local text = (event.method or '?') .. ' ' .. (event.url or '?')
        if event.status ~= nil then
            text = text .. ' -> ' .. tostring(event.status)
        end
        vim.fn.setqflist({}, 'a', {
            title = 'BiDi network',
            items = { { text = '[' .. event.kind .. '] ' .. text, type = 'I' } },
        })
    end)
end

return M
