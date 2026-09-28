-- Tests for dev.vulkan.prompts -- Vulkan-aware Rose prompt templates.
-- Run from the repo root:  lua tests/lua/vulkan_prompts.lua
-- Pure Lua: no vim stub needed (the module has no vim.* calls by design).
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

local prompts = require('dev.vulkan.prompts')
assert(type(prompts.build) == 'function', 'dev.vulkan.prompts must load')

local passed = 0
local total = 0
local function check(value, message)
    total = total + 1
    assert(value, message)
    passed = passed + 1
end

-- ============================ validation (6) ============================

local prompt = prompts.build('shader_review', { source_text = 'void main() {}', file = 'a.vert' })
check(
    type(prompt) == 'string' and prompt:find('void main() {}', 1, true) ~= nil and prompt:find('Vulkan', 1, true) ~= nil,
    'V1: shader_review embeds the shader source with Vulkan context'
)

prompt = prompts.build('validation_error', { error_text = 'VUID-vkCmdDraw-foo' })
check(
    prompt:find('VUID-vkCmdDraw-foo', 1, true) ~= nil and prompt:find('Do not invent VUID', 1, true) ~= nil,
    'V2: validation_error embeds the error and carries the honesty instruction'
)

prompt = prompts.build('pipeline_debug', { pipeline_desc = 'black screen' })
check(
    prompt:find('black screen', 1, true) ~= nil and prompt:find('escriptor', 1, true) ~= nil,
    'V3: pipeline_debug embeds the description with a descriptor checklist'
)

local names = prompts.names()
check(#names == 3 and names[1] == 'pipeline_debug' and names[3] == 'validation_error', 'V4: three templates, sorted')

check(prompts.describe('shader_review'):find('Shader review') ~= nil, 'V5: describe returns the template title')

-- A shader containing '%' must not break rendering (concatenation, not format).
prompt = prompts.build('shader_review', { source_text = 'float x = 100%3; // %s %d %%' })
check(prompt:find('100%3', 1, true) ~= nil, 'V6: percent signs pass through unmodified')

-- ============================ adversarial (6) ============================

local bad, bad_err = prompts.build('not_a_template', {})
check(bad == nil and bad_err:find('unknown prompt template') ~= nil, 'A1: unknown template name rejected')

bad, bad_err = prompts.build(nil, {})
check(bad == nil and type(bad_err) == 'string', 'A2: nil template name rejected')

prompt = prompts.build('shader_review', nil)
check(
    type(prompt) == 'string' and prompt:find('(none provided)', 1, true) ~= nil,
    'A3: nil context yields a usable prompt with a placeholder'
)

check(type(prompts.build('shader_review', 'not a table')) == 'string', 'A4: non-table context coerced, never crashes')

local huge = string.rep('x', 64 * 1024)
prompt = prompts.build('validation_error', { error_text = huge })
check(#prompt < 64 * 1024 and prompt:find('truncated', 1, true) ~= nil, 'A5: oversized context truncated with a marker')

bad, bad_err = prompts.describe('nope')
check(bad == nil and type(bad_err) == 'string', 'A6: describe of an unknown name rejected')

print(('vulkan_prompts: %d/%d passed (6 validation + 6 adversarial)'):format(passed, total))
assert(passed == total and total == 12, 'vulkan_prompts: failures present')
