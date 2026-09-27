-- tests/lua/cdp/test_domains.lua
-- Domain wrapper tests: command shapes, param building, input validation.
---@module 'tests.cdp.test_domains'

local t = require('cdp.t')
local domains = require('dev.browser.cdp.domains')

local tests = {}

---@param session_id? string nil means browser-level session
local function new_fake_session(session_id)
    local s = {
        session_id = session_id,
        sent = {},
        _closed = false,
    }
    function s:send(method, params, callback)
        self.sent[#self.sent + 1] = { method = method, params = params, callback = callback }
        return #self.sent
    end
    function s:is_closed()
        return self._closed
    end
    return s
end

-- Validation ------------------------------------------------------------

tests[#tests + 1] = {
    kind = 'V',
    name = 'target.get_targets sends Target.getTargets',
    fn = function()
        local s = new_fake_session()
        local id, err = domains.target.get_targets(s, function() end)
        t.eq(err, nil, 'no error')
        t.eq(id, 1, 'id returned')
        t.eq(s.sent[1].method, 'Target.getTargets', 'method')
        t.is_nil(s.sent[1].params, 'no params')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'target.attach_to_target forces flatten=true',
    fn = function()
        local s = new_fake_session()
        domains.target.attach_to_target(s, 'page-1', function() end)
        t.eq(s.sent[1].method, 'Target.attachToTarget', 'method')
        t.eq(s.sent[1].params.targetId, 'page-1', 'target id')
        t.eq(s.sent[1].params.flatten, true, 'flatten forced')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'runtime.evaluate forces returnByValue and awaitPromise',
    fn = function()
        local s = new_fake_session('sess-1')
        domains.runtime.evaluate(s, '1 + 1', function() end)
        local params = s.sent[1].params
        t.eq(s.sent[1].method, 'Runtime.evaluate', 'method')
        t.eq(params.expression, '1 + 1', 'expression')
        t.eq(params.returnByValue, true, 'returnByValue')
        t.eq(params.awaitPromise, true, 'awaitPromise')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'page.capture_screenshot builds format/quality/clip',
    fn = function()
        local s = new_fake_session('sess-1')
        domains.page.capture_screenshot(s, {
            format = 'jpeg',
            quality = 80,
            clip = { x = 0, y = 0, width = 100, height = 100 },
        }, function() end)
        local params = s.sent[1].params
        t.eq(params.format, 'jpeg', 'format')
        t.eq(params.quality, 80, 'quality')
        t.eq(params.clip.width, 100, 'clip')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'browser.get_version sends Browser.getVersion',
    fn = function()
        local s = new_fake_session()
        domains.browser.get_version(s, function() end)
        t.eq(s.sent[1].method, 'Browser.getVersion', 'method')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'debugger.set_breakpoint_by_url sends urlRegex',
    fn = function()
        local s = new_fake_session('sess-1')
        domains.debugger.set_breakpoint_by_url(s, 'https://example\\.com/.*', function() end)
        t.eq(s.sent[1].method, 'Debugger.setBreakpointByUrl', 'method')
        t.eq(s.sent[1].params.urlRegex, 'https://example\\.com/.*', 'regex')
        t.eq(s.sent[1].params.lineNumber, 0, 'line zero')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'page.navigate sends the url',
    fn = function()
        local s = new_fake_session('sess-1')
        domains.page.navigate(s, 'https://example.com/', function() end)
        t.eq(s.sent[1].method, 'Page.navigate', 'method')
        t.eq(s.sent[1].params.url, 'https://example.com/', 'url')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'target.create_target and close_target send target ids',
    fn = function()
        local s = new_fake_session()
        domains.target.create_target(s, 'https://example.com/', function() end)
        t.eq(s.sent[1].method, 'Target.createTarget', 'method')
        t.eq(s.sent[1].params.url, 'https://example.com/', 'url')
        domains.target.close_target(s, 'page-9', function() end)
        t.eq(s.sent[2].method, 'Target.closeTarget', 'method')
        t.eq(s.sent[2].params.targetId, 'page-9', 'target id')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'get_response_body passes through bodies within the limit',
    fn = function()
        local s = new_fake_session('sess-1')
        local got, got_err = 'unset', 'unset'
        local function cb(result, err)
            got, got_err = result, err
        end
        local id, err = domains.network.get_response_body(s, 'req-1', 'text/html', cb)
        t.eq(err, nil, 'sent: ' .. tostring(err))
        t.eq(id, 1, 'id')
        s.sent[1].callback({ body = 'hello', base64Encoded = false }, nil)
        t.eq(got_err, nil, 'no error')
        t.eq(got.body, 'hello', 'body passed through')
    end,
}

-- Adversarial -----------------------------------------------------------

tests[#tests + 1] = {
    kind = 'A',
    name = 'get_response_body refuses image/png without sending',
    fn = function()
        local s = new_fake_session('sess-1')
        local id, err = domains.network.get_response_body(s, 'req-1', 'image/png', function() end)
        t.is_nil(id, 'no id')
        t.err_match(err, 'non-text MIME', 'refusal')
        t.eq(#s.sent, 0, 'nothing sent')
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'get_response_body refuses application/octet-stream',
    fn = function()
        local s = new_fake_session('sess-1')
        local function noop() end
        local id, err
        id, err = domains.network.get_response_body(s, 'req-1', 'application/octet-stream', noop)
        t.is_nil(id, 'no id')
        t.err_match(err, 'non-text MIME', 'refusal')
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'get_response_body allows text/*, json, and +json suffixes',
    fn = function()
        local s = new_fake_session('sess-1')
        local mimes = { 'text/html', 'text/plain; charset=utf-8' }
        mimes[#mimes + 1] = 'application/json'
        mimes[#mimes + 1] = 'application/vnd.api+json'
        for _, mime in ipairs(mimes) do
            local id, err = domains.network.get_response_body(s, 'req-1', mime, function() end)
            t.not_nil(id, 'allowed: ' .. mime .. ' err=' .. tostring(err))
        end
        t.eq(#s.sent, 4, 'four sent')
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'runtime.evaluate refuses empty and oversized expressions',
    fn = function()
        local s = new_fake_session('sess-1')
        local id, err = domains.runtime.evaluate(s, '', function() end)
        t.is_nil(id, 'empty refused')
        t.err_match(err, 'non-empty', 'reason')
        local big = string.rep('x', 70000)
        local id2, err2 = domains.runtime.evaluate(s, big, function() end)
        t.is_nil(id2, 'oversized refused')
        t.err_match(err2, 'exceeds', 'reason')
        t.eq(#s.sent, 0, 'nothing sent')
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'page.navigate refuses an empty url',
    fn = function()
        local s = new_fake_session('sess-1')
        local id, err = domains.page.navigate(s, '', function() end)
        t.is_nil(id, 'refused')
        t.err_match(err, 'non-empty', 'reason')
        t.eq(#s.sent, 0, 'nothing sent')
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'page commands refuse the browser-level session',
    fn = function()
        local s = new_fake_session(nil)
        local id, err = domains.page.enable(s, function() end)
        t.is_nil(id, 'refused')
        t.err_match(err, 'attached target session', 'reason')
        local id2, err2 = domains.runtime.evaluate(s, '1', function() end)
        t.is_nil(id2, 'refused')
        t.err_match(err2, 'attached target session', 'reason')
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'wrappers refuse a closed session',
    fn = function()
        local s = new_fake_session('sess-1')
        s._closed = true
        local id, err = domains.page.navigate(s, 'https://example.com/', function() end)
        t.is_nil(id, 'refused')
        t.err_match(err, 'closed', 'reason')
        t.eq(#s.sent, 0, 'nothing sent')
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'capture_screenshot rejects quality on png and bad formats',
    fn = function()
        local s = new_fake_session('sess-1')
        local shot_opts = { format = 'png', quality = 50 }
        local id, err = domains.page.capture_screenshot(s, shot_opts, function() end)
        t.is_nil(id, 'quality on png refused')
        t.err_match(err, 'jpeg', 'reason')
        local id2, err2 = domains.page.capture_screenshot(s, { format = 'gif' }, function() end)
        t.is_nil(id2, 'gif refused')
        t.err_match(err2, 'png', 'reason')
        t.eq(#s.sent, 0, 'nothing sent')
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'get_response_body refuses bodies over the limit',
    fn = function()
        local s = new_fake_session('sess-1')
        local got, got_err = 'unset', 'unset'
        local function cb(result, err)
            got, got_err = result, err
        end
        domains.network.get_response_body(s, 'req-1', 'text/html', cb)
        s.sent[1].callback({ body = string.rep('x', 1048577), base64Encoded = false }, nil)
        t.is_nil(got, 'body withheld')
        t.err_match(got_err, 'exceeds', 'limit named')
    end,
}

return { tests = tests }
