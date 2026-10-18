-- /qompassai/diver/tests/security/ghidra.lua
-- Qompass AI Diver Ghidra headless-analysis tests
-- Run from the config root:
--   nvim --headless -u NONE -i NONE -l tests/security/ghidra.lua
--
-- Covers security.ghidra: the status probe's shape, input validation,
-- project-name sanitization, command registration, the security
-- audit wiring, and the ai.harness ghidra_analyze tool registration.
-- Validation half here; tests/security/
-- ghidra_adversarial.lua carries the adversarial half (fake Ghidra).
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

local scratch = fn.tempname()
fn.mkdir(scratch, 'p')

local ok, ghidra = pcall(require, 'security.ghidra')
check(ok and ghidra ~= nil, 'require(security.ghidra) loads')
if not ok then
    print(('ghidra: %d checks, %d failures'):format(count, failures))
    os.exit(1)
end

ghidra.setup({ scratch_root = scratch })

-- Status probe: structured in both worlds (installed or not).
local status = ghidra.status()
check(type(status) == 'table', 'status() returns a table')
check(type(status.available) == 'boolean', 'status().available is a boolean')
check(status.scratch_root == scratch, 'status() reports the configured scratch root')
check(type(status.fidb_count) == 'number', 'status().fidb_count is a number')
check(type(status.bridge) == 'table' and type(status.bridge.present) == 'boolean', 'bridge status is structured')
check(type(status.bridge.plugin_present) == 'boolean', 'bridge plugin status is structured')
check(status.bridge.server_url == 'http://127.0.0.1:8089/', 'bridge URL is the plugin default')
ghidra.setup({ bridge_command = scratch .. '/no-bridge-here' })
check(ghidra.status().bridge.present == false, 'bridge override to a missing path reports absent')
ghidra.setup({ bridge_command = bundle .. '/tests/fixtures/ghidra/support/analyzeHeadless' })
check(ghidra.status().bridge.present == true, 'bridge override to an executable reports present')
if status.available then
    check(type(status.analyze_headless) == 'string', 'available status names analyzeHeadless')
    print('NOTE: Ghidra is installed here; unavailable-path checks skipped')
else
    check(type(status.error) == 'string' and status.error ~= '', 'unavailable status carries a reason')
    -- A valid binary still fails cleanly when Ghidra is absent.
    local victim = scratch .. '/victim.bin'
    fn.writefile({ 'MZ' }, victim, 'b')
    local result, err = ghidra.analyze(victim)
    check(result == nil and err ~= nil and err:find('not found') ~= nil, 'analyze() reports unavailable, never crashes')
end

-- Input validation: every bad shape is a (nil, err), never a throw.
---@type any
local not_a_path = nil
local _, err_nil = ghidra.analyze(not_a_path)
check(err_nil ~= nil, 'analyze(nil) rejected')
local _, err_empty = ghidra.analyze('')
check(err_empty ~= nil, 'analyze(empty string) rejected')
local _, err_missing = ghidra.analyze(scratch .. '/does-not-exist.bin')
check(err_missing ~= nil, 'analyze(missing file) rejected')
local _, err_dir = ghidra.analyze(scratch)
check(err_dir ~= nil and err_dir:find('directory') ~= nil, 'analyze(directory) rejected')
local _, err_ctrl = ghidra.analyze(scratch .. '/bad\nname.bin')
check(err_ctrl ~= nil, 'analyze(path with newline) rejected')
local _, err_timeout = ghidra.analyze(scratch .. '/does-not-exist.bin', { timeout_ms = 5 })
check(err_timeout ~= nil, 'analyze(timeout below minimum) rejected')

-- Project naming: deterministic, distinguishing, and traversal-proof.
local name_a = ghidra.project_name_for('/tmp/one/prog')
local name_b = ghidra.project_name_for('/tmp/one/prog')
local name_c = ghidra.project_name_for('/tmp/two/prog')
check(name_a == name_b, 'project_name_for is deterministic')
check(name_a ~= name_c, 'same basename in different dirs gets different projects')
check(name_a:find('/') == nil and name_a:find('%.%.') == nil, 'project name has no separators or dotdots')
local dir = ghidra.scratch_dir_for('/tmp/../../etc/passwd')
check(dir:sub(1, #scratch + 1) == scratch .. '/', 'scratch_dir_for stays under the scratch root')

-- Commands exist after setup().
check(fn.exists(':GhidraStatus') == 2, ':GhidraStatus registered')
check(fn.exists(':GhidraAnalyze') == 2, ':GhidraAnalyze registered')

-- Security wiring: the toolkit exposes the module and the audit sees it.
local security = require('security')
check(security.ghidra == ghidra, 'security.ghidra is wired into the toolkit')
local report = security.audit()
local ghidra_check = nil
for _, entry in ipairs(report.checks) do
    if entry.name == 'ghidra' then
        ghidra_check = entry
    end
end
check(ghidra_check ~= nil, 'security.audit() includes a ghidra check')
if ghidra_check ~= nil then
    check(
        ghidra_check.status == 'pass' or ghidra_check.status == 'skip',
        'audit ghidra check is pass-or-skip, never fail for an optional tool'
    )
end

-- Harness tool registration: with ai.harness set up, the security audit's
-- registration attempt lands exactly one tool from the security side,
-- and dispatch under the harness's default (deny) policy refuses
-- without ever invoking the tool.
local harness_ok, harness = pcall(require, 'ai.harness')
check(harness_ok and harness ~= nil, 'require(ai.harness) loads')
if harness_ok then
    local setup_ok, setup_err = harness.setup()
    check(setup_ok == true, 'ai.harness setup succeeds: ' .. tostring(setup_err))
    local report2 = security.audit()
    local tool_check = nil
    for _, entry in ipairs(report2.checks) do
        if entry.name == 'ghidra_tool' then
            tool_check = entry
        end
    end
    check(tool_check ~= nil, 'security.audit() includes a ghidra_tool check')
    if tool_check ~= nil then
        check(tool_check.status == 'pass', 'audit ghidra_tool check passes once the harness is up')
    end
    local names = harness.list_tools()
    check(
        type(names) == 'table' and #names == 1 and names[1] == 'ghidra_analyze',
        'harness registry lists exactly ghidra_analyze from the security side'
    )
    local result, dispatch_err = harness.dispatch_tool('ghidra_analyze', { path = '/usr/bin/true' })
    check(
        result == nil and dispatch_err ~= nil and dispatch_err:find('denied by policy') ~= nil,
        'dispatch under the default policy denies and never invokes the tool'
    )
end

fn.delete(scratch, 'rf')
print(('ghidra: %d checks, %d failures'):format(count, failures))
os.exit(failures == 0 and 0 or 1)
