-- Salesforce Code Analyzer basename-attribution test.
-- Run from the repo root: nvim --headless -u NONE -l tests/lua/salesforce_basename.lua
-- Two open buffers share a basename in different directories. A violation
-- whose location matches only by basename must be dropped for the wrong
-- buffer (never misattributed) and kept for the right one; once the
-- basename is unambiguous the fallback applies again. Also covers the
-- code_analyzer re-export carrying the factory's bug fixes. No plugins,
-- no network, no `sf` binary needed (the parser is exercised directly).
local api = vim.api
vim.opt.runtimepath:prepend(vim.fn.getcwd())

local passed = 0
local failures = {}
local function check(value, message)
    if value then
        passed = passed + 1
    else
        failures[#failures + 1] = message
    end
end

local factory = require('linters._salesforce-code-analyzer')
check(type(factory.new) == 'function', 'factory exposes new()')

local spec = factory.new({ name = 'test-salesforce', selector = 'flow:Recommended' })
check(type(spec.parser) == 'function', 'spec exposes parser()')

---@param file string|nil
---@return table
local function make_violation(file)
    return {
        engine = 'flow',
        rule = 'HardcodedId',
        severity = 3,
        message = 'hardcoded id',
        locations = {
            { file = file, startLine = 2, startColumn = 3 },
        },
    }
end

local function output_for(violations)
    return vim.json.encode({ violations = violations })
end

---@param bufnr integer
---@param filename string
---@return LintContext
local function context_for(bufnr, filename)
    return {
        bufnr = bufnr,
        cwd = '/tmp',
        filename = filename,
        filetype = 'apex',
        modified = false,
        root = '/tmp',
    }
end

-- Two loaded buffers, same basename, different directories.
local buf_a = api.nvim_create_buf(true, false)
api.nvim_buf_set_name(buf_a, '/tmp/sfa/dup.cls')
local buf_b = api.nvim_create_buf(true, false)
api.nvim_buf_set_name(buf_b, '/tmp/sfb/dup.cls')
check(api.nvim_buf_is_loaded(buf_a) and api.nvim_buf_is_loaded(buf_b), 'both same-basename buffers are loaded')

-- Exact absolute path: kept for the right buffer...
local diags_a = spec.parser(output_for({ make_violation('/tmp/sfa/dup.cls') }), context_for(buf_a, '/tmp/sfa/dup.cls'))
check(#diags_a == 1, 'exact path match is kept for buffer A')
---@type any -- bufnr is attached at runtime by the parser under test
local first_a = diags_a[1]
check(first_a ~= nil and first_a.bufnr == buf_a, 'diagnostic targets buffer A')

-- ...and dropped for the wrong buffer even though the basename matches.
local diags_b = spec.parser(output_for({ make_violation('/tmp/sfa/dup.cls') }), context_for(buf_b, '/tmp/sfb/dup.cls'))
check(#diags_b == 0, 'absolute path of another buffer is dropped while basenames collide')

-- Basename-only (relative) location while ambiguous: dropped, not guessed.
local diags_rel = spec.parser(output_for({ make_violation('dup.cls') }), context_for(buf_b, '/tmp/sfb/dup.cls'))
check(#diags_rel == 0, 'basename-only match is dropped while ambiguous')

-- Missing location info is still attributed to the linted buffer.
local diags_nofile = spec.parser(output_for({ make_violation(nil) }), context_for(buf_a, '/tmp/sfa/dup.cls'))
check(#diags_nofile == 1, 'missing location file is attributed to the buffer')

-- One buffer left: the basename fallback applies again (unambiguous).
api.nvim_buf_delete(buf_b, { force = true })
local diags_rel_a = spec.parser(output_for({ make_violation('sub/dup.cls') }), context_for(buf_a, '/tmp/sfa/dup.cls'))
check(#diags_rel_a == 1, 'basename-only match is kept once unambiguous')
---@type any -- bufnr is attached at runtime by the parser under test
local first_rel = diags_rel_a[1]
check(first_rel ~= nil and first_rel.bufnr == buf_a, 'fallback diagnostic targets buffer A')

-- code_analyzer re-export: same factory API, fixes carried over.
local code_analyzer = require('linters.code_analyzer')
check(type(code_analyzer.new) == 'function', 'code_analyzer still exposes new()')
local ca_spec = code_analyzer.new({ name = 'code-analyzer-test', selector = 'flow:Recommended' })
check(type(ca_spec) == 'table' and ca_spec.cmd == 'sf', 'code_analyzer delegates to the factory')
local diags_file = ca_spec.parser(output_for({ make_violation('file://') }), context_for(buf_a, '/tmp/sfa/dup.cls'))
check(#diags_file == 1, 'file:// location no longer throws via the re-export')

api.nvim_buf_delete(buf_a, { force = true })

if #failures > 0 then
    print(('FAIL: %d passed, %d failed'):format(passed, #failures))
    for _, message in ipairs(failures) do
        print('  - ' .. message)
    end
    vim.cmd('cquit 1')
else
    print(('PASS: %d checks'):format(passed))
end
