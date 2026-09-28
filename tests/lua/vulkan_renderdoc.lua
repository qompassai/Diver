-- Tests for dap/renderdoc.lua Vulkan additions (:VulkanCapture) plus the
-- pre-existing capture helpers it builds on.
-- Run from the repo root:  lua tests/lua/vulkan_renderdoc.lua
-- Hermetic: vim.fn/vim.fs/vim.uv/vim.system are stubbed; argv construction
-- is verified, nothing is spawned.
-- Exactly 50% validation / 50% adversarial: 6 + 6.
local here = debug.getinfo(1, 'S').source:sub(2)
if here:sub(1, 1) ~= '/' then
    local pwd = io.popen('pwd')
    local cwd = pwd:read('*l')
    pwd:close()
    here = cwd .. '/' .. here
end
local dir = here:match('^(.*)/[^/]*$')
local root = dir:match('^(.*)/tests/lua$')
assert(root ~= nil, 'cannot locate repo root from ' .. dir)
package.path = root .. '/lua/?.lua;' .. root .. '/lua/?/init.lua;' .. package.path

local stub = {
    exec = { renderdoccmd = true, qrenderdoc = true, myapp = true },
    dir_entries = {},
    stat = {},
    system_argv = nil,
    notifications = {},
}

_G.vim = {
    fn = {
        executable = function(name)
            return stub.exec[name] == true and 1 or 0
        end,
        fnamemodify = function(path, mods)
            if mods == ':p' then
                return path
            end
            if mods == ':t' then
                return path:match('[^/]*$') or path
            end
            return path
        end,
        getcwd = function()
            return '/work'
        end,
        input = function()
            return ''
        end,
    },
    fs = {
        normalize = function(path)
            return path
        end,
        joinpath = function(...)
            return table.concat({ ... }, '/')
        end,
        dir = function(_path)
            local index = 0
            return function()
                index = index + 1
                local entry = stub.dir_entries[index]
                if entry == nil then
                    return nil
                end
                return entry.name, entry.kind
            end
        end,
    },
    uv = {
        fs_stat = function(path)
            return stub.stat[path]
        end,
    },
    log = { levels = { INFO = 1, WARN = 2, ERROR = 3 } },
    system = function(argv, _opts, _on_exit)
        stub.system_argv = argv
        return true
    end,
    notify = function(message, level)
        stub.notifications[#stub.notifications + 1] = { message = message, level = level }
    end,
    ui = {
        select = function(items, _opts, on_choice)
            on_choice(items[1])
        end,
    },
    schedule = function(fn)
        fn()
    end,
}

local renderdoc = require('dap.renderdoc')
assert(type(renderdoc.capture) == 'function', 'dap.renderdoc must load')

local passed = 0
local total = 0
local function check(value, message)
    total = total + 1
    assert(value, message)
    passed = passed + 1
end

local function reset()
    stub.dir_entries = {}
    stub.stat = {}
    stub.system_argv = nil
    stub.notifications = {}
end

-- ============================ validation (6) ============================

reset()
stub.dir_entries = {
    { name = 'a.rdc', kind = 'file' },
    { name = 'b.rdc', kind = 'file' },
    { name = 'notes.txt', kind = 'file' },
    { name = 'sub.rdc', kind = 'directory' },
}
stub.stat['/work'] = { type = 'directory' }
stub.stat['/work/a.rdc'] = { type = 'file', mtime = { sec = 100 } }
stub.stat['/work/b.rdc'] = { type = 'file', mtime = { sec = 200 } }
local captures = renderdoc.list_captures('/work')
check(
    #captures == 2 and captures[1] == '/work/b.rdc' and captures[2] == '/work/a.rdc',
    'V1: only .rdc files listed, newest first'
)

reset()
stub.dir_entries = {
    { name = 'zeta.rdc', kind = 'file' },
    { name = 'alpha.rdc', kind = 'file' },
}
stub.stat['/work'] = { type = 'directory' }
stub.stat['/work/zeta.rdc'] = { type = 'file', mtime = { sec = 50 } }
stub.stat['/work/alpha.rdc'] = { type = 'file', mtime = { sec = 50 } }
captures = renderdoc.list_captures('/work')
check(
    captures[1] == '/work/alpha.rdc' and captures[2] == '/work/zeta.rdc',
    'V2: mtime ties break on filename ascending (deterministic)'
)

local cmd = renderdoc.commands.VulkanCapture
check(
    type(cmd) == 'table' and cmd.nargs == '+' and cmd.desc:find('Vulkan') ~= nil,
    'V3: VulkanCapture command registered with nargs and Vulkan description'
)

reset()
cmd.callback({ fargs = { 'myapp', '--foo' } })
local argv = stub.system_argv
local api_validation_at, executable_at = nil, nil
if argv ~= nil then
    for i, token in ipairs(argv) do
        if token == '--opt-api-validation' then
            api_validation_at = i
        end
        if token == 'myapp' then
            executable_at = i
        end
    end
end
check(
    argv ~= nil
        and argv[1] == 'renderdoccmd'
        and argv[2] == 'capture'
        and api_validation_at ~= nil
        and executable_at ~= nil
        and api_validation_at < executable_at
        and argv[#argv] == '--foo',
    'V4: VulkanCapture passes --opt-api-validation before the executable, args verbatim'
)

check(renderdoc.is_available(), 'V5: renderdoccmd reported available when executable')

reset()
local ok, err = renderdoc.open_capture('/work/a.txt')
check(ok == false and err:find('%.rdc') ~= nil, 'V6: non-.rdc path rejected')

-- ============================ adversarial (6) ============================

reset()
local a1_ok, a1_err = renderdoc.capture({ executable = '' })
check(a1_ok == false and type(a1_err) == 'string', 'A1: empty executable rejected')

reset()
local a2_ok, a2_err = renderdoc.capture({ executable = 'a\0b' })
check(a2_ok == false and a2_err:find('NUL') ~= nil, 'A2: NUL byte in executable rejected')

reset()
local a3_ok, a3_err = renderdoc.capture({ executable = 'myapp', working_dir = '/nope' })
check(a3_ok == false and a3_err:find('does not exist') ~= nil, 'A3: nonexistent working_dir rejected')

reset()
local many_args = {}
for i = 1, 129 do
    many_args[i] = '--x'
end
local a4_ok, a4_err = renderdoc.capture({ executable = 'myapp', args = many_args })
check(a4_ok == false and a4_err:find('128') ~= nil, 'A4: 129 args rejected at the 128 bound')

reset()
local a5_ok, a5_err = renderdoc.open_capture('/work/missing.rdc')
check(a5_ok == false and a5_err:find('not found') ~= nil, 'A5: missing capture file rejected')

reset()
renderdoc.commands.VulkanCapture.callback({ fargs = {} })
check(
    #stub.notifications == 1 and stub.notifications[1].level == 3,
    'A6: VulkanCapture with no args notifies usage at ERROR level'
)

print(('vulkan_renderdoc: %d/%d passed (6 validation + 6 adversarial)'):format(passed, total))
assert(passed == total and total == 12, 'vulkan_renderdoc: failures present')
