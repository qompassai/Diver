-- tests/lua/cdp/fixture.lua
-- Fake CDP server fixture: canned discovery HTTP responses and a
-- script-driven fake WebSocket. Tests drive the fake socket by hand.
---@module 'tests.cdp.fixture'

local json = require('cdp.json')

local M = {}

M.VERSION_BODY = table.concat({
    '{',
    '"Browser":"Chrome/120.0.6099.109",',
    '"Protocol-Version":"1.3",',
    '"User-Agent":"Mozilla/5.0 test",',
    '"V8-Version":"12.0.0",',
    '"WebKit-Version":"537.36",',
    '"webSocketDebuggerUrl":"ws://127.0.0.1:9222/devtools/browser/aaaa-bbbb-cccc"',
    '}',
})

M.LIST_BODY = table.concat({
    '[',
    '{"id":"page-1","type":"page","title":"Example","url":"https://example.com/",',
    '"webSocketDebuggerUrl":"ws://127.0.0.1:9222/devtools/page/page-1"},',
    '{"id":"bg-1","type":"background_page","title":"bg","url":"chrome-extension://x/bg.html"},',
    '{"id":"page-2","type":"page","title":"Other","url":"https://other.test/",',
    '"webSocketDebuggerUrl":"ws://127.0.0.1:9222/devtools/page/page-2"}',
    ']',
})

---Build a fake shared-HTTP-helper. routes maps "METHOD path" to
---{status, body} or to a function(opts) returning res|nil, err.
---@param routes table<string, table|fun(opts: table): table|nil, string|nil>
function M.new_fake_http(routes)
    local fake = { requests = {} }
    function fake.request(opts)
        fake.requests[#fake.requests + 1] = opts
        local key = tostring(opts.method) .. ' ' .. tostring(opts.path)
        local entry = routes[key]
        if entry == nil then
            return nil, 'connection refused'
        end
        if type(entry) == 'function' then
            return entry(opts)
        end
        return { status = entry.status or 200, headers = {}, body = entry.body or '' }
    end
    return fake
end

---Standard discovery routes answering version + list.
function M.discovery_routes()
    return {
        ['GET /json/version'] = { status = 200, body = M.VERSION_BODY },
        ['GET /json/list'] = { status = 200, body = M.LIST_BODY },
    }
end

---Fake websocket with hand-driven lifecycle. ws_new matches the factory
---shape init.connect expects; tests call ws:receive_text(frame) and
---ws:trigger_connect() to script the server side.
function M.new_fake_ws()
    local handlers = {}
    local ws = {
        sent = {},
        closed = false,
        disconnects = 0,
    }
    function ws:try_send_data(text)
        if self.closed then
            return nil, 'closed'
        end
        self.sent[#self.sent + 1] = text
        return true
    end
    function ws:try_disconnect()
        self.disconnects = self.disconnects + 1
        if self.closed then
            return
        end
        self.closed = true
        if handlers.on_disconnect ~= nil then
            handlers.on_disconnect()
        end
    end
    ---Server side: deliver one text frame to the client.
    function ws:receive_text(text)
        handlers.on_message(text)
    end
    function ws:trigger_connect()
        handlers.on_connect()
    end
    function ws:trigger_error(err)
        handlers.on_error(err)
    end
    ---Decode the n-th sent frame for assertions.
    function ws:sent_frame(n)
        local value, err = json.decode(self.sent[n])
        assert(value ~= nil, 'sent frame ' .. tostring(n) .. ' is not JSON: ' .. tostring(err))
        return value
    end
    local function ws_new(ws_opts)
        handlers.on_message = ws_opts.on_message
        handlers.on_connect = ws_opts.on_connect
        handlers.on_disconnect = ws_opts.on_disconnect
        handlers.on_error = ws_opts.on_error
        M._last_url = ws_opts.url
        return ws
    end
    return ws, ws_new
end

---The connect_addr the last fake ws was created with.
function M.last_ws_url()
    return M._last_url
end

---Full attach flow against the fakes: discover, ws connect, getVersion,
---attachToTarget. Returns the ready connection plus the fake ws, the
---recorded on_error list, and the fake http.
---@param overrides? { target_id?: string, routes?: table }
---@return table conn
---@return table ws
---@return string[] errors
---@return table http
function M.connect_ready(overrides)
    overrides = overrides or {}
    local cdp = require('dev.browser.cdp')
    local http = M.new_fake_http(overrides.routes or M.discovery_routes())
    local ws, ws_new = M.new_fake_ws()
    local errors = {}
    local ready = nil
    local conn_opts = {
        host = '127.0.0.1',
        port = 9222,
        http = http,
        ws_new = ws_new,
        on_connected = function(conn)
            ready = conn
        end,
        on_error = function(err)
            errors[#errors + 1] = tostring(err)
        end,
    }
    if overrides.target_id ~= nil then
        conn_opts.target_id = overrides.target_id
    end
    local conn, cerr = cdp.connect(conn_opts)
    assert(conn ~= nil, 'connect failed: ' .. tostring(cerr))
    ws:trigger_connect()
    -- Browser.getVersion is always id 1 on the browser session.
    ws:receive_text('{"id":1,"result":{"protocolVersion":"1.3","product":"Chrome/120.0"}}')
    -- Target.attachToTarget is always id 2 on the browser session.
    ws:receive_text('{"id":2,"result":{"sessionId":"sess-1"}}')
    assert(ready ~= nil, 'on_connected never fired; errors: ' .. table.concat(errors, '; '))
    return ready, ws, errors, http
end

return M
