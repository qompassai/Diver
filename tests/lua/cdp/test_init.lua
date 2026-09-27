-- tests/lua/cdp/test_init.lua
-- Connection manager tests: discovery, attach flow, frame routing,
-- teardown. Driven through the fake CDP server fixture.
---@module 'tests.cdp.test_init'

local t = require('cdp.t')
local cdp = require('dev.browser.cdp')
local domains = require('dev.browser.cdp.domains')
local fixture = require('cdp.fixture')

local tests = {}

local function fake_http_for(routes)
    return fixture.new_fake_http(routes)
end

-- Validation ------------------------------------------------------------

tests[#tests + 1] = {
    kind = 'V',
    name = 'discover parses version verbatim and filters page targets',
    fn = function()
        local http = fake_http_for(fixture.discovery_routes())
        local disc, err = cdp.discover({ host = '127.0.0.1', port = 9222, http = http })
        t.eq(err, nil, 'no error')
        t.not_nil(disc, 'discovery')
        local want = 'ws://127.0.0.1:9222/devtools/browser/aaaa-bbbb-cccc'
        t.eq(disc.browser_ws_url, want, 'verbatim ws url')
        t.eq(disc.browser_name, 'Chrome/120.0.6099.109', 'browser name')
        t.eq(disc.protocol_version, '1.3', 'protocol version')
        t.eq(#disc.pages, 2, 'two page targets')
        t.eq(disc.pages[1].id, 'page-1', 'first page')
        t.eq(#disc.targets, 3, 'all targets kept raw')
        -- Both endpoints were hit exactly once each.
        t.eq(#http.requests, 2, 'two http calls')
        t.eq(http.requests[1].path, '/json/version', 'version first')
        t.eq(http.requests[2].path, '/json/list', 'list second')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'discover treats a 404 version endpoint as not-CDP',
    fn = function()
        local routes = fixture.discovery_routes()
        routes['GET /json/version'] = { status = 404, body = 'nope' }
        local probe = { host = '127.0.0.1', port = 9222, http = fake_http_for(routes) }
        local disc, err = cdp.discover(probe)
        t.is_nil(disc, 'no discovery')
        t.err_match(err, 'not a CDP endpoint', 'reason')
        t.err_match(err, '404', 'status named')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'discover treats a non-JSON version body as not-CDP',
    fn = function()
        local routes = fixture.discovery_routes()
        routes['GET /json/version'] = { status = 200, body = '<html>not json' }
        local probe = { host = '127.0.0.1', port = 9222, http = fake_http_for(routes) }
        local disc, err = cdp.discover(probe)
        t.is_nil(disc, 'no discovery')
        t.err_match(err, 'not a CDP endpoint', 'reason')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'full connect flow: ws url verbatim, getVersion, flat attach',
    fn = function()
        local conn, ws, errors = fixture.connect_ready()
        t.eq(#errors, 0, 'no errors: ' .. table.concat(errors, '; '))
        local want = 'ws://127.0.0.1:9222/devtools/browser/aaaa-bbbb-cccc'
        t.eq(fixture.last_ws_url(), want, 'verbatim ws url used')
        t.eq(conn.target_session_id, 'sess-1', 'session id captured')
        t.eq(conn.target_id, 'page-1', 'first page attached')
        t.eq(conn.target_url, 'https://example.com/', 'target url captured')
        t.not_nil(conn.target_session, 'target session exists')
        -- Frame 1: Browser.getVersion, browser-level (no sessionId).
        local f1 = ws:sent_frame(1)
        t.eq(f1.method, 'Browser.getVersion', 'getVersion first')
        t.eq(f1.id, 1, 'browser id 1')
        t.is_nil(f1.sessionId, 'no sessionId browser-level')
        -- Frame 2: Target.attachToTarget with flatten.
        local f2 = ws:sent_frame(2)
        t.eq(f2.method, 'Target.attachToTarget', 'attach second')
        t.eq(f2.params.flatten, true, 'flat mode')
        t.eq(f2.params.targetId, 'page-1', 'target')
        cdp.close(conn)
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'target commands carry sessionId and restart ids at 1',
    fn = function()
        local conn, ws = fixture.connect_ready()
        domains.page.navigate(conn.target_session, 'https://example.com/', function() end)
        local frame = ws:sent_frame(3)
        t.eq(frame.method, 'Page.navigate', 'method')
        t.eq(frame.id, 1, 'target ids restart at 1')
        t.eq(frame.sessionId, 'sess-1', 'sessionId carried')
        -- Browser session ids continue independently (3rd browser command).
        domains.target.get_targets(conn.browser_session, function() end)
        local bframe = ws:sent_frame(4)
        t.eq(bframe.id, 3, 'browser ids continue')
        t.is_nil(bframe.sessionId, 'browser frame has no sessionId')
        cdp.close(conn)
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'explicit target_id attaches the requested page',
    fn = function()
        local conn, ws = fixture.connect_ready({ target_id = 'page-2' })
        t.eq(conn.target_id, 'page-2', 'requested page')
        t.eq(conn.target_url, 'https://other.test/', 'url matches')
        local f2 = ws:sent_frame(2)
        t.eq(f2.params.targetId, 'page-2', 'attach asked for page-2')
        cdp.close(conn)
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'close fails pending, drops the socket once, stops the pump',
    fn = function()
        local conn, ws = fixture.connect_ready()
        local errs = {}
        domains.page.navigate(conn.target_session, 'https://example.com/', function(_, err)
            errs[#errs + 1] = err
        end)
        cdp.close(conn)
        t.ok(conn.closed, 'marked closed')
        t.eq(#errs, 1, 'pending failed')
        t.err_match(errs[1], 'session closed', 'reason')
        t.eq(ws.disconnects, 1, 'socket closed exactly once')
        t.ok(ws.closed, 'ws closed')
        local timer = vim._recorded.timers[#vim._recorded.timers]
        t.ok(timer._closed, 'pump timer closed')
        cdp.close(conn) -- idempotent
        t.eq(ws.disconnects, 1, 'still once')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'pump expires overdue requests',
    fn = function()
        local conn, _ = fixture.connect_ready()
        local errs = {}
        domains.page.navigate(conn.target_session, 'https://example.com/', function(_, err)
            errs[#errs + 1] = err
        end)
        vim.uv._now = vim.uv._now + 120000
        cdp.pump(conn, vim.uv.now())
        t.eq(#errs, 1, 'expired')
        t.err_match(errs[1], 'timed out', 'reason')
        cdp.close(conn)
        vim.uv._now = 1000000 -- restore stub clock
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'browser-level events dispatch to the browser session',
    fn = function()
        local conn, ws = fixture.connect_ready()
        local seen = nil
        conn.browser_session:on('Target.targetCreated', function(params)
            seen = params
        end)
        local frame = '{"method":"Target.targetCreated",'
            .. '"params":{"targetInfo":{"targetId":"page-3"}}}'
        ws:receive_text(frame)
        t.not_nil(seen, 'event dispatched')
        t.eq(seen.targetInfo.targetId, 'page-3', 'params')
        cdp.close(conn)
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'pump with nothing pending is a silent no-op',
    fn = function()
        local conn, _, errors = fixture.connect_ready()
        cdp.pump(conn, vim.uv.now())
        t.eq(#errors, 0, 'no errors')
        t.eq(conn.browser_session:pending_count(), 0, 'browser clear')
        t.eq(conn.target_session:pending_count(), 0, 'target clear')
        cdp.close(conn)
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'close removes the owned temp profile exactly once',
    fn = function()
        local conn = fixture.connect_ready()
        conn._profile = '/tmp/x-cdp-profile-1-123456'
        vim._recorded.deletes = {}
        cdp.close(conn)
        t.eq(#vim._recorded.deletes, 1, 'profile removed')
        t.eq(vim._recorded.deletes[1].path, '/tmp/x-cdp-profile-1-123456', 'right path')
        cdp.close(conn)
        t.eq(#vim._recorded.deletes, 1, 'no second delete')
    end,
}

-- Adversarial -----------------------------------------------------------

tests[#tests + 1] = {
    kind = 'A',
    name = 'non-loopback host is refused before any network touch',
    fn = function()
        local http = fake_http_for(fixture.discovery_routes())
        local conn, err = cdp.connect({ host = '192.168.1.5', port = 9222, http = http })
        t.is_nil(conn, 'no connection')
        t.err_match(err, 'localhost-only', 'reason')
        t.eq(#http.requests, 0, 'no http attempted')
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'truncated JSON frames are reported and the connection survives',
    fn = function()
        local conn, ws, errors = fixture.connect_ready()
        ws:receive_text('{"id":1,"result":')
        t.eq(#errors, 1, 'reported')
        t.err_match(errors[1], 'malformed frame', 'reason')
        t.ok(not conn.closed, 'connection still alive')
        -- Still functional afterwards.
        local fired = false
        domains.page.navigate(conn.target_session, 'https://example.com/', function(result, err)
            fired = err == nil and result ~= nil
        end)
        ws:receive_text('{"id":1,"sessionId":"sess-1","result":{"frameId":"f1"}}')
        t.ok(fired, 'recovered and answered')
        cdp.close(conn)
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'response for an unknown id is ignored, not misrouted',
    fn = function()
        local conn, ws, errors = fixture.connect_ready()
        ws:receive_text('{"id":77,"result":{}}')
        t.eq(#errors, 1, 'reported')
        t.err_match(errors[1], 'unknown id', 'reason')
        cdp.close(conn)
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'cross-session id collision routes by sessionId',
    fn = function()
        local conn, ws, errors = fixture.connect_ready()
        local browser_got, target_got = nil, nil
        domains.target.get_targets(conn.browser_session, function(result, err)
            browser_got = { result = result, err = err }
        end) -- browser id 3
        domains.page.navigate(conn.target_session, 'https://example.com/', function(result, err)
            target_got = { result = result, err = err }
        end) -- target id 1
        -- Same numeric id, no sessionId: must NOT hit the target session.
        ws:receive_text('{"id":1,"result":{"targetInfos":[]}}')
        t.is_nil(target_got, 'target untouched')
        t.is_nil(browser_got, 'browser untouched (id 3 pending)')
        t.eq(#errors, 1, 'unknown id reported')
        -- Properly addressed frames resolve each side.
        ws:receive_text('{"id":1,"sessionId":"sess-1","result":{"frameId":"f1"}}')
        t.not_nil(target_got, 'target resolved')
        t.eq(target_got.result.frameId, 'f1', 'target result')
        ws:receive_text('{"id":3,"result":{"targetInfos":[]}}')
        t.not_nil(browser_got, 'browser resolved')
        t.eq(#browser_got.result.targetInfos, 0, 'browser result')
        cdp.close(conn)
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'frames for an unknown sessionId are dropped with a report',
    fn = function()
        local conn, ws, errors = fixture.connect_ready()
        ws:receive_text('{"id":1,"sessionId":"nope","result":{}}')
        t.eq(#errors, 1, 'reported')
        t.err_match(errors[1], 'unknown sessionId', 'reason')
        t.ok(not conn.closed, 'connection alive')
        cdp.close(conn)
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'socket killed mid-request tears down cleanly with no zombie',
    fn = function()
        local conn, ws, errors = fixture.connect_ready()
        local errs = {}
        domains.page.navigate(conn.target_session, 'https://example.com/', function(_, err)
            errs[#errs + 1] = err
        end)
        ws:try_disconnect() -- the kill
        t.ok(conn.closed, 'connection closed')
        t.eq(#errs, 1, 'pending failed')
        t.eq(ws.disconnects, 1, 'disconnect ran once, no loop')
        local timer = vim._recorded.timers[#vim._recorded.timers]
        t.ok(timer._closed, 'pump stopped: no zombie timer')
        t.eq(#errors, 1, 'disconnect reported')
        t.err_match(errors[1], 'disconnected', 'reason')
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'a non-array /json/list is a discovery error',
    fn = function()
        local routes = fixture.discovery_routes()
        routes['GET /json/list'] = { status = 200, body = '123' }
        local probe = { host = '127.0.0.1', port = 9222, http = fake_http_for(routes) }
        local disc, err = cdp.discover(probe)
        t.is_nil(disc, 'no discovery')
        t.err_match(err, 'JSON array', 'reason')
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'getVersion failure means not-CDP and closes the connection',
    fn = function()
        local cdp_mod = cdp
        local http = fake_http_for(fixture.discovery_routes())
        local ws, ws_new = fixture.new_fake_ws()
        local errors = {}
        local conn, cerr = cdp_mod.connect({
            host = '127.0.0.1',
            port = 9222,
            http = http,
            ws_new = ws_new,
            on_connected = function() end,
            on_error = function(err)
                errors[#errors + 1] = tostring(err)
            end,
        })
        t.not_nil(conn, 'connecting conn: ' .. tostring(cerr))
        ws:trigger_connect()
        ws:receive_text('{"id":1,"error":{"code":-32601,"message":"no such method"}}')
        t.ok(conn.closed, 'connection closed')
        t.ok(ws.closed, 'socket closed')
        t.eq(#errors, 1, 'reported')
        t.err_match(errors[1], 'not a CDP endpoint', 'reason')
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'unknown target_id is rejected before attaching',
    fn = function()
        local http = fake_http_for(fixture.discovery_routes())
        local ws, ws_new = fixture.new_fake_ws()
        local errors = {}
        local conn, cerr = cdp.connect({
            host = '127.0.0.1',
            port = 9222,
            target_id = 'ghost',
            http = http,
            ws_new = ws_new,
            on_connected = function() end,
            on_error = function(err)
                errors[#errors + 1] = tostring(err)
            end,
        })
        t.not_nil(conn, 'connecting conn: ' .. tostring(cerr))
        ws:trigger_connect()
        ws:receive_text('{"id":1,"result":{"protocolVersion":"1.3"}}')
        t.ok(conn.closed, 'closed')
        t.eq(#errors, 1, 'reported')
        t.err_match(errors[1], 'unknown target id', 'reason')
        t.eq(#ws.sent, 1, 'no attachToTarget sent')
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'event frames with bad method shapes are ignored safely',
    fn = function()
        local conn, ws, errors = fixture.connect_ready()
        ws:receive_text('{"method":123,"params":{}}')
        ws:receive_text('{"method":"no-dot-here","params":{}}')
        t.eq(#errors, 2, 'both reported')
        t.ok(not conn.closed, 'alive')
        cdp.close(conn)
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'close never deletes an unmarked profile path',
    fn = function()
        local conn = fixture.connect_ready()
        conn._profile = '/home/matt/.config/google-chrome'
        vim._recorded.deletes = {}
        cdp.close(conn)
        t.eq(#vim._recorded.deletes, 0, 'real profile untouched')
    end,
}

return { tests = tests }
