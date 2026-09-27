-- BiDi wire.lua framing tests. Pure logic; runs under plain Lua 5.4.
-- run: ~/workspace/tools/lua-5.4.8/src/lua tests/lua/bidi/bidi_wire.lua

local src = debug.getinfo(1, 'S').source:sub(2)
local dir = src:match('^(.*)/[^/]+$')
local H = dofile(dir .. '/harness.lua')

local wire = require('dev.browser.bidi.wire')
wire.set_json(H.json_encode, H.json_decode)

local function new_state()
    return wire.new_state()
end

-- ---------------------------------------------------------- validation

H.test('next_command returns id 1 with method/params frame', false, function()
    local st = new_state()
    local id, text, err = wire.next_command(st, 'session.status', {}, nil)
    H.eq(id, 1)
    H.is_nil(err)
    local frame = H.json_decode(text)
    H.eq(frame.id, 1)
    H.eq(frame.method, 'session.status')
    H.eq(wire.pending_count(st), 0) -- no callback registered
end)

H.test('ids increment monotonically', false, function()
    local st = new_state()
    for i = 1, 3 do
        local id = wire.next_command(st, 'm', {}, nil)
        H.eq(id, i)
    end
end)

H.test('success response routes result to the right callback', false, function()
    local st = new_state()
    local got_err, got_result = 'unset', nil
    wire.next_command(st, 'session.status', {}, function(err, result)
        got_err, got_result = err, result
    end)
    wire.on_text(st, H.json_encode({ type = 'success', id = 1, result = { ready = true } }))
    H.is_nil(got_err)
    H.eq(got_result.ready, true)
    H.eq(wire.pending_count(st), 0)
end)

H.test('out-of-order responses match their commands', false, function()
    local st = new_state()
    local seen = {}
    for i = 1, 3 do
        wire.next_command(st, 'm' .. i, {}, function(err, result)
            seen[result.n] = true
            H.is_nil(err)
        end)
    end
    wire.on_text(st, H.json_encode({ type = 'success', id = 3, result = { n = 3 } }))
    wire.on_text(st, H.json_encode({ type = 'success', id = 1, result = { n = 1 } }))
    wire.on_text(st, H.json_encode({ type = 'success', id = 2, result = { n = 2 } }))
    H.is_true(seen[1] and seen[2] and seen[3])
    H.eq(wire.pending_count(st), 0)
end)

H.test('interleaved events dispatch while commands are pending', false, function()
    local st = new_state()
    local events = {}
    wire.on_event(st, 'log.entryAdded', function(params)
        events[#events + 1] = params.text
    end)
    local done = false
    wire.next_command(st, 'session.subscribe', {}, function()
        done = true
    end)
    local ev_a = { type = 'event', method = 'log.entryAdded', params = { text = 'a' } }
    local ev_b = { type = 'event', method = 'log.entryAdded', params = { text = 'b' } }
    wire.on_text(st, H.json_encode(ev_a))
    wire.on_text(st, H.json_encode(ev_b))
    H.eq(#events, 2)
    H.eq(events[1], 'a')
    H.eq(events[2], 'b')
    H.is_true(not done) -- command still pending
    wire.on_text(st, H.json_encode({ type = 'success', id = 1, result = {} }))
    H.is_true(done)
end)

H.test('error response delivers name and message', false, function()
    local st = new_state()
    local got_err = nil
    wire.next_command(st, 'x', {}, function(err)
        got_err = err
    end)
    wire.on_text(
        st,
        H.json_encode({ type = 'error', id = 1, error = 'no such alert', message = 'boom' })
    )
    H.matches(got_err, 'no such alert')
    H.matches(got_err, 'boom')
end)

H.test('error response without message still names the error', false, function()
    local st = new_state()
    local got_err = nil
    wire.next_command(st, 'x', {}, function(err)
        got_err = err
    end)
    wire.on_text(st, H.json_encode({ type = 'error', id = 1, error = 'unknown error' }))
    H.eq(got_err, 'unknown error')
end)

H.test('fail_all empties pending and calls every callback', false, function()
    local st = new_state()
    local errs = {}
    for _ = 1, 4 do
        wire.next_command(st, 'm', {}, function(err)
            errs[#errs + 1] = err
        end)
    end
    wire.fail_all(st, 'socket dropped')
    H.eq(#errs, 4)
    for i = 1, 4 do
        H.eq(errs[i], 'socket dropped')
    end
    H.eq(wire.pending_count(st), 0)
end)

H.test('handlers can be removed with off_event', false, function()
    local st = new_state()
    local n = 0
    wire.on_event(st, 'log.entryAdded', function()
        n = n + 1
    end)
    wire.off_event(st, 'log.entryAdded')
    wire.on_text(st, H.json_encode({ type = 'event', method = 'log.entryAdded', params = {} }))
    H.eq(n, 0)
    H.eq(st.counters.unknown_event, 1)
end)

-- ---------------------------------------------------------- adversarial

H.test('malformed JSON is dropped and counted, pending untouched', true, function()
    local st = new_state()
    local fired = false
    wire.next_command(st, 'm', {}, function()
        fired = true
    end)
    wire.on_text(st, '{"type": "success", "id": 1, ')
    wire.on_text(st, 'not json at all')
    H.eq(st.counters.malformed, 2)
    H.is_true(not fired)
    H.eq(wire.pending_count(st), 1)
end)

H.test('non-table JSON values are dropped', true, function()
    local st = new_state()
    wire.on_text(st, '42')
    wire.on_text(st, '"hello"')
    wire.on_text(st, 'null')
    H.eq(st.counters.malformed, 3)
    -- a JSON array decodes fine but is not a BiDi frame: bad_shape, not malformed
    wire.on_text(st, '[1,2,3]')
    H.eq(st.counters.malformed, 3)
    H.eq(st.counters.bad_shape, 1)
end)

H.test('success for an unknown id is stale, not misdelivered', true, function()
    local st = new_state()
    local fired = false
    wire.next_command(st, 'm', {}, function()
        fired = true
    end)
    wire.on_text(st, H.json_encode({ type = 'success', id = 999, result = {} }))
    H.eq(st.counters.stale, 1)
    H.is_true(not fired)
    H.eq(wire.pending_count(st), 1)
end)

H.test('error for an unknown id is stale', true, function()
    local st = new_state()
    wire.on_text(st, H.json_encode({ type = 'error', id = 7, error = 'x' }))
    H.eq(st.counters.stale, 1)
end)

H.test('success frame without numeric id is bad_shape', true, function()
    local st = new_state()
    wire.on_text(st, H.json_encode({ type = 'success', result = {} }))
    wire.on_text(st, H.json_encode({ type = 'success', id = 'one', result = {} }))
    H.eq(st.counters.bad_shape, 2)
end)

H.test('event without method or params is bad_shape', true, function()
    local st = new_state()
    wire.on_text(st, H.json_encode({ type = 'event', params = {} }))
    wire.on_text(st, H.json_encode({ type = 'event', method = 'log.entryAdded' }))
    H.eq(st.counters.bad_shape, 2)
end)

H.test('unknown event method is counted, handler absence never crashes', true, function()
    local st = new_state()
    local seen = nil
    st.on_unknown_event = function(method, _params)
        seen = method
    end
    wire.on_text(st, H.json_encode({ type = 'event', method = 'weird.future', params = {} }))
    H.eq(st.counters.unknown_event, 1)
    H.eq(seen, 'weird.future')
end)

H.test('frame with unknown type is bad_shape', true, function()
    local st = new_state()
    wire.on_text(st, H.json_encode({ type = 'ack', id = 1 }))
    H.eq(st.counters.bad_shape, 1)
end)

H.test('id wraps at ID_MAX back to 1', true, function()
    local st = new_state()
    st.seq = wire.ID_MAX
    local id = wire.next_command(st, 'm', {}, nil)
    H.eq(id, 1)
    H.eq(st.seq, 1)
end)

os.exit(H.run('bidi_wire'))

-- ------------------------------------------------- empty-params encoding
-- chromedriver strictly requires params to be a JSON dictionary; an
-- empty Lua table encodes as [] with naive encoders, which chromedriver
-- rejects. next_command consults the injected empty_dict factory.

H.test('empty params use the injected empty_dict factory', false, function()
    wire.set_json(H.json_encode, H.json_decode, function()
        return { __empty_dict = true }
    end)
    local st = new_state()
    local _, text = wire.next_command(st, 'session.status', {}, nil)
    local frame = H.json_decode(text)
    H.eq(type(frame.params), 'table')
    H.eq(frame.params.__empty_dict, true)
    wire.set_json(H.json_encode, H.json_decode, function()
        return {}
    end)
end)

H.test('nil params use the empty_dict factory, never encode bare', true, function()
    wire.set_json(H.json_encode, H.json_decode, function()
        return { __empty_dict = true }
    end)
    local st = new_state()
    local _, text = wire.next_command(st, 'session.status', nil, nil)
    local frame = H.json_decode(text)
    H.eq(type(frame.params), 'table')
    H.eq(frame.params.__empty_dict, true)
    wire.set_json(H.json_encode, H.json_decode, function()
        return {}
    end)
end)

H.test('non-empty params bypass the empty_dict factory untouched', true, function()
    local factory_calls = 0
    wire.set_json(H.json_encode, H.json_decode, function()
        factory_calls = factory_calls + 1
        return {}
    end)
    local st = new_state()
    local _, text = wire.next_command(st, 'm', { a = 1 }, nil)
    local frame = H.json_decode(text)
    H.eq(frame.params.a, 1)
    H.eq(factory_calls, 0)
    wire.set_json(H.json_encode, H.json_decode, function()
        return {}
    end)
end)
