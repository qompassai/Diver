-- tests/lua/cdp/test_session.lua
-- Session unit tests: ids, request/response matching, timeouts, events.
---@module 'tests.cdp.test_session'

local t = require('cdp.t')
local json = require('cdp.json')
local session = require('dev.browser.cdp.session')

local tests = {}

---@param overrides? table
local function new_session(overrides)
    overrides = overrides or {}
    local state = {
        sent = {},
        errors = {},
        now = 1000000,
        send_ok = true,
    }
    local opts = {
        session_id = overrides.session_id,
        transport = {
            send = function(text)
                if not state.send_ok then
                    return nil, 'boom'
                end
                state.sent[#state.sent + 1] = text
                return true
            end,
        },
        json_encode = json.encode,
        json_decode = json.decode,
        timeout_ms = overrides.timeout_ms or 5000,
        clock = function()
            return state.now
        end,
        on_error = function(err)
            state.errors[#state.errors + 1] = tostring(err)
        end,
    }
    if overrides.no_transport then
        opts.transport = nil
    end
    local s = session.new(opts)
    return s, state
end

local function last_sent_frame(state)
    local value, err = json.decode(state.sent[#state.sent])
    t.not_nil(value, 'sent frame decodes: ' .. tostring(err))
    return value
end

-- Validation ------------------------------------------------------------

tests[#tests + 1] = {
    kind = 'V',
    name = 'ids start at 1 and increment per session',
    fn = function()
        local s = new_session()
        t.eq(s:next_id(), 1, 'first id')
        t.eq(s:next_id(), 2, 'second id')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'send builds a browser-level frame without sessionId',
    fn = function()
        local s, state = new_session()
        local id, err = s:send('Target.getTargets', nil, function() end)
        t.eq(err, nil, 'no error')
        t.eq(id, 1, 'id')
        local frame = last_sent_frame(state)
        t.eq(frame.id, 1, 'frame id')
        t.eq(frame.method, 'Target.getTargets', 'frame method')
        t.is_nil(frame.sessionId, 'no sessionId on browser session')
        t.eq(s:pending_count(), 1, 'one pending')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'send on a target session carries sessionId',
    fn = function()
        local s, state = new_session({ session_id = 'sess-9' })
        s:send('Page.navigate', { url = 'https://example.com/' }, function() end)
        local frame = last_sent_frame(state)
        t.eq(frame.sessionId, 'sess-9', 'sessionId carried')
        t.eq(frame.params.url, 'https://example.com/', 'params carried')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'response matches pending request by id',
    fn = function()
        local s = new_session()
        local got_result, got_err = 'unset', 'unset'
        s:send('Page.navigate', nil, function(result, err)
            got_result, got_err = result, err
        end)
        local handled = s:handle_message({ id = 1, result = { frameId = 'f1' } })
        t.ok(handled, 'handled')
        t.eq(got_err, nil, 'no error')
        t.eq(got_result.frameId, 'f1', 'result delivered')
        t.eq(s:pending_count(), 0, 'pending cleared')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'cdp error responses reach the callback as (nil, err)',
    fn = function()
        local s = new_session()
        local got_result, got_err = 'unset', 'unset'
        s:send('Page.navigate', nil, function(result, err)
            got_result, got_err = result, err
        end)
        s:handle_message({ id = 1, error = { code = -32601, message = 'not found' } })
        t.is_nil(got_result, 'nil result')
        t.err_match(got_err, '-32601', 'code in error')
        t.err_match(got_err, 'not found', 'message in error')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'event dispatch calls the registered handler with params',
    fn = function()
        local s = new_session()
        local seen = nil
        local unsub, err = s:on('Runtime.consoleAPICalled', function(params)
            seen = params
        end)
        t.eq(err, nil, 'subscribed')
        t.not_nil(unsub, 'unsubscribe returned')
        local msg = { method = 'Runtime.consoleAPICalled', params = { type = 'log' } }
        local handled = s:handle_message(msg)
        t.ok(handled, 'handled')
        t.eq(seen.type, 'log', 'params delivered')
        unsub()
        seen = nil
        s:handle_message({ method = 'Runtime.consoleAPICalled', params = { type = 'log' } })
        t.is_nil(seen, 'unsubscribed handler not called')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'close fails pending requests and is idempotent',
    fn = function()
        local s, state = new_session()
        local errs = {}
        s:send('Page.navigate', nil, function(_, err)
            errs[#errs + 1] = err
        end)
        s:on('Page.loadEventFired', function() end)
        s:close()
        t.ok(s:is_closed(), 'closed')
        t.eq(#errs, 1, 'pending failed once')
        t.err_match(errs[1], 'session closed', 'close error')
        t.eq(s:pending_count(), 0, 'no pending left')
        s:close() -- idempotent: no second failure
        t.eq(#errs, 1, 'still one failure')
        local msg = { method = 'Page.loadEventFired', params = {} }
        t.eq(s:handle_message(msg), false, 'handlers cleared')
        t.is_nil(state.errors[1], 'no protocol error from close')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'check_timeouts expires only overdue requests',
    fn = function()
        local s, state = new_session({ timeout_ms = 1000 })
        local errs = {}
        s:send('Page.navigate', nil, function(_, err)
            errs[#errs + 1] = err
        end)
        t.eq(s:check_timeouts(state.now + 500), 0, 'nothing expired yet')
        t.eq(s:check_timeouts(state.now + 1000), 1, 'one expired')
        t.eq(#errs, 1, 'callback fired')
        t.err_match(errs[1], 'timed out', 'timeout error')
        t.err_match(errs[1], 'Page.navigate', 'method named')
        t.eq(s:pending_count(), 0, 'pending cleared')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'send without a transport is a clean (nil, err)',
    fn = function()
        local s = new_session({ no_transport = true })
        local id, err = s:send('Target.getTargets', nil, function() end)
        t.is_nil(id, 'no id')
        t.err_match(err, 'no transport', 'transport error')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'send after close is rejected',
    fn = function()
        local s = new_session()
        s:close()
        local id, err = s:send('Target.getTargets', nil, function() end)
        t.is_nil(id, 'no id')
        t.err_match(err, 'closed', 'closed error')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'multiple handlers on one event all fire in order',
    fn = function()
        local s = new_session()
        local order = {}
        s:on('Page.loadEventFired', function()
            order[#order + 1] = 'first'
        end)
        s:on('Page.loadEventFired', function()
            order[#order + 1] = 'second'
        end)
        local handled = s:handle_message({ method = 'Page.loadEventFired', params = {} })
        t.ok(handled, 'handled')
        t.eq(#order, 2, 'both fired')
        t.eq(order[1], 'first', 'registration order kept')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'request ids increment per session',
    fn = function()
        local s = new_session()
        local function noop() end
        local id1 = s:send('Page.enable', nil, noop)
        local id2 = s:send('Page.enable', nil, noop)
        t.eq(id1, 1, 'first id')
        t.eq(id2, 2, 'second id')
        t.eq(s:pending_count(), 2, 'both pending')
    end,
}

-- Adversarial -----------------------------------------------------------

tests[#tests + 1] = {
    kind = 'A',
    name = 'response for an unknown id is ignored without corrupting pending',
    fn = function()
        local s, state = new_session()
        local fired = false
        s:send('Page.navigate', nil, function()
            fired = true
        end)
        local handled = s:handle_message({ id = 999, result = {} })
        t.eq(handled, false, 'not handled')
        t.eq(#state.errors, 1, 'protocol error recorded')
        t.err_match(state.errors[1], 'unknown id', 'unknown id reported')
        t.eq(s:pending_count(), 1, 'real pending intact')
        t.eq(fired, false, 'callback not fired')
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'id counters are independent per session',
    fn = function()
        local a = new_session()
        local b = new_session({ session_id = 'sess-1' })
        t.eq(a:next_id(), 1, 'a starts at 1')
        t.eq(b:next_id(), 1, 'b starts at 1 too')
        t.eq(a:next_id(), 2, 'a independent')
        t.eq(b:next_id(), 2, 'b independent')
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'handler cap is enforced per event',
    fn = function()
        local s = new_session()
        local noop = function() end
        for _ = 1, 32 do
            local unsub, err = s:on('Runtime.consoleAPICalled', noop)
            t.not_nil(unsub, 'within cap')
            t.eq(err, nil, 'no error')
        end
        local unsub, err = s:on('Runtime.consoleAPICalled', noop)
        t.is_nil(unsub, 'no unsubscribe')
        t.err_match(err, 'too many handlers', 'cap error')
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'pending cap is enforced',
    fn = function()
        local s = new_session()
        local noop = function() end
        for _ = 1, 256 do
            local id, err = s:send('Target.getTargets', nil, noop)
            t.not_nil(id, 'within cap, err=' .. tostring(err))
        end
        local id, err = s:send('Target.getTargets', nil, noop)
        t.is_nil(id, 'no id past cap')
        t.err_match(err, 'pending request limit', 'cap error')
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'event with no handlers is ignored quietly',
    fn = function()
        local s, state = new_session()
        local handled = s:handle_message({ method = 'Network.requestWillBeSent', params = {} })
        t.eq(handled, false, 'not handled')
        t.is_nil(state.errors[1], 'no error recorded for unsubscribed chatter')
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'a raising handler does not break dispatch of the rest',
    fn = function()
        local s, state = new_session()
        local second_ran = false
        s:on('Runtime.consoleAPICalled', function()
            error('handler boom', 0)
        end)
        s:on('Runtime.consoleAPICalled', function()
            second_ran = true
        end)
        local handled = s:handle_message({ method = 'Runtime.consoleAPICalled', params = {} })
        t.ok(handled, 'handled')
        t.ok(second_ran, 'second handler still ran')
        t.eq(#state.errors, 1, 'failure reported')
        t.err_match(state.errors[1], 'event handler failed', 'report names the problem')
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'malformed method strings are rejected before sending',
    fn = function()
        local s, state = new_session()
        for _, bad in ipairs({ 'nope', 'a b.c', '', '.navigate', 'Page.' }) do
            local id, err = s:send(bad, nil, function() end)
            t.is_nil(id, 'no id for ' .. tostring(bad))
            t.err_match(err, 'Domain.command', 'shape error for ' .. tostring(bad))
        end
        local id, err = s:send(123, nil, function() end)
        t.is_nil(id, 'no id for non-string')
        t.err_match(err, 'Domain.command', 'shape error')
        t.eq(#state.sent, 0, 'nothing reached the wire')
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'non-table frames are ignored with a report',
    fn = function()
        local s, state = new_session()
        t.eq(s:handle_message('{"id":1}'), false, 'string frame ignored')
        t.eq(s:handle_message(42), false, 'number frame ignored')
        t.eq(#state.errors, 2, 'both reported')
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'frames with neither id nor method are ignored with a report',
    fn = function()
        local s, state = new_session()
        t.eq(s:handle_message({ result = {} }), false, 'ignored')
        t.eq(#state.errors, 1, 'reported')
        t.err_match(state.errors[1], 'neither id nor method', 'reason named')
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'a late response after timeout does not double-fire the callback',
    fn = function()
        local s, state = new_session({ timeout_ms = 1000 })
        local calls = 0
        s:send('Page.navigate', nil, function()
            calls = calls + 1
        end)
        state.now = state.now + 5000
        s:check_timeouts(state.now)
        t.eq(calls, 1, 'timeout fired once')
        local handled = s:handle_message({ id = 1, result = {} })
        t.eq(handled, false, 'stale id ignored')
        t.eq(calls, 1, 'still once')
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'transport failure rejects the send without leaking pending',
    fn = function()
        local s, state = new_session()
        state.send_ok = false
        local id, err = s:send('Page.navigate', nil, function() end)
        t.is_nil(id, 'no id')
        t.err_match(err, 'transport send failed', 'reason')
        t.err_match(err, 'boom', 'cause')
        t.eq(s:pending_count(), 0, 'no leaked pending')
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'a raising transport reports the raised error text',
    fn = function()
        local opts = {
            transport = {
                send = function(_)
                    error('socket exploded')
                end,
            },
            json_encode = json.encode,
            json_decode = json.decode,
            timeout_ms = 5000,
            clock = function()
                return 1000000
            end,
            on_error = function() end,
        }
        local sess = session.new(opts)
        local id, err = sess:send('Page.navigate', nil, function() end)
        t.is_nil(id, 'no id')
        t.err_match(err, 'raised', 'raise distinguished')
        t.err_match(err, 'socket exploded', 'cause preserved')
        t.eq(sess:pending_count(), 0, 'no leaked pending')
    end,
}

return { tests = tests }
