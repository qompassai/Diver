-- Tests for dev.vulkan.toolchain -- compiler probing and argv building.
-- Run from the repo root:  lua tests/lua/vulkan_toolchain.lua
-- Hermetic: vim.fn/vim.system are stubbed; flags are verified, never executed.
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
    exec = {},
    system_argv = nil,
    system_result = { code = 0, stdout = '1.9(1-0d3ee6b5)(1.9.0.1)\n' },
}

_G.vim = {
    fn = {
        executable = function(name)
            return stub.exec[name] == true and 1 or 0
        end,
        exepath = function(name)
            return stub.exec[name] == true and ('/usr/bin/' .. name) or ''
        end,
    },
    system = function(argv, opts, on_exit)
        stub.system_argv = argv
        return stub.system_result
    end,
    trim = function(s)
        return (s:gsub('^%s+', ''):gsub('%s+$', ''))
    end,
}

local toolchain = require('dev.vulkan.toolchain')
assert(type(toolchain.probe) == 'function', 'dev.vulkan.toolchain must load')

local passed = 0
local total = 0
local function check(value, message)
    total = total + 1
    assert(value, message)
    passed = passed + 1
end

local function argv_equal(a, b)
    if type(a) ~= 'table' or #a ~= #b then
        return false
    end
    for i = 1, #a do
        if a[i] ~= b[i] then
            return false
        end
    end
    return true
end

-- ============================ validation (6) ============================

stub.exec['dxc'] = true
local probe = toolchain.probe('dxc')
check(
    probe ~= nil and probe.found == true and probe.version == '1.9(1-0d3ee6b5)(1.9.0.1)',
    'V1: dxc reported found with parsed version'
)

stub.system_argv = nil
stub.exec['slangc'] = true
probe = toolchain.probe('slangc')
check(
    probe.found == true and stub.system_argv ~= nil and stub.system_argv[2] == '-v',
    'V2: slangc probed with -v (not --version)'
)

local vert, comp, rgen =
    toolchain.stage_for_ext('.vert'), toolchain.stage_for_ext('.comp'), toolchain.stage_for_ext('.rgen')
check(vert == 'vert' and comp == 'comp' and rgen == 'rgen', 'V3: extensions map to pipeline stages')

check(
    argv_equal(
        toolchain.build_argv('glslangValidator', {
            stage = 'frag',
            source = 'a.frag',
            output = 'a.frag.spv',
        }),
        {
            'glslangValidator',
            '-V',
            '-S',
            'frag',
            '--target-env',
            'vulkan1.3',
            '-o',
            'a.frag.spv',
            'a.frag',
        }
    ),
    'V4: glslangValidator argv exact'
)

check(
    argv_equal(
        toolchain.build_argv('dxc', {
            profile = 'vs_6_8',
            entry = 'main',
            source = 'a.hlsl',
            output = 'a.spv',
        }),
        {
            'dxc',
            '-spirv',
            '-T',
            'vs_6_8',
            '-E',
            'main',
            '-Fo',
            'a.spv',
            'a.hlsl',
        }
    ),
    'V5: dxc argv exact (SPIR-V backend, profile, entry)'
)

check(
    argv_equal(
        toolchain.build_argv('slangc', {
            stage = 'compute',
            entry = 'computeMain',
            source = 'a.slang',
            output = 'a.spv',
        }),
        {
            'slangc',
            '-target',
            'spirv',
            '-stage',
            'compute',
            '-entry',
            'computeMain',
            '-o',
            'a.spv',
            'a.slang',
        }
    ),
    'V6: slangc argv exact'
)

-- ============================ adversarial (6) ============================

local bad, bad_err = toolchain.probe('not_a_tool')
check(bad == nil and type(bad_err) == 'string', 'A1: unknown tool returns nil + error')

local amb, amb_err = toolchain.stage_for_ext('.glsl')
check(amb == nil and amb_err:find('ambiguous') ~= nil, 'A2: bare .glsl is ambiguous, not guessed')

local no_source = toolchain.build_argv('glslc', { stage = 'vert', output = 'o.spv' })
check(no_source == nil, 'A3: missing source rejected')

local no_profile = toolchain.build_argv('dxc', { source = 'a.hlsl', output = 'a.spv' })
check(no_profile == nil, 'A4: dxc without a profile is rejected')

check(toolchain.build_argv('fxc', { source = 'a', output = 'b' }) == nil, 'A5: unknown tool argv rejected')

stub.exec['glslc'] = true
stub.system_result = { code = 1, stdout = '' }
probe = toolchain.probe('glslc')
stub.system_result = { code = 0, stdout = '1.9(1-0d3ee6b5)(1.9.0.1)\n' }
check(probe.found == true and probe.version == nil, 'A6: failing version flag reports version=nil honestly')

print(('vulkan_toolchain: %d/%d passed (6 validation + 6 adversarial)'):format(passed, total))
assert(passed == total and total == 12, 'vulkan_toolchain: failures present')
