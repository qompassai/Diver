-- tests/lua/cdp/vim_stub.lua
-- Minimal _G.vim for plain-Lua 5.4 testing of the CDP modules.
-- Records notifications, autocmds, user commands, ui.select calls, and
-- timers so tests can assert behavior without Neovim.
---@module 'tests.cdp.vim_stub'

local json = require('cdp.json')

local B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local function b64_decode(data)
    local out = {}
    local bits = 0
    local acc = 0
    for i = 1, #data do
        local c = data:sub(i, i)
        if c ~= '=' then
            local v = B64:find(c, 1, true)
            if v == nil then
                error('bad base64 char: ' .. c, 0)
            end
            acc = acc * 64 + (v - 1)
            bits = bits + 6
            if bits >= 8 then
                bits = bits - 8
                out[#out + 1] = string.char(math.floor(acc / (2 ^ bits)) % 256)
                acc = acc % (2 ^ bits)
            end
        end
    end
    return table.concat(out)
end

local function b64_encode(data)
    local out = {}
    for i = 1, #data, 3 do
        local a, b, c = string.byte(data, i, i + 2)
        b = b or 0
        c = c or 0
        local n = a * 65536 + b * 256 + c
        local pad = 3 - math.min(3, #data - i + 1)
        for j = 3, 0, -1 do
            if j < pad then
                out[#out + 1] = '='
            else
                local sextet = math.floor(n / (64 ^ j)) % 64 + 1
                out[#out + 1] = B64:sub(sextet, sextet)
            end
        end
    end
    return table.concat(out)
end

local recorded = {
    notifies = {},
    autocmds = {},
    commands = {},
    selects = {},
    confirms = {},
    timers = {},
    bufs = {},
    deletes = {},
    tempname_calls = 0,
    ---Test control: ui.select returns this choice (default: first item).
    select_choice = nil,
    ---Test control: when false, ui.select raises (simulates broken UI).
    select_works = true,
}

local vim = {}
vim._recorded = recorded

vim.json = { decode = json.decode, encode = json.encode }
vim.log = { levels = { DEBUG = 0, INFO = 1, WARN = 2, ERROR = 3 } }

function vim.notify(message, level)
    recorded.notifies[#recorded.notifies + 1] = { msg = tostring(message), level = level }
end

function vim.inspect(value)
    return tostring(value)
end

vim.uv = {
    _now = 1000000,
}
function vim.uv.now()
    return vim.uv._now
end
function vim.uv.hrtime()
    return vim.uv._now * 1000000
end
function vim.uv.new_timer()
    local timer = { _started = false, _stopped = false, _closed = false, _cb = nil }
    function timer:start(_, _, cb)
        timer._started = true
        timer._cb = cb
        return 0
    end
    function timer:stop()
        timer._stopped = true
        return 0
    end
    function timer:close()
        timer._closed = true
        return 0
    end
    function timer:is_closing()
        return timer._closed
    end
    recorded.timers[#recorded.timers + 1] = timer
    return timer
end

vim.fn = {}
function vim.fn.tempname()
    recorded.tempname_calls = recorded.tempname_calls + 1
    return '/tmp/cdp-test-' .. tostring(recorded.tempname_calls)
end
function vim.fn.executable(bin)
    if bin == 'google-chrome' or bin == 'chromium' then
        return 1
    end
    return 0
end
function vim.fn.confirm(_)
    recorded.confirms[#recorded.confirms + 1] = true
    return 1
end
function vim.fn.delete(path, flags)
    recorded.deletes[#recorded.deletes + 1] = { path = path, flags = flags }
    return 0
end

vim.api = {}
function vim.api.nvim_create_user_command(name, handler, opts)
    recorded.commands[name] = { handler = handler, opts = opts }
end
function vim.api.nvim_exec_autocmds(event, opts)
    recorded.autocmds[#recorded.autocmds + 1] = { event = event, opts = opts }
end
function vim.api.nvim_create_buf(_, _)
    local id = #recorded.bufs + 1
    recorded.bufs[id] = { lines = {} }
    return id
end
function vim.api.nvim_buf_set_lines(buf, _, _, _, lines)
    recorded.bufs[buf].lines = lines
end
function vim.api.nvim_set_option_value(_, _, _)
end
function vim.api.nvim_win_set_buf(_, _)
end

vim.ui = {}
function vim.ui.select(items, opts, on_choice)
    recorded.selects[#recorded.selects + 1] = { items = items, opts = opts }
    if not recorded.select_works then
        error('ui.select broken', 0)
    end
    local choice = recorded.select_choice
    if choice == nil then
        choice = items[1]
    end
    on_choice(choice)
end

vim.base64 = { encode = b64_encode, decode = b64_decode }

function vim.cmd(_)
end

return vim
