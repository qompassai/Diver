-- /qompassai/diver/tests/security/ghidra_adversarial.lua
-- Qompass AI Diver Ghidra headless-analysis adversarial tests
-- Run from the config root:
--   nvim --headless -u NONE -i NONE -l tests/security/ghidra_adversarial.lua
--
-- Adversarial half for security.ghidra, driven end-to-end through a fake
-- analyzeHeadless (tests/fixtures/ghidra). Attack surface under test:
-- shell-metacharacter and space-bearing binary paths (must arrive as ONE
-- argv element and never execute), project-path traversal, unbounded
-- analyzer output (row caps, oversized-row skip), analyzer failure, and
-- the run timeout.
local fn = vim.fn
local bundle = fn.getcwd()
vim.opt.runtimepath:prepend(bundle)

local failures = 0
local count = 0
local function check(value, label)
    count = count + 1
    if value then
        print('PASS: ' .. label)
    else
        print('FAIL: ' .. label)
        failures = failures + 1
    end
end

local ok, ghidra = pcall(require, 'security.ghidra')
check(ok and ghidra ~= nil, 'require(security.ghidra) loads')
if not ok then
    print(('ghidra_adversarial: %d checks, %d failures'):format(count, failures))
    os.exit(1)
end

local work = fn.tempname()
fn.mkdir(work, 'p')
local scratch = work .. '/scratch'
local fixture_home = bundle .. '/tests/fixtures/ghidra'
ghidra.setup({ ghidra_home = fixture_home, scratch_root = scratch })

-- The fake install resolves through the setup seam, version included.
local status = ghidra.status()
check(status.available == true, 'fake Ghidra resolves as available')
check(status.version == 'FAKE-1.0', 'version read from the install metadata')
check(status.fidb_count == 0, 'fake install reports zero function-id datasets')

---@param mode string
---@param path string
---@param opts? table
---@return table|nil result
---@return string|nil err
local function analyze_as(mode, path, opts)
    vim.env.FAKE_GHIDRA_MODE = mode
    local result, err = ghidra.analyze(path, opts)
    vim.env.FAKE_GHIDRA_MODE = nil
    return result, err
end

---@param dir string
---@param name string
---@return string path
local function make_binary(dir, name)
    fn.mkdir(dir, 'p')
    local path = dir .. '/' .. name
    fn.writefile({ 'MZ', 'fake' }, path, 'b')
    return path
end

---@param export_dir string
---@return string[] lines
local function read_argv(export_dir)
    return fn.readfile(export_dir .. '/argv.txt')
end

---@param lines string[]
---@param wanted string
---@return boolean found True when wanted is exactly one whole line.
local function has_line(lines, wanted)
    for _, line in ipairs(lines) do
        if line == wanted then
            return true
        end
    end
    return false
end

-- Happy path through the fake, with a space in the binary's file name:
-- the path must survive to the child as exactly one argv element.
local spaced = make_binary(work .. '/bins', 'my binary.bin')
local result, err = analyze_as('normal', spaced)
check(result ~= nil, 'normal analysis succeeds (err: ' .. tostring(err) .. ')')
if result ~= nil then
    check(result.function_count == 3, 'three functions parsed')
    check(result.functions[1].name == 'main', 'first function is main')
    check(result.string_count == 2, 'two strings parsed')
    check(result.decompile_bytes > 0 and result.decompile_preview:find('main') ~= nil, 'decompile preview present')
    check(has_line(read_argv(result.export_dir), spaced), 'spaced path arrived as one argv element')
    check(result.project_dir:sub(1, #scratch) == scratch, 'project stayed under the scratch root')
end

-- Shell metacharacters in a file name are data, not syntax: nothing may
-- execute, and the name must arrive whole as one argv element.
local evil_name = 'evil;$(touch pwned).bin'
local evil = make_binary(work .. '/bins', evil_name)
local evil_result, evil_err = analyze_as('normal', evil)
check(evil_result ~= nil, 'metachar-named binary analyzes (err: ' .. tostring(evil_err) .. ')')
check(fn.filereadable(work .. '/pwned') == 0 and fn.filereadable('pwned') == 0, 'no injected command executed')
if evil_result ~= nil then
    check(has_line(read_argv(evil_result.export_dir), evil), 'metachar path arrived as one argv element')
end

-- Traversal: a hostile path cannot move the project out of scratch.
local traversal_dir = ghidra.scratch_dir_for(work .. '/../../../../etc/cron.d/x')
check(traversal_dir:sub(1, #scratch + 1) == scratch .. '/', 'traversal input cannot escape the scratch root')

-- Flood: analyzer output is capped, and the cap is reported, not silent.
local flood_result, flood_err = analyze_as('flood', spaced)
check(flood_result ~= nil, 'flood analysis succeeds (err: ' .. tostring(flood_err) .. ')')
if flood_result ~= nil then
    check(
        flood_result.function_count == 5000,
        'function list capped at 5000 (got ' .. flood_result.function_count .. ')'
    )
    check(flood_result.functions_truncated == true, 'truncation is reported')
end

-- Oversized row: skipped by the line cap; the well-formed rows survive.
local long_result, long_err = analyze_as('longline', spaced)
check(long_result ~= nil, 'longline analysis succeeds (err: ' .. tostring(long_err) .. ')')
if long_result ~= nil then
    check(long_result.function_count == 2, 'oversized row skipped, two rows parsed')
end

-- Analyzer failure: non-zero exit surfaces as a structured error.
local fail_result, fail_err = analyze_as('fail', spaced)
check(
    fail_result == nil and fail_err ~= nil and fail_err:find('code 3') ~= nil,
    'analyzer failure is a structured error'
)

-- Timeout: a hung analyzer is killed and reported, bounded by the caller.
local slow_result, slow_err = analyze_as('sleep', spaced, { timeout_ms = 1000 })
check(slow_result == nil and slow_err ~= nil and slow_err:find('timed out') ~= nil, 'hung analyzer times out bounded')

fn.delete(work, 'rf')
print(('ghidra_adversarial: %d checks, %d failures'):format(count, failures))
os.exit(failures == 0 and 0 or 1)
