-- tests/lua/cdp/test_actions.lua
-- Action tests: validation, confirmation gating, taps, bounded buffers.
---@module 'tests.cdp.test_actions'

local t = require('cdp.t')
local actions = require('dev.browser.cdp.actions')
local fixture = require('cdp.fixture')

local tests = {}

local function reset_ui()
    vim._recorded.select_choice = nil
    vim._recorded.select_works = true
    vim._recorded.selects = {}
end

-- Validation ------------------------------------------------------------

tests[#tests + 1] = {
    kind = 'V',
    name = 'is_web_url accepts http(s) and rejects the rest',
    fn = function()
        t.ok(actions.is_web_url('https://example.com/'), 'https')
        t.ok(actions.is_web_url('http://127.0.0.1:9222/'), 'http')
        for _, bad in ipairs({ 'ftp://x/', 'javascript:alert(1)', '', 'notaurl', nil }) do
            t.ok(not actions.is_web_url(bad), 'rejected: ' .. tostring(bad))
        end
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'console ring is bounded and oldest-first',
    fn = function()
        local ring = actions.new_ring(5)
        for i = 1, 8 do
            ring:push({ n = i })
        end
        t.eq(ring:len(), 5, 'capped')
        local entries = ring:entries()
        t.eq(entries[1].n, 4, 'oldest dropped')
        t.eq(entries[5].n, 8, 'newest kept')
        ring:push('not a table')
        t.eq(ring:len(), 5, 'non-table ignored')
        ring:clear()
        t.eq(ring:len(), 0, 'cleared')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'network log is bounded',
    fn = function()
        local netlog = actions.new_network_log(3)
        for i = 1, 5 do
            netlog:push({ url = 'u' .. i })
        end
        t.eq(netlog:len(), 3, 'capped')
        t.eq(netlog:entries()[1].url, 'u3', 'oldest dropped')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'confirmed eval sends Runtime.evaluate and returns the value',
    fn = function()
        local conn, ws = fixture.connect_ready()
        local got, got_err = 'unset', 'unset'
        actions.eval(conn, '1 + 1', { confirmed = true }, function(err, result)
            got_err, got = err, result
        end)
        local frame = ws:sent_frame(3)
        t.eq(frame.method, 'Runtime.evaluate', 'method')
        t.eq(frame.params.expression, '1 + 1', 'expression')
        t.eq(frame.params.returnByValue, true, 'returnByValue')
        local raw = '{"id":1,"sessionId":"sess-1",'
            .. '"result":{"result":{"type":"number","value":2}}}'
        ws:receive_text(raw)
        t.eq(got_err, nil, 'no error')
        -- CDP wraps the value once: response.result = { result = RemoteObject }.
        t.eq(got.result.value, 2, 'value returned')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'navigate reports CDP errorText as the error',
    fn = function()
        local conn, ws = fixture.connect_ready()
        local got_err = 'unset'
        actions.navigate(conn, 'https://example.com/', function(err, _)
            got_err = err
        end)
        local frame = '{"id":1,"sessionId":"sess-1",'
            .. '"result":{"frameId":"f","errorText":"net::ERR_NAME_NOT_RESOLVED"}}'
        ws:receive_text(frame)
        t.err_match(got_err, 'ERR_NAME_NOT_RESOLVED', 'errorText surfaced')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'screenshot writes decoded PNG bytes to the chosen path',
    fn = function()
        local conn, ws = fixture.connect_ready()
        local path = '/tmp/cdp-shot-' .. tostring(os.time()) .. '.png'
        os.remove(path)
        local saved, saved_err = 'unset', 'unset'
        actions.screenshot(conn, path, function(err, result)
            saved_err, saved = err, result
        end)
        ws:receive_text('{"id":1,"sessionId":"sess-1","result":{"data":"aGVsbG8="}}')
        t.eq(saved_err, nil, 'no error')
        t.eq(saved, path, 'path returned')
        local fh = io.open(path, 'rb')
        t.not_nil(fh, 'file exists')
        local bytes = fh:read('*a')
        fh:close()
        os.remove(path)
        t.eq(bytes, 'hello', 'decoded bytes written')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'console tap fills the ring and emits CdpConsoleMessage',
    fn = function()
        local conn, ws = fixture.connect_ready()
        local ring = actions.new_ring()
        local ok, err = actions.enable_console_tap(conn, ring)
        t.eq(ok, true, 'tap enabled: ' .. tostring(err))
        local before = #vim._recorded.autocmds
        ws:receive_text(table.concat({
            '{"method":"Runtime.consoleAPICalled","sessionId":"sess-1",',
            '"params":{"type":"log","args":[{"type":"string","value":"hi"}],"timestamp":1}}',
        }))
        t.eq(ring:len(), 1, 'ring got the entry')
        t.eq(ring:entries()[1].type, 'log', 'entry type')
        t.eq(#vim._recorded.autocmds, before + 1, 'autocmd emitted')
        local last = vim._recorded.autocmds[#vim._recorded.autocmds]
        t.eq(last.opts.pattern, 'CdpConsoleMessage', 'pattern')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'network tap records requests with method and url',
    fn = function()
        local conn, ws = fixture.connect_ready()
        local netlog = actions.new_network_log()
        local ok, err = actions.enable_network_tap(conn, netlog)
        t.eq(ok, true, 'tap enabled: ' .. tostring(err))
        ws:receive_text(table.concat({
            '{"method":"Network.requestWillBeSent","sessionId":"sess-1",',
            '"params":{"requestId":"r1","request":{"method":"GET","url":"https://example.com/"},',
            '"timestamp":1}}',
        }))
        t.eq(netlog:len(), 1, 'one entry')
        t.eq(netlog:entries()[1].method, 'GET', 'method')
        t.eq(netlog:entries()[1].url, 'https://example.com/', 'url')
        ws:receive_text('{"method":"Network.loadingFailed","sessionId":"sess-1",'
            .. '"params":{"requestId":"r2","errorText":"net::ERR_FAILED"}}')
        t.eq(netlog:entries()[2].failed, true, 'failure flagged')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'debugger watch notifies on pause without stepping UI',
    fn = function()
        local conn, ws = fixture.connect_ready()
        local ok, err = actions.enable_debugger_watch(conn)
        t.eq(ok, true, 'watch enabled: ' .. tostring(err))
        local notes_before = #vim._recorded.notifies
        local autos_before = #vim._recorded.autocmds
        ws:receive_text('{"method":"Debugger.paused","sessionId":"sess-1",'
            .. '"params":{"reason":"breakpoint","callFrames":[]}}')
        t.eq(#vim._recorded.notifies, notes_before + 1, 'notification shown')
        local note = vim._recorded.notifies[#vim._recorded.notifies]
        t.ok(note.msg:find('paused', 1, true) ~= nil, 'pause named')
        t.eq(#vim._recorded.autocmds, autos_before + 1, 'autocmd emitted')
        t.eq(vim._recorded.autocmds[#vim._recorded.autocmds].opts.pattern, 'CdpPaused', 'pattern')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'show_console renders bounded lines into a scratch buffer',
    fn = function()
        local ring = actions.new_ring()
        local args = { { type = 'string', value = 'hello' } }
        ring:push({ kind = 'console', type = 'log', args = args })
        ring:push({ kind = 'log', level = 'error', text = 'boom happened' })
        vim._recorded.bufs = {}
        actions.show_console(ring)
        t.eq(#vim._recorded.bufs, 1, 'one scratch buffer')
        local lines = vim._recorded.bufs[1].lines
        t.eq(#lines, 2, 'two lines')
        t.ok(lines[1]:find('hello', 1, true) ~= nil, 'console arg rendered')
        t.ok(lines[2]:find('boom happened', 1, true) ~= nil, 'log text rendered')
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'oversized eval expression is refused before touching the wire',
    fn = function()
        local conn, ws = fixture.connect_ready()
        local got_err = 'unset'
        local big = string.rep('x', 70000)
        actions.eval(conn, big, {}, function(err, _)
            got_err = err
        end)
        t.err_match(got_err, '64 KiB', 'bound named')
        t.eq(#ws.sent, 2, 'nothing sent')
        require('dev.browser.cdp').close(conn)
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'console tap normalizes args into bounded previews',
    fn = function()
        local conn, ws = fixture.connect_ready()
        local ring = actions.new_ring()
        actions.enable_console_tap(conn, ring)
        local args = {}
        for _ = 1, 40 do
            local big = string.rep('v', 5000)
            args[#args + 1] = '{"type":"string","value":"' .. big .. '"}'
        end
        local frame = '{"method":"Runtime.consoleAPICalled","sessionId":"sess-1",'
            .. '"params":{"type":"log","args":[' .. table.concat(args, ',') .. '],"timestamp":1}}'
        ws:receive_text(frame)
        local entry = ring:entries()[1]
        t.eq(#entry.args, 32, 'arg count capped')
        t.ok(#entry.args[1].preview <= 4096 + 20, 'preview bounded')
        t.is_nil(entry.args[1].value, 'raw value not stored')
        t.is_nil(entry.args[1].description, 'raw description not stored')
        require('dev.browser.cdp').close(conn)
    end,
}

-- Adversarial -----------------------------------------------------------

tests[#tests + 1] = {
    kind = 'A',
    name = 'eval without confirmation and without UI is refused, nothing sent',
    fn = function()
        reset_ui()
        vim._recorded.select_works = false
        local conn, ws = fixture.connect_ready()
        local sent_before = #ws.sent
        local got_err = 'unset'
        actions.eval(conn, 'alert(1)', {}, function(err, _)
            got_err = err
        end)
        t.err_match(got_err, 'declined', 'refused')
        t.eq(#ws.sent, sent_before, 'nothing sent')
        vim._recorded.select_works = true
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'declining the eval prompt sends nothing',
    fn = function()
        reset_ui()
        vim._recorded.select_choice = 'Cancel'
        local conn, ws = fixture.connect_ready()
        local sent_before = #ws.sent
        local got_err = 'unset'
        actions.eval(conn, 'alert(1)', {}, function(err, _)
            got_err = err
        end)
        t.err_match(got_err, 'declined', 'refused')
        t.eq(#ws.sent, sent_before, 'nothing sent')
        vim._recorded.select_choice = nil
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'attach without confirmed=true is refused before connecting',
    fn = function()
        local got_err = 'unset'
        actions.attach('127.0.0.1', 9222, 'page-1', {}, function(err, _)
            got_err = err
        end)
        t.err_match(got_err, 'confirmation', 'refused')
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'attach with an empty target id is refused',
    fn = function()
        local got_err = 'unset'
        actions.attach('127.0.0.1', 9222, '', { confirmed = true }, function(err, _)
            got_err = err
        end)
        t.err_match(got_err, 'target_id', 'refused')
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'navigate rejects non-web urls before touching the wire',
    fn = function()
        local conn, ws = fixture.connect_ready()
        local sent_before = #ws.sent
        local got_err = 'unset'
        actions.navigate(conn, 'javascript:alert(1)', function(err, _)
            got_err = err
        end)
        t.err_match(got_err, 'http', 'refused')
        t.eq(#ws.sent, sent_before, 'nothing sent')
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'actions refuse a dead or missing connection',
    fn = function()
        local got_err = 'unset'
        actions.navigate(nil, 'https://example.com/', function(err, _)
            got_err = err
        end)
        t.err_match(got_err, 'not connected', 'nil conn refused')
        local conn, _ = fixture.connect_ready()
        require('dev.browser.cdp').close(conn)
        local got_err2 = 'unset'
        actions.eval(conn, '1', { confirmed = true }, function(err, _)
            got_err2 = err
        end)
        t.err_match(got_err2, 'not connected', 'closed conn refused')
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'screenshot failure surfaces the error and writes no file',
    fn = function()
        local conn, ws = fixture.connect_ready()
        local path = '/tmp/cdp-shot-fail-' .. tostring(os.time()) .. '.png'
        os.remove(path)
        local got_err = 'unset'
        actions.screenshot(conn, path, function(err, _)
            got_err = err
        end)
        ws:receive_text('{"id":1,"sessionId":"sess-1","error":{"code":-32000,"message":"nope"}}')
        t.err_match(got_err, 'nope', 'cdp error surfaced')
        local fh = io.open(path, 'rb')
        t.is_nil(fh, 'no file written')
        if fh ~= nil then
            fh:close()
        end
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'eval with an empty expression is refused',
    fn = function()
        local conn, ws = fixture.connect_ready()
        local sent_before = #ws.sent
        local got_err = 'unset'
        actions.eval(conn, '', { confirmed = true }, function(err, _)
            got_err = err
        end)
        t.err_match(got_err, 'non-empty', 'refused')
        t.eq(#ws.sent, sent_before, 'nothing sent')
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'open rejects bad ports and non-web urls without launching',
    fn = function()
        local got_err = 'unset'
        actions.open('https://example.com/', { port = 99999 }, function(err, _)
            got_err = err
        end)
        t.err_match(got_err, 'port', 'bad port refused')
        local got_err2 = 'unset'
        actions.open('javascript:alert(1)', {}, function(err, _)
            got_err2 = err
        end)
        t.err_match(got_err2, 'http', 'bad url refused')
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'network tap truncates a hostile errorText',
    fn = function()
        local conn, ws = fixture.connect_ready()
        local netlog = actions.new_network_log()
        actions.enable_network_tap(conn, netlog)
        local hostile = string.rep('e', 10000)
        ws:receive_text('{"method":"Network.loadingFailed","sessionId":"sess-1",'
            .. '"params":{"requestId":"r9","errorText":"' .. hostile .. '"}}')
        local entry = netlog:entries()[1]
        t.eq(entry.failed, true, 'failure flagged')
        t.ok(#entry.error_text <= 4096 + 20, 'error text bounded')
        require('dev.browser.cdp').close(conn)
    end,
}

return { tests = tests }
