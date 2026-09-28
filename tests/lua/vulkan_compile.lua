-- Tests for dev.vulkan.compile -- finding parsing, tool mapping, diagnostics.
-- Run from the repo root:  lua tests/lua/vulkan_compile.lua
-- Hermetic: compiler output parsing and tool mapping are verified; nothing
-- is executed and no real buffer is touched.
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

_G.vim = {
    api = {
        nvim_create_namespace = function()
            return 1
        end,
    },
    diagnostic = {
        severity = { ERROR = 1, WARN = 2, INFO = 3, HINT = 4 },
    },
    fn = {
        executable = function(name)
            return name == 'glslangValidator' and 1 or 0
        end,
        exepath = function(name)
            return '/usr/bin/' .. name
        end,
    },
    fs = {
        normalize = function(path)
            return (path:gsub('//+', '/'))
        end,
        dirname = function(path)
            return path:match('^(.*)/[^/]*$') or '.'
        end,
        joinpath = function(...)
            return table.concat({ ... }, '/')
        end,
    },
    log = { levels = { INFO = 1, WARN = 2, ERROR = 3 } },
    system = function()
        return { code = 0, stdout = '1.0\n' }
    end,
    trim = function(s)
        return (s:gsub('^%s+', ''):gsub('%s+$', ''))
    end,
    notify = function() end,
}

local compile = require('dev.vulkan.compile')
assert(type(compile.parse_findings) == 'function', 'dev.vulkan.compile must load')

local passed = 0
local total = 0
local function check(value, message)
    total = total + 1
    assert(value, message)
    passed = passed + 1
end

-- ============================ validation (6) ============================

local findings = compile.parse_findings("shader.vert:5:3: error: undeclared identifier 'x'\n")
check(
    #findings == 1
        and findings[1].line == 5
        and findings[1].col == 3
        and findings[1].severity == 'error'
        and findings[1].message == "undeclared identifier 'x'",
    'V1: error finding parsed with line, column, severity, message'
)

findings = compile.parse_findings('a.frag:2:1: warning: implicit conversion\n')
check(#findings == 1 and findings[1].severity == 'warning', 'V2: warning severity parsed')

findings = compile.parse_findings('\n   \nnot a diagnostic\n')
check(#findings == 0, 'V3: blank and garbage lines ignored')

check(
    compile.tool_for_ext('.hlsl') == 'dxc'
        and compile.tool_for_ext('.slang') == 'slangc'
        and compile.tool_for_ext('.frag') == 'glslangValidator',
    'V4: extensions map to their compilers'
)

local diags = compile.to_diagnostics({
    { file = '/work/s.vert', line = 5, col = 3, severity = 'error', message = 'boom' },
}, 7, '/work/s.vert')
check(
    #diags == 1 and diags[1].lnum == 4 and diags[1].col == 2 and diags[1].bufnr == 7 and diags[1].severity == 1,
    'V5: 1-based finding becomes a 0-based ERROR diagnostic for the buffer'
)

local covered = { vert = false, frag = false, comp = false, glsl = false, hlsl = false, slang = false }
for _, pattern in ipairs(compile.shader_patterns()) do
    local ext = pattern:match('^%*%.(.+)$')
    if ext ~= nil and covered[ext] ~= nil then
        covered[ext] = true
    end
end
local all_covered = true
for _, ok in pairs(covered) do
    all_covered = all_covered and ok
end
check(all_covered, 'V6: save patterns cover .vert/.frag/.comp/.glsl/.hlsl/.slang')

-- ============================ adversarial (6) ============================

check(#compile.parse_findings('') == 0 and #compile.parse_findings(nil) == 0, 'A1: empty/nil output yields no findings')

local many_lines = {}
for i = 1, 600 do
    many_lines[#many_lines + 1] = ('s.vert:%d:1: error: e%d'):format(i, i)
end
check(#compile.parse_findings(table.concat(many_lines, '\n')) == 512, 'A2: findings capped at 512')

local long_findings = compile.parse_findings('s.vert:1:1: error: ' .. string.rep('x', 3000))
check(#long_findings == 1 and #long_findings[1].message == 2048, 'A3: message truncated to 2048 bytes')

check(
    compile.tool_for_ext('.txt') == nil and compile.tool_for_ext('') == nil and compile.tool_for_ext(nil) == nil,
    'A4: unknown/empty/nil extensions map to no compiler'
)

diags = compile.to_diagnostics({
    { file = '/work/other.vert', line = 9, col = 2, severity = 'warning', message = 'elsewhere' },
}, 7, '/work/s.vert')
check(
    diags[1].lnum == 0 and diags[1].message == '/work/other.vert: elsewhere',
    'A5: cross-file finding pinned to line 1 and prefixed with its file'
)

findings = compile.parse_findings('s.vert:1:1: error: bad\0line\ns.vert:2:1: warning: ok\n')
check(#findings == 1 and findings[1].line == 2, 'A6: NUL-containing line skipped, clean line kept')

print(('vulkan_compile: %d/%d passed (6 validation + 6 adversarial)'):format(passed, total))
assert(passed == total and total == 12, 'vulkan_compile: failures present')
