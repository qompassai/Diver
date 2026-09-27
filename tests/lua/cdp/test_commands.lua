-- tests/lua/cdp/test_commands.lua
-- Command registration tests: the seven :Browser* commands exist,
-- demand a connection, and delegate to actions.
---@module 'tests.cdp.test_commands'

local t = require('cdp.t')
local commands = require('dev.browser.cdp.commands')
local fixture = require('cdp.fixture')

local tests = {}

local function error_notifies()
    local out = {}
    for _, note in ipairs(vim._recorded.notifies) do
        if note.level == vim.log.levels.ERROR then
            out[#out + 1] = note.msg
        end
    end
    return out
end

-- Validation ------------------------------------------------------------

tests[#tests + 1] = {
    kind = 'V',
    name = 'setup registers the seven Browser commands',
    fn = function()
        vim._recorded.commands = {}
        commands._setup_done = false
        t.eq(commands.setup(), true, 'setup ok')
        local want = {
            'BrowserOpen',
            'BrowserAttach',
            'BrowserNavigate',
            'BrowserEval',
            'BrowserScreenshot',
            'BrowserConsole',
            'BrowserNetwork',
        }
        for _, name in ipairs(want) do
            t.not_nil(vim._recorded.commands[name], 'registered: ' .. name)
            t.not_nil(vim._recorded.commands[name].handler, 'handler: ' .. name)
        end
        local count = 0
        for _ in pairs(vim._recorded.commands) do
            count = count + 1
        end
        t.eq(count, 7, 'exactly seven commands')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'setup is idempotent',
    fn = function()
        vim._recorded.commands = {}
        commands._setup_done = false
        commands.setup()
        commands.setup()
        local count = 0
        for _ in pairs(vim._recorded.commands) do
            count = count + 1
        end
        t.eq(count, 7, 'still seven')
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'BrowserNavigate with a connection sends Page.navigate',
    fn = function()
        vim._recorded.commands = {}
        commands._setup_done = false
        commands.setup()
        local conn, ws = fixture.connect_ready()
        commands._set_connection(conn)
        vim._recorded.notifies = {}
        vim._recorded.commands['BrowserNavigate'].handler({ args = 'https://example.com/' })
        local frame = ws:sent_frame(3)
        t.eq(frame.method, 'Page.navigate', 'navigated')
        ws:receive_text('{"id":1,"sessionId":"sess-1","result":{"frameId":"f"}}')
        t.eq(#error_notifies(), 0, 'no errors')
        commands._set_connection(nil)
        require('dev.browser.cdp').close(conn)
    end,
}

tests[#tests + 1] = {
    kind = 'V',
    name = 'BrowserConsole with a connection taps events and shows the tail',
    fn = function()
        vim._recorded.commands = {}
        commands._setup_done = false
        commands.setup()
        local conn, ws = fixture.connect_ready()
        commands._set_connection(conn)
        vim._recorded.notifies = {}
        vim._recorded.bufs = {}
        vim._recorded.commands['BrowserConsole'].handler({})
        -- Runtime.enable + Log.enable went out on the target session.
        t.eq(#ws.sent, 4, 'enable commands sent')
        t.eq(ws:sent_frame(3).method, 'Runtime.enable', 'runtime enabled')
        t.eq(ws:sent_frame(4).method, 'Log.enable', 'log enabled')
        t.eq(#vim._recorded.bufs, 1, 'tail buffer shown')
        t.eq(#error_notifies(), 0, 'no errors')
        commands._set_connection(nil)
        require('dev.browser.cdp').close(conn)
    end,
}

-- Adversarial -----------------------------------------------------------

tests[#tests + 1] = {
    kind = 'A',
    name = 'BrowserNavigate without a connection errors loudly',
    fn = function()
        vim._recorded.commands = {}
        commands._setup_done = false
        commands.setup()
        commands._set_connection(nil)
        vim._recorded.notifies = {}
        vim._recorded.commands['BrowserNavigate'].handler({ args = 'https://example.com/' })
        local errs = error_notifies()
        t.eq(#errs, 1, 'one error')
        t.err_match(errs[1], 'Not connected', 'message')
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'BrowserEval without a connection errors loudly',
    fn = function()
        commands._set_connection(nil)
        vim._recorded.notifies = {}
        vim._recorded.commands['BrowserEval'].handler({ args = '1+1' })
        local errs = error_notifies()
        t.eq(#errs, 1, 'one error')
        t.err_match(errs[1], 'Not connected', 'message')
    end,
}

tests[#tests + 1] = {
    kind = 'A',
    name = 'BrowserConsole without a connection errors loudly',
    fn = function()
        commands._set_connection(nil)
        vim._recorded.notifies = {}
        vim._recorded.commands['BrowserConsole'].handler({})
        local errs = error_notifies()
        t.eq(#errs, 1, 'one error')
        t.err_match(errs[1], 'Not connected', 'message')
    end,
}

return { tests = tests }
