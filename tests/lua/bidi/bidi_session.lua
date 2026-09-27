-- BiDi session lifecycle + pure-helper tests. Runs under plain Lua 5.4:
-- exactly-once teardown, screenshot bounds, RemoteValue conversion,
-- network/log normalization, URL policy, driver pure helpers.
-- Driver/browser integration tests SKIP here (no vim.uv, no drivers).
-- run: ~/workspace/tools/lua-5.4.8/src/lua tests/lua/bidi/bidi_session.lua

local src = debug.getinfo(1, 'S').source:sub(2)
local dir = src:match('^(.*)/[^/]+$')
local H = dofile(dir .. '/harness.lua')

local wire = require('dev.browser.bidi.wire')
wire.set_json(H.json_encode, H.json_decode)
local bidi = require('dev.browser.bidi')
local bctx = require('dev.browser.bidi.browsing_context')
local bscript = require('dev.browser.bidi.script')
local bnetwork = require('dev.browser.bidi.network')
local blog = require('dev.browser.bidi.log')
local btransport = require('dev.browser.bidi.transport')
local bdriver = require('dev.browser.bidi.driver')
local bconfig = require('dev.browser.bidi.config')

-- ---------------------------------------------------------- validation

H.test('first teardown runs every dep step', false, function()
    local st = bidi._new_state()
    local calls = {}
    local first = bidi._teardown_state(st, {
        session_finish = function()
            calls[#calls + 1] = 'finish'
        end,
        close_transport = function()
            calls[#calls + 1] = 'transport'
        end,
        kill_driver = function()
            calls[#calls + 1] = 'kill'
        end,
        remove_profile = function()
            calls[#calls + 1] = 'profile'
        end,
    })
    H.is_true(first)
    H.eq(#calls, 4)
    H.is_true(st.torn_down)
end)

H.test('new state is clean and wire-backed', false, function()
    local st = bidi._new_state()
    H.is_true(not st.torn_down)
    H.not_nil(st.wire_state)
    H.eq(wire.pending_count(st.wire_state), 0)
end)

H.test('small screenshots pass the size gate', false, function()
    local ok = bctx._check_image_bytes(1024 * 1024)
    H.is_true(ok)
end)

H.test('RemoteValue primitives convert', false, function()
    H.eq(bscript._from_remote({ type = 'string', value = 'hi' }, 0), 'hi')
    H.eq(bscript._from_remote({ type = 'number', value = 42 }, 0), 42)
    H.eq(bscript._from_remote({ type = 'boolean', value = true }, 0), true)
    H.is_nil(bscript._from_remote({ type = 'undefined' }, 0))
    H.is_nil(bscript._from_remote({ type = 'null', value = nil }, 0))
    local big = bscript._from_remote({ type = 'bigint', value = '9007199254740993' }, 0)
    H.eq(big, '9007199254740993')
end)

H.test('RemoteValue array and pair-list object convert', false, function()
    local arr = bscript._from_remote({
        type = 'array',
        value = {
            { type = 'number', value = 1 },
            { type = 'string', value = 'two' },
        },
    }, 0)
    H.eq(arr[1], 1)
    H.eq(arr[2], 'two')
    local obj = bscript._from_remote({
        type = 'object',
        value = {
            { { type = 'string', value = 'title' }, { type = 'string', value = 'Example' } },
        },
    }, 0)
    H.eq(obj.title, 'Example')
end)

H.test('network.beforeRequestSent normalizes', false, function()
    local e = bnetwork._normalize('network.beforeRequestSent', {
        requestId = 'r1',
        request = { method = 'GET', url = 'https://example.com/' },
        timestamp = 123,
    })
    H.not_nil(e)
    H.eq(e.kind, 'request')
    H.eq(e.method, 'GET')
    H.eq(e.url, 'https://example.com/')
end)

H.test('network.responseCompleted carries status', false, function()
    local e = bnetwork._normalize('network.responseCompleted', {
        requestId = 'r1',
        request = { method = 'GET', url = 'https://example.com/' },
        response = { status = 200, url = 'https://example.com/' },
    })
    H.not_nil(e)
    H.eq(e.kind, 'response-done')
    H.eq(e.status, 200)
end)

H.test('log entry maps error level to E', false, function()
    local item = blog._to_qf_item({ level = 'error', text = 'boom', source = {} })
    H.eq(item.type, 'E')
    H.eq(item.text, 'boom')
    local warn = blog._to_qf_item({ level = 'warning', text = 'careful' })
    H.eq(warn.type, 'W')
end)

H.test('transport accepts loopback ws urls', false, function()
    local ok1 = btransport._validate_url('ws://127.0.0.1:9515/session/abc')
    H.not_nil(ok1)
    local ok2 = btransport._validate_url('ws://localhost:4444/session')
    H.not_nil(ok2)
end)

-- ---------------------------------------------------------- adversarial

H.test('second teardown is a no-op: deps run exactly once', true, function()
    local st = bidi._new_state()
    local counts = { finish = 0, transport = 0, kill = 0, profile = 0 }
    local deps = {
        session_finish = function()
            counts.finish = counts.finish + 1
        end,
        close_transport = function()
            counts.transport = counts.transport + 1
        end,
        kill_driver = function()
            counts.kill = counts.kill + 1
        end,
        remove_profile = function()
            counts.profile = counts.profile + 1
        end,
    }
    H.is_true(bidi._teardown_state(st, deps))
    H.is_true(not bidi._teardown_state(st, deps))
    H.is_true(not bidi._teardown_state(st, deps))
    H.eq(counts.finish, 1)
    H.eq(counts.transport, 1)
    H.eq(counts.kill, 1)
    H.eq(counts.profile, 1)
end)

H.test('a failing dep step never blocks the remaining steps', true, function()
    local st = bidi._new_state()
    local ran = {}
    bidi._teardown_state(st, {
        session_finish = function()
            error('browser already gone')
        end,
        close_transport = function()
            ran.transport = true
        end,
        kill_driver = function()
            error('no such process')
        end,
        remove_profile = function()
            ran.profile = true
        end,
    })
    H.is_true(ran.transport)
    H.is_true(ran.profile)
end)

H.test('50MB screenshot is rejected by the bound', true, function()
    local ok, err = bctx._check_image_bytes(50 * 1024 * 1024)
    H.is_nil(ok)
    H.matches(err, tostring(bconfig.screenshot_bytes_max))
end)

H.test('deeply nested RemoteValue terminates at the depth bound', true, function()
    local deep = { type = 'string', value = 'leaf' }
    for _ = 1, 200 do
        deep = { type = 'array', value = { deep } }
    end
    local v = bscript._from_remote(deep, 0)
    -- must terminate; over-budget levels collapse to nil
    H.is_true(v == nil or type(v) == 'table')
end)

H.test('huge RemoteValue array is item-bounded', true, function()
    local big = { type = 'array', value = {} }
    for i = 1, 20000 do
        big.value[i] = { type = 'number', value = i }
    end
    local v = bscript._from_remote(big, 0)
    H.eq(#v, bconfig.remote_value_items_max)
end)

H.test('non-loopback webSocketUrl is refused by driver and transport', true, function()
    local ok1, err1 = bdriver._check_ws_url('ws://192.168.1.5:9515/session/x')
    H.is_nil(ok1)
    H.matches(err1, 'non-loopback')
    local ok2, err2 = btransport._validate_url('ws://browser.evil.example:9515/session')
    H.is_nil(ok2)
    H.matches(err2, 'non-loopback')
    local ok3, err3 = bdriver._check_ws_url('wss://127.0.0.1:9515/x')
    H.is_nil(ok3)
    H.matches(err3, 'unparseable')
end)

H.test('session extraction rejects missing sessionId/webSocketUrl', true, function()
    local no_sid = { value = { capabilities = { webSocketUrl = 'ws://x' } } }
    local s1, e1 = bdriver._extract_session(no_sid)
    H.is_nil(s1)
    H.matches(e1, 'sessionId')
    local s2, e2 = bdriver._extract_session({ value = { sessionId = 's', capabilities = {} } })
    H.is_nil(s2)
    H.matches(e2, 'webSocketUrl')
    local s3, e3 = bdriver._extract_session('garbage')
    H.is_nil(s3)
    H.not_nil(e3)
end)

H.test('rapid close mid-flight fails every pending command fast', true, function()
    local st = bidi._new_state()
    local errs = {}
    for _ = 1, 5 do
        wire.next_command(st.wire_state, 'script.evaluate', {}, function(err)
            errs[#errs + 1] = err
        end)
    end
    H.eq(wire.pending_count(st.wire_state), 5)
    -- simulate the disconnect path: fail_all + exactly-once teardown
    wire.fail_all(st.wire_state, 'bidi session closed')
    local first = bidi._teardown_state(st, {})
    H.is_true(first)
    H.eq(#errs, 5)
    for i = 1, 5 do
        H.eq(errs[i], 'bidi session closed')
    end
    H.eq(wire.pending_count(st.wire_state), 0)
end)

H.test('sha256sum output must be 64 hex chars', true, function()
    local h1, e1 = bdriver._parse_sha256sum_output('not a hash  /bin/false\n')
    H.is_nil(h1)
    H.not_nil(e1)
    local h2, e2 = bdriver._parse_sha256sum_output('abcd  /bin/false\n')
    H.is_nil(h2)
    H.not_nil(e2)
    local good = string.rep('ab', 32) .. '  /usr/bin/chromedriver\n'
    local h3 = bdriver._parse_sha256sum_output(good)
    H.eq(h3, string.rep('ab', 32))
end)

H.test('underlying WS client honors reconnect = false', false, function()
    local ws = require('ai.websocket.client')
    local c = ws.WebsocketClient.new({
        connect_addr = 'ws://127.0.0.1:9515/session',
        reconnect = false, -- what transport.lua passes: BiDi needs reconnect OFF
        on_message = function() end,
    })
    H.is_true(c.auto_reconnect == false)
end)

os.exit(H.run('bidi_session'))
