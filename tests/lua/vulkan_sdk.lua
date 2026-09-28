-- Tests for dev.vulkan.sdk -- SDK detection, vulkaninfo parsing, layers.
-- Run from the repo root:  lua tests/lua/vulkan_sdk.lua
-- Harness follows tests/lua/research_docs_make_header.lua (plain-lua `check`
-- counting, minimal vim stub; hermetic -- vim.system/vim.uv are stubbed,
-- no real tools are required).
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

-- Mutable stub state: tests reconfigure per case.
local stub = {
    env = { HOME = '/home/test', VULKAN_SDK = '', VK_LAYER_PATH = '' },
    exec = {},
    stat_dirs = {},
    system_impl = nil,
}

_G.vim = {
    env = stub.env,
    fn = {
        executable = function(name)
            return stub.exec[name] == true and 1 or 0
        end,
        exepath = function(name)
            return stub.exec[name] == true and ('/usr/bin/' .. name) or ''
        end,
    },
    fs = {
        normalize = function(path)
            return (path:gsub('//+', '/'))
        end,
        joinpath = function(...)
            return table.concat({ ... }, '/')
        end,
    },
    uv = {
        fs_stat = function(path)
            if stub.stat_dirs[path] then
                return { type = 'directory' }
            end
            return nil
        end,
    },
    system = function(argv, opts, on_exit)
        assert(type(stub.system_impl) == 'function', 'system stub not configured')
        return stub.system_impl(argv, opts, on_exit)
    end,
    trim = function(s)
        return (s:gsub('^%s+', ''):gsub('%s+$', ''))
    end,
}

local sdk = require('dev.vulkan.sdk')
assert(type(sdk.status) == 'function', 'dev.vulkan.sdk must load')

local passed = 0
local total = 0
local function check(value, message)
    total = total + 1
    assert(value, message)
    passed = passed + 1
end

local function reset()
    stub.env.VULKAN_SDK = ''
    stub.env.VK_LAYER_PATH = ''
    stub.exec = {}
    stub.stat_dirs = {}
    stub.system_impl = nil
end

local SAMPLE_SUMMARY = table.concat({
    '==========',
    'VULKANINFO',
    '==========',
    '',
    'Vulkan Instance Version: 1.4.357',
    '',
    '',
    'Instance Extensions: count = 2',
    '-------------------------------',
    'VK_KHR_surface                         : extension revision 25',
    '',
    'Instance Layers: count = 3',
    '---------------------------',
    'VK_LAYER_KHRONOS_validation      Validation layer          1.3.0    version 1',
    'VK_LAYER_LUNARG_monitor          Execution monitor         1.3.0    version 1',
    'VK_LAYER_AEJS_DeviceChooserLayer Device chooser layer      1.3.0    version 1',
    '',
    'Devices:',
    '========',
}, '\n')

-- ============================ validation (6) ============================

reset()
stub.env.VULKAN_SDK = '/opt/sdk/1.4.357'
stub.stat_dirs['/opt/sdk/1.4.357'] = true
check(sdk.sdk_root() == '/opt/sdk/1.4.357', 'V1: VULKAN_SDK wins when it names a directory')

reset()
stub.stat_dirs['/usr/share/vulkan'] = true
check(sdk.sdk_root() == '/usr/share/vulkan', 'V2: falls back to a well-known path when VULKAN_SDK is empty')

reset()
check(sdk.parse_instance_version(SAMPLE_SUMMARY) == '1.4.357', 'V3: parses the Vulkan instance version')

reset()
local layers = sdk.parse_layers(SAMPLE_SUMMARY)
check(
    #layers == 3 and layers[1] == 'VK_LAYER_KHRONOS_validation' and sdk.validation_layer_available(layers),
    'V4: parses 3 instance layers and detects the validation layer'
)

reset()
stub.exec['vulkaninfo'] = true
stub.exec['vkconfig'] = true
check(sdk.vulkaninfo_available() and sdk.vkconfig_available(), 'V5: present binaries reported present')

reset()
stub.env.VK_LAYER_PATH = '/opt/layers:/home/test/implicit_layer.d'
local dirs = sdk.vk_layer_path_dirs()
check(#dirs == 2 and dirs[1] == '/opt/layers', 'V6: VK_LAYER_PATH split into directories')

-- ============================ adversarial (6) ============================

reset()
stub.env.VULKAN_SDK = '/opt/sdk/stale'
check(sdk.sdk_root() == nil, 'A1: stale VULKAN_SDK with no fallback yields nil root')

reset()
check(sdk.parse_instance_version('total garbage\nno version here') == nil, 'A2: garbage yields nil version')

reset()
check(#sdk.parse_layers('no sections at all') == 0, 'A3: missing layer section yields no layers')

reset()
stub.exec['vulkaninfo'] = true
stub.system_impl = function()
    error('boom')
end
local ver, ver_err = sdk.instance_version()
check(ver == nil and type(ver_err) == 'string', 'A4: system failure returns nil + error, not a crash')

reset()
stub.env.VULKAN_SDK = '/opt/sdk\0evil'
stub.stat_dirs['/usr/share/vulkan'] = true
check(sdk.sdk_root() == '/usr/share/vulkan', 'A5: NUL byte in VULKAN_SDK is rejected, fallback used')

reset()
local many = { 'Instance Layers: count = 300', '---------------------------' }
for i = 1, 300 do
    many[#many + 1] = ('VK_LAYER_FAKE_%04d  fake  1.0.0  version 1'):format(i)
end
check(#sdk.parse_layers(table.concat(many, '\n')) == 256, 'A6: layer parsing capped at 256')

print(('vulkan_sdk: %d/%d passed (6 validation + 6 adversarial)'):format(passed, total))
assert(passed == total and total == 12, 'vulkan_sdk: failures present')
