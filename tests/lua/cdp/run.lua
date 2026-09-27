-- tests/lua/cdp/run.lua
-- Plain-Lua 5.4 test runner for the CDP client. No Neovim needed:
-- installs the vim stub, then runs every suite and reports.
--
-- Run from the repo root:
--   ~/workspace/tools/lua-5.4.8/src/lua tests/lua/cdp/run.lua
---@module 'tests.cdp.run'

local src = debug.getinfo(1, 'S').source:sub(2)
local root = src:gsub('/?tests/lua/cdp/run%.lua$', '')
if root == '' then
    root = '.'
end

package.path = root .. '/lua/?.lua;'
    .. root .. '/lua/?/init.lua;'
    .. root .. '/tests/lua/?.lua;'
    .. root .. '/tests/lua/?/init.lua;'
    .. package.path

-- The stub must be global before any CDP module resolves vim lazily.
_G.vim = require('cdp.vim_stub')

local suites = {
    'cdp.test_session',
    'cdp.test_domains',
    'cdp.test_security',
    'cdp.test_init',
    'cdp.test_actions',
    'cdp.test_commands',
}

local total, passed = 0, 0
local val_total, val_passed, adv_total, adv_passed = 0, 0, 0, 0
local failures = {}

for _, suite_name in ipairs(suites) do
    local suite = require(suite_name)
    for _, test in ipairs(suite.tests) do
        total = total + 1
        if test.kind == 'A' then
            adv_total = adv_total + 1
        else
            val_total = val_total + 1
        end
        -- Reset shared stub state between tests.
        vim._recorded.notifies = {}
        vim._recorded.autocmds = {}
        vim._recorded.selects = {}
        vim._recorded.select_choice = nil
        vim._recorded.select_works = true
        vim.uv._now = 1000000
        local ok, err = pcall(test.fn)
        if ok then
            passed = passed + 1
            if test.kind == 'A' then
                adv_passed = adv_passed + 1
            else
                val_passed = val_passed + 1
            end
            print(string.format('ok   [%s] %s: %s', test.kind, suite_name, test.name))
        else
            failures[#failures + 1] = { suite = suite_name, name = test.name, err = err }
            print(string.format('FAIL [%s] %s: %s', test.kind, suite_name, test.name))
            print('      ' .. tostring(err))
        end
    end
end

print('---')
print(string.format('validation:  %d/%d passed', val_passed, val_total))
print(string.format('adversarial: %d/%d passed', adv_passed, adv_total))
print(string.format('total:       %d/%d passed', passed, total))

if #failures > 0 then
    os.exit(1)
end
