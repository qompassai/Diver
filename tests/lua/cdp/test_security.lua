-- tests/lua/cdp/test_security.lua
-- Security policy tests: loopback gate, temp profiles, confirmations.
---@module 'tests.cdp.test_security'

local t = require('cdp.t')
local security = require('dev.browser.cdp.security')

local tests = {}

local function reset_ui()
    vim._recorded.select_choice = nil
    vim._recorded.select_works = true
    vim._recorded.selects = {}
end

-- Validation ------------------------------------------------------------

tests[#tests + 1] = {
    kind = 'V',
    name = 'loopback hosts are accepted (case-insensitive)',
    fn = function()
        for _, host in ipairs({ '127.0.0.1', '::1', 'localhost', 'LOCALHOST' }) do
            t.ok(security.is_loopback(host), 'loopback: ' .. host)
            local ok, err = security.check_host(host)
            t.eq(ok, true, 'check passes: ' .. host .. ' err=' .. tostring(err))
        end
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'new_temp_profile returns a fresh unique path',
    fn = function()
        local a, err_a = security.new_temp_profile()
        local b, err_b = security.new_temp_profile()
        t.not_nil(a, 'profile a: ' .. tostring(err_a))
        t.not_nil(b, 'profile b: ' .. tostring(err_b))
        t.ok(a:find('cdp-profile', 1, true) ~= nil, 'marked as cdp profile')
        t.ok(a ~= b, 'unique per call')
        t.ok(a:find('Default', 1, true) == nil, 'never the real profile dir')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'confirm_eval shows the exact expression and URL, then allows',
    fn = function()
        reset_ui()
        local allowed, reason = 'unset', 'unset'
        local prompt_opts = { expression = 'document.title', url = 'https://example.com/' }
        security.confirm_eval(prompt_opts, function(a, r)
            allowed, reason = a, r
        end)
        t.eq(allowed, true, 'allowed')
        t.eq(reason, 'confirmed in prompt', 'reason')
        t.eq(#vim._recorded.selects, 1, 'one prompt')
        local prompt = vim._recorded.selects[1].opts.prompt
        t.ok(prompt:find('document.title', 1, true) ~= nil, 'exact expression shown')
        t.ok(prompt:find('https://example.com/', 1, true) ~= nil, 'url shown')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'confirm_attach names the target title and URL',
    fn = function()
        reset_ui()
        local allowed = 'unset'
        security.confirm_attach({ title = 'Example', url = 'https://example.com/' }, function(a, _)
            allowed = a
        end)
        t.eq(allowed, true, 'allowed')
        local prompt = vim._recorded.selects[1].opts.prompt
        t.ok(prompt:find('Example', 1, true) ~= nil, 'title shown')
        t.ok(prompt:find('https://example.com/', 1, true) ~= nil, 'url shown')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'confirm_eval honors an injected ui without touching globals',
    fn = function()
        local seen_prompt = nil
        local fake_ui = {
            select = function(items, opts, on_choice)
                seen_prompt = opts.prompt
                on_choice(items[1])
            end,
        }
        local allowed, reason = 'unset', 'unset'
        local prompt_opts = { expression = '1', url = 'https://example.com/', ui = fake_ui }
        security.confirm_eval(prompt_opts, function(a, r)
            allowed, reason = a, r
        end)
        t.eq(allowed, true, 'allowed')
        t.ok(seen_prompt:find('https://example.com/', 1, true) ~= nil, 'url in prompt')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'remove_temp_profile deletes a marked path and is idempotent',
    fn = function()
        vim._recorded.deletes = {}
        local path = '/tmp/x-cdp-profile-99-123456'
        local ok, err = security.remove_temp_profile(path)
        t.eq(ok, true, 'removed: ' .. tostring(err))
        t.eq(#vim._recorded.deletes, 1, 'one delete')
        t.eq(vim._recorded.deletes[1].path, path, 'right path')
        t.eq(vim._recorded.deletes[1].flags, 'rf', 'recursive')
        local ok2 = security.remove_temp_profile(path)
        t.eq(ok2, true, 'second removal also fine')
        t.eq(#vim._recorded.deletes, 2, 'delete retried, still marked')
    end,
}

-- Adversarial -----------------------------------------------------------

tests[#tests + 1] = {
    kind = 'A',
    name = 'non-loopback hosts are hard-refused with no override',
    fn = function()
        for _, host in ipairs({ '192.168.1.5', '10.0.0.1', 'example.com', '', '0.0.0.0' }) do
            t.ok(not security.is_loopback(host), 'not loopback: ' .. tostring(host))
            local ok, err = security.check_host(host)
            t.is_nil(ok, 'refused: ' .. tostring(host))
            t.err_match(err, 'localhost-only', 'reason for ' .. tostring(host))
        end
        local ok, err = security.check_host(nil)
        t.is_nil(ok, 'nil refused')
        t.err_match(err, 'localhost-only', 'reason')
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'lookalike hosts do not pass the gate',
    fn = function()
        local lookalikes = { '127.0.0.1.evil.com', 'evil-127.0.0.1', 'localhost.' }
        lookalikes[#lookalikes + 1] = ' 127.0.0.1'
        lookalikes[#lookalikes + 1] = '127.0.0.1 '
        for _, host in ipairs(lookalikes) do
            t.ok(not security.is_loopback(host), 'rejected: ' .. host)
            local ok, _ = security.check_host(host)
            t.is_nil(ok, 'check refuses: ' .. host)
        end
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'declining the eval prompt denies without running anything',
    fn = function()
        reset_ui()
        vim._recorded.select_choice = 'Cancel'
        local allowed, reason = 'unset', 'unset'
        local prompt_opts = { expression = 'alert(1)', url = 'https://example.com/' }
        security.confirm_eval(prompt_opts, function(a, r)
            allowed, reason = a, r
        end)
        t.eq(allowed, false, 'denied')
        t.eq(reason, 'cancelled', 'reason')
        vim._recorded.select_choice = nil
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'a broken confirmation UI denies eval',
    fn = function()
        reset_ui()
        vim._recorded.select_works = false
        local allowed, reason = 'unset', 'unset'
        local prompt_opts = { expression = 'alert(1)', url = 'https://example.com/' }
        security.confirm_eval(prompt_opts, function(a, r)
            allowed, reason = a, r
        end)
        t.eq(allowed, false, 'denied')
        t.err_match(reason, 'UI unavailable', 'reason')
        vim._recorded.select_works = true
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'empty expression or missing url never reaches a prompt',
    fn = function()
        reset_ui()
        local calls = 0
        local function on_decision(allowed, _)
            calls = calls + 1
            t.eq(allowed, false, 'denied')
        end
        security.confirm_eval({ expression = '', url = 'https://example.com/' }, on_decision)
        security.confirm_eval({ expression = 'x', url = '' }, on_decision)
        t.eq(calls, 2, 'both denied')
        t.eq(#vim._recorded.selects, 0, 'no prompt shown')
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'oversized expressions are rejected before any prompt',
    fn = function()
        reset_ui()
        local big = string.rep('y', 65537)
        local allowed, reason = 'unset', 'unset'
        local prompt_opts = { expression = big, url = 'https://example.com/' }
        security.confirm_eval(prompt_opts, function(a, r)
            allowed, reason = a, r
        end)
        t.eq(allowed, false, 'denied')
        t.err_match(reason, '64 KiB', 'bound named in reason')
        t.eq(#vim._recorded.selects, 0, 'no prompt shown')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'a long but in-bounds expression is shown in full',
    fn = function()
        reset_ui()
        local big = string.rep('z', 4000)
        local prompt_opts = { expression = big, url = 'https://example.com/' }
        security.confirm_eval(prompt_opts, function() end)
        t.eq(#vim._recorded.selects, 1, 'prompt shown')
        local prompt = vim._recorded.selects[1].opts.prompt
        t.ok(prompt:find(big, 1, true) ~= nil, 'exact expression present')
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'confirm_attach with a missing url denies immediately',
    fn = function()
        reset_ui()
        local allowed = 'unset'
        security.confirm_attach({ title = 'x', url = '' }, function(a, _)
            allowed = a
        end)
        t.eq(allowed, false, 'denied')
        t.eq(#vim._recorded.selects, 0, 'no prompt shown')
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'remove_temp_profile refuses unmarked paths',
    fn = function()
        vim._recorded.deletes = {}
        local bad_paths = { '/home/matt/.config/google-chrome', '/tmp/cdp-profile-evil' }
        for _, bad in ipairs(bad_paths) do
            local ok, err = security.remove_temp_profile(bad)
            t.is_nil(ok, 'refused: ' .. tostring(bad))
            t.err_match(err, 'refus', 'refusal named')
        end
        local ok_empty, err_empty = security.remove_temp_profile('')
        t.is_nil(ok_empty, 'empty refused')
        t.err_match(err_empty, 'no profile path', 'empty named')
        t.eq(#vim._recorded.deletes, 0, 'nothing deleted')
    end,
}

return { tests = tests }
