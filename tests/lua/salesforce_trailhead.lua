-- Salesforce Trailhead async agent jobs test.
-- Run from the repo root:
--   XDG_DATA_HOME=/tmp/th-test-data nvim --headless -u NONE -l tests/lua/salesforce_trailhead.lua
-- Covers validation (enqueue/start/progress/log/resume/persist, :Sf stub,
-- sfdx-project.json activation) and adversarial cases (bad input, bounds,
-- stale callbacks, malformed state). No network; shell steps use real
-- argv-form binaries resolved from PATH (skipped when absent).
vim.opt.runtimepath:prepend(vim.fn.getcwd())
package.path = vim.fn.getcwd() .. '/lua/?.lua;' .. vim.fn.getcwd() .. '/lua/?/init.lua;' .. package.path

local passed = 0
local failed = 0
local skipped = 0
local validation_passed = 0
local validation_failed = 0
local adversarial_passed = 0
local adversarial_failed = 0
local failures = {}
local function check(value, message, adversarial)
    if value then
        passed = passed + 1
        if adversarial then
            adversarial_passed = adversarial_passed + 1
        else
            validation_passed = validation_passed + 1
        end
    else
        failed = failed + 1
        if adversarial then
            adversarial_failed = adversarial_failed + 1
        else
            validation_failed = validation_failed + 1
        end
        failures[#failures + 1] = message
    end
end
---Adversarial half of the suite: bad input, bounds, stale state, hostile
---callbacks. Tracked separately from the validation half.
local function acheck(value, message)
    check(value, message, true)
end
---Setup precondition: verifies scaffolding an adversarial case needs
---(enqueue/start/cancel working). The behavior itself is covered by
---dedicated validation tests, so preconditions fail the suite without
---inflating the validation tally.
---@param value any
---@param message string
---@return boolean
local function precond(value, message)
    if value then
        return true
    end
    failed = failed + 1
    failures[#failures + 1] = 'PRECOND: ' .. message
    return false
end
local function skip(message)
    skipped = skipped + 1
    print('  SKIP: ' .. message)
end

local function has_bin(name)
    return vim.fn.exepath(name) ~= ''
end

-- ---- module loads -------------------------------------------------------
local ok, trailhead = pcall(require, 'dev.sf.trailhead')
check(ok and type(trailhead) == 'table', 'dev.sf.trailhead loads')
check(type(trailhead.commands) == 'table' and #trailhead.commands == 12, 'exposes 12 commands')

-- ---- adversarial: enqueue validation ------------------------------------
-- Deliberate contract violations go through an untyped alias so the suite
-- can pass hostile values without weakening the module's annotations.
do
    ---@type any
    local any_trailhead = trailhead
    local id_bad, err_bad = any_trailhead.enqueue(nil)
    acheck(id_bad == nil and type(err_bad) == 'string', 'enqueue(nil) rejected')
end
local id_bad2 = trailhead.enqueue({ kind = 'nope', title = 'x' })
acheck(id_bad2 == nil, 'enqueue with bad kind rejected')
local id_bad3 = trailhead.enqueue({ kind = 'study', title = '' })
acheck(id_bad3 == nil, 'enqueue with empty title rejected')

-- ---- validation: enqueue + steps ----------------------------------------
local job_id, err = trailhead.enqueue({ kind = 'study', title = 'Admin trailmix' })
check(type(job_id) == 'string' and err == nil, 'enqueue returns id')
-- Scaffolding ids are asserted non-nil past this point: a nil id would only
-- cascade noise, and the assert narrows the type for strict LuaLS.
assert(job_id ~= nil, 'scaffolding: enqueue must return an id')
local long_title = string.rep('t', 300)
local long_id = trailhead.enqueue({ kind = 'note', title = long_title })
assert(long_id ~= nil, 'scaffolding: long-title enqueue must return an id')
local long_job = trailhead.get(long_id)
check(long_job and #long_job.title == 200, 'title truncated to TITLE_BYTES_MAX')

local ok_step = trailhead.add_step(job_id, { name = 'Read module 1', note = 'first' })
check(ok_step, 'note step added')
local ok_step2 = trailhead.add_step(job_id, { name = 'Read module 2', note = 'via agent' })
check(ok_step2, 'note step with text added')
do
    ---@type any
    local any_trailhead = trailhead
    local bad_argv, bad_argv_err = any_trailhead.add_step(job_id, { name = 'bad', argv = { 'echo', 42 } })
    acheck(bad_argv == false and type(bad_argv_err) == 'string', 'argv with non-string rejected')
end
local bad_empty = trailhead.add_step(job_id, { name = 'bad', argv = {} })
acheck(bad_empty == false, 'empty argv rejected')
local bad_name = trailhead.add_step(job_id, { name = '' })
acheck(bad_name == false, 'empty step name rejected')
local bad_job = trailhead.add_step('th-nope', { name = 'x' })
acheck(bad_job == false, 'add_step to unknown job rejected')

-- ---- adversarial: start validation --------------------------------------
local empty_id = trailhead.enqueue({ kind = 'study', title = 'empty job' })
assert(empty_id ~= nil, 'scaffolding: empty_id must be a job id')
local ok_empty, err_empty = trailhead.start(empty_id)
acheck(ok_empty == false and type(err_empty) == 'string', 'start with no steps rejected')
local ok_unknown = trailhead.start('th-nope')
acheck(ok_unknown == false, 'start unknown job rejected')

-- ---- validation: note steps run to done ---------------------------------
local ok_start = trailhead.start(job_id)
check(ok_start, 'job started')
-- adversarial: a note step is synchronously running here (its auto-complete
-- is scheduled, not yet fired), so manual reporting must refuse it.
local note_id = trailhead.enqueue({ kind = 'study', title = 'note probe' })
assert(note_id ~= nil, 'scaffolding: note_id must be a job id')
trailhead.add_step(note_id, { name = 'read me', note = 'some text' })
check(trailhead.start(note_id), 'note probe job started')
local ok_note_report, note_report_err = trailhead.complete_step(note_id, 'read me')
acheck(
    ok_note_report == false and note_report_err == 'step is note-driven; it completes on its own',
    'complete_step on note-driven step rejected'
)
local note_probe_done = vim.wait(3000, function()
    local job = trailhead.get(note_id)
    return job ~= nil and job.status == 'done'
end)
check(note_probe_done, 'note probe job auto-completes')
local settled = vim.wait(3000, function()
    local job = trailhead.get(job_id)
    return job ~= nil and job.status == 'done'
end)
check(settled, 'note steps auto-complete to done')
local done_count, total_count = trailhead.progress(job_id)
check(done_count == 2 and total_count == 2, 'progress reports 2/2')
local finished = trailhead.get(job_id)
check(finished and finished.result ~= nil and #finished.log > 0, 'result and log recorded')
check(finished and finished.handle == nil, 'get() does not expose the process handle')

-- ---- adversarial: double start / resume done -----------------------------
local ok_restart = trailhead.start(job_id)
acheck(ok_restart == false, 'start on done job rejected')
local ok_resume_done = trailhead.resume(job_id)
acheck(ok_resume_done == false, 'resume on done job rejected')

-- ---- validation: manual external-agent reporting -------------------------
-- External steps (no argv, no note) wait after start() until reported.
local manual_id = trailhead.enqueue({ kind = 'trailmix', title = 'manual quest work' })
assert(manual_id ~= nil, 'scaffolding: manual_id must be a job id')
trailhead.add_step(manual_id, { name = 'unit-a' })
trailhead.add_step(manual_id, { name = 'unit-b' })
-- adversarial: reporting while paused is rejected; the job must start first.
local ok_paused_report = trailhead.complete_step(manual_id, 'unit-a', 'quiz passed')
acheck(ok_paused_report == false, 'complete_step on paused job rejected')
local ok_paused_fail = trailhead.fail_step(manual_id, 'unit-a', 'nope')
acheck(ok_paused_fail == false, 'fail_step on paused job rejected')
check(trailhead.start(manual_id), 'external job started')
local waiting = trailhead.get(manual_id)
check(
    waiting ~= nil
        and waiting.status == 'running'
        and waiting.steps[1].status == 'running'
        and waiting.steps[2].status == 'pending',
    'external step waits after start; later steps stay pending'
)
-- adversarial: only the waiting step can be reported, by name.
local ok_wrong = trailhead.complete_step(manual_id, 'unit-b')
acheck(ok_wrong == false, 'complete_step on non-waiting step rejected')
local ok_unknown_step = trailhead.complete_step(manual_id, 'unit-zzz')
acheck(ok_unknown_step == false, 'complete_step unknown step rejected')
local ok_done = trailhead.complete_step(manual_id, 'unit-a', 'quiz passed')
check(ok_done, 'complete_step reports waiting step done')
local mid = trailhead.get(manual_id)
check(
    mid ~= nil and mid.steps[1].status == 'done' and mid.steps[2].status == 'running',
    'report advances to the next external step'
)
local ok_fail = trailhead.fail_step(manual_id, 'unit-b', 'hands-on check failed')
check(ok_fail, 'fail_step reports waiting step failed')
local failed_job = trailhead.get(manual_id)
check(failed_job ~= nil and failed_job.status == 'failed', 'job failed after fail_step')
local ok_resume = trailhead.resume(manual_id)
check(ok_resume, 'resume re-queues failed job')
-- unit-b is external, so the resumed job waits on it again instead of
-- finishing on its own.
local manual_waiting = vim.wait(3000, function()
    local job = trailhead.get(manual_id)
    return job ~= nil and job.status == 'running' and job.steps[2].status == 'running'
end)
check(manual_waiting, 'resumed job waits on the retried external step')
local ok_redo = trailhead.complete_step(manual_id, 'unit-b', 'quiz passed on retry')
check(ok_redo, 'retried external step can be reported done')
local manual_settled = vim.wait(3000, function()
    local job = trailhead.get(manual_id)
    return job ~= nil and job.status == 'done'
end)
check(manual_settled, 'manual job reaches done after all steps reported')

-- ---- validation: shell steps (argv form, real binaries) -------------------
if has_bin('echo') and has_bin('false') then
    local shell_id = trailhead.enqueue({ kind = 'shell', title = 'shell probe' })
    assert(shell_id ~= nil, 'scaffolding: shell_id must be a job id')
    trailhead.add_step(shell_id, { name = 'say hi', argv = { 'echo', 'hello-trailhead' } })
    trailhead.add_step(shell_id, { name = 'boom', argv = { 'false' } })
    check(trailhead.start(shell_id), 'shell job started')
    local shell_settled = vim.wait(5000, function()
        local job = trailhead.get(shell_id)
        return job ~= nil and (job.status == 'done' or job.status == 'failed')
    end)
    check(shell_settled, 'shell job settled')
    local shell_job = trailhead.get(shell_id)
    check(shell_job and shell_job.status == 'failed', 'failing argv marks job failed')
    local saw_output = false
    local saw_exit = false
    if shell_job then
        for _, line in ipairs(shell_job.log) do
            if line:find('hello%-trailhead', 1) then
                saw_output = true
            end
            if line:find('exit 1', 1, true) then
                saw_exit = true
            end
        end
    end
    check(saw_output, 'shell stdout captured in job log')
    check(saw_exit, 'non-zero exit recorded')
    -- resume retries the failed step
    check(trailhead.resume(shell_id), 'shell job resumed')
    local shell_settled2 = vim.wait(5000, function()
        local job = trailhead.get(shell_id)
        return job ~= nil and (job.status == 'done' or job.status == 'failed')
    end)
    check(shell_settled2 and trailhead.get(shell_id).status == 'failed', 'failed shell step fails again on resume')
else
    skip('echo/false not in PATH; shell step tests skipped')
end

-- ---- validation: AddStep note mode through the command layer ----------------
-- User commands close over this module instance, so command behavior is
-- tested here, before the persistence section re-requires the module.
precond(pcall(require, 'dev.sf'), 'dev.sf loads for the command-layer test')
local cmd_id = trailhead.enqueue({ kind = 'quest', title = 'command note' })
assert(cmd_id ~= nil, 'scaffolding: cmd_id must be a job id')
if cmd_id then
    vim.cmd('SfTrailheadAddStep ' .. cmd_id .. ' note alpha')
    vim.cmd('SfTrailheadAddStep ' .. cmd_id .. ' note beta extra words here')
    local cmd_job = trailhead.get(cmd_id)
    check(
        cmd_job ~= nil
            and #cmd_job.steps == 2
            and cmd_job.steps[1].name == 'alpha'
            and cmd_job.steps[1].note == 'alpha'
            and cmd_job.steps[2].name == 'beta'
            and cmd_job.steps[2].note == 'extra words here',
        'AddStep note mode records name/text through commands'
    )
    check(trailhead.start(cmd_id), 'command-note job started')
    check(
        vim.wait(3000, function()
            local job = trailhead.get(cmd_id)
            return job ~= nil and job.status == 'done'
        end),
        'command-created note steps auto-complete to done'
    )
end

-- ---- validation: cancel ---------------------------------------------------
local cancel_id = trailhead.enqueue({ kind = 'study', title = 'cancel me' })
assert(cancel_id ~= nil, 'scaffolding: cancel_id must be a job id')
local ok_cancel_paused = trailhead.cancel(cancel_id)
acheck(ok_cancel_paused == false, 'cancel on a paused draft job is rejected')
local ok_cancel_unknown = trailhead.cancel('th-nope')
acheck(ok_cancel_unknown == false, 'cancel unknown job rejected')

-- ---- adversarial: add_step to a running job ------------------------------
if has_bin('sleep') then
    local run_id = trailhead.enqueue({ kind = 'shell', title = 'running probe' })
    assert(run_id ~= nil, 'scaffolding: run_id must be a job id')
    trailhead.add_step(run_id, { name = 'nap', argv = { 'sleep', '30' } })
    check(trailhead.start(run_id), 'sleep job started')
    vim.wait(500, function()
        local job = trailhead.get(run_id)
        return job ~= nil and job.status == 'running'
    end)
    local ok_late = trailhead.add_step(run_id, { name = 'late' })
    acheck(ok_late == false, 'add_step to running job rejected')
    local ok_shell_report, shell_report_err = trailhead.complete_step(run_id, 'nap')
    acheck(
        ok_shell_report == false and shell_report_err == 'step is shell-driven; it completes on its own',
        'complete_step on shell-driven step rejected'
    )
    local ok_shell_fail, shell_fail_err = trailhead.fail_step(run_id, 'nap', 'nope')
    acheck(
        ok_shell_fail == false and shell_fail_err == 'step is shell-driven; it completes on its own',
        'fail_step on shell-driven step rejected'
    )
    check(trailhead.cancel(run_id), 'running sleep job cancelled')
    check(trailhead.get(run_id).status == 'cancelled', 'cancelled running job recorded')
    check(trailhead.resume(run_id), 'cancelled job resumable')
else
    skip('sleep not in PATH; running-job tests skipped')
end

-- ---- validation: event subscribers -----------------------------------------
local events = {}
trailhead.on_event(function(event)
    events[#events + 1] = event.type .. ':' .. event.status
end)
trailhead.on_event(function()
    error('boom')
end)
trailhead.enqueue({ kind = 'note', title = 'event probe' })
acheck(#events >= 1 and events[1] == 'job:paused', 'subscriber got enqueue event despite throwing sibling')

-- ---- validation: persistence across reload ----------------------------------
local persist_id = trailhead.enqueue({ kind = 'quest', title = 'persist me' })
assert(persist_id ~= nil, 'scaffolding: persist_id must be a job id')
trailhead.add_step(persist_id, { name = 'step one' })
local state_file = vim.fn.stdpath('data') .. '/diver/sf/trailhead.json'
check(vim.fn.filereadable(state_file) == 1, 'state file written to ' .. state_file)
package.loaded['dev.sf.trailhead'] = nil
local trailhead2 = require('dev.sf.trailhead')
local reloaded = trailhead2.get(persist_id)
check(reloaded and reloaded.title == 'persist me', 'job survives module reload')
check(reloaded and #reloaded.steps == 1 and reloaded.steps[1].name == 'step one', 'steps survive reload')
trailhead = trailhead2

-- adversarial: malformed state file degrades to empty, never throws
local backup = nil
do
    local handle = io.open(state_file, 'r')
    if handle then
        backup = handle:read('*a')
        handle:close()
    end
end
do
    local handle = io.open(state_file, 'w')
    if handle then
        handle:write('this is not json {{{')
        handle:close()
    end
end
package.loaded['dev.sf.trailhead'] = nil
local ok_garbage, trailhead3 = pcall(require, 'dev.sf.trailhead')
acheck(ok_garbage and #trailhead3.list() == 0, 'malformed state file loads as empty')
if backup then
    local handle = io.open(state_file, 'w')
    if handle then
        handle:write(backup)
        handle:close()
    end
end
package.loaded['dev.sf.trailhead'] = nil
trailhead = require('dev.sf.trailhead')

-- ---- validation: voucher intel ----------------------------------------------
local lines = trailhead.quest_lines()
check(#lines > 10, 'quest_lines returns content')
local blob = table.concat(lines, '\n')
local verified_count = 0
for _ in blob:gmatch('%[VERIFIED%]') do
    verified_count = verified_count + 1
end
local speculative_count = 0
for _ in blob:gmatch('%[SPECULATIVE%]') do
    speculative_count = speculative_count + 1
end
check(verified_count == 4 and speculative_count == 3, 'voucher claims labeled 4 verified / 3 speculative')
check(blob:find('trailblazer.me/id/qompassai', 1, true) ~= nil, 'open browser item recorded')

-- ---- validation: full suite registration ------------------------------------
local ok_sf, sf = pcall(require, 'dev.sf')
check(ok_sf and type(sf.trailhead) == 'table', 'dev.sf exposes trailhead')
-- nvim_get_commands({}) lists nothing in headless -l runs, so probe each
-- command directly with exists().
local expected_commands = {
    'SfTrailheadEnqueue',
    'SfTrailheadAddStep',
    'SfTrailheadStart',
    'SfTrailheadCancel',
    'SfTrailheadCancelAll',
    'SfTrailheadResume',
    'SfTrailheadDone',
    'SfTrailheadFail',
    'SfTrailheadStatus',
    'SfTrailheadJobs',
    'SfTrailheadLog',
    'SfTrailheadQuests',
}
local missing = 0
for _, name in ipairs(expected_commands) do
    if vim.fn.exists(':' .. name) ~= 2 then
        missing = missing + 1
    end
end
check(missing == 0, 'all 12 SfTrailhead* commands registered')

-- ---- validation: :Sf stub before activation ----------------------------------
local utils_ok = pcall(require, 'utils')
check(utils_ok, 'utils loads (stub definitions execute)')
check(vim.fn.exists(':Sf') == 2, ':Sf stub command exists')

-- ---- validation: sfdx-project.json activates the suite ----------------------
local proj = vim.fn.tempname() .. '-sfproj'
vim.fn.mkdir(proj, 'p')
local marker = io.open(proj .. '/sfdx-project.json', 'w')
assert(marker ~= nil, 'scaffolding: sfdx marker must be writable')
marker:write('{}')
marker:close()
package.loaded['dev.sf'] = nil
vim.cmd('edit ' .. vim.fn.fnameescape(proj .. '/notes.md'))
vim.wait(500, function()
    return package.loaded['dev.sf'] ~= nil
end)
check(package.loaded['dev.sf'] ~= nil, 'sfdx-project.json activates dev.sf for generic files')
vim.fn.delete(proj, 'rf')
-- Leave the deleted project behind: later shell steps spawn with
-- cwd = core.root(), which would otherwise resolve into the deleted dir.
vim.cmd('enew')

-- ---- adversarial: bounds, aliasing, hostile state ---------------------------
-- argv count bound
local argv_bound_id = trailhead.enqueue({ kind = 'quest', title = 'argv bounds' })
assert(argv_bound_id ~= nil, 'scaffolding: argv_bound_id must be a job id')
precond(argv_bound_id ~= nil, 'argv bounds job enqueued')
if argv_bound_id then
    local many = {}
    for i = 1, 33 do
        many[i] = 'x'
    end
    local ok_many, err_many = trailhead.add_step(argv_bound_id, { name = 'many', argv = many })
    acheck(
        ok_many == false and type(err_many) == 'string' and err_many:find('32', 1, true) ~= nil,
        'argv exceeding STEP_ARGV_COUNT_MAX rejected'
    )
    local ok_long, err_long =
        trailhead.add_step(argv_bound_id, { name = 'long', argv = { 'ok', string.rep('y', 2049) } })
    acheck(
        ok_long == false and type(err_long) == 'string' and err_long:find('2048', 1, true) ~= nil,
        'argv argument exceeding STEP_ARGV_BYTES_MAX rejected'
    )
end

-- on_event validates gracefully instead of throwing
do
    ---@type any
    local any_trailhead = trailhead
    local ok_sub, err_sub = any_trailhead.on_event('not a function')
    acheck(ok_sub == false and type(err_sub) == 'string', 'on_event with non-function rejected gracefully')
end

-- reentrant reporting from inside a subscriber cannot corrupt the job
local re_id = trailhead.enqueue({ kind = 'quest', title = 'reentrancy' })
precond(re_id ~= nil, 'reentrancy job enqueued')
if re_id then
    trailhead.add_step(re_id, { name = 'first' })
    trailhead.add_step(re_id, { name = 'second' })
    local reentrant_calls = 0
    trailhead.on_event(function(event)
        if event.job_id == re_id and event.type == 'step' then
            reentrant_calls = reentrant_calls + 1
            trailhead.complete_step(re_id, 'first')
        end
    end)
    precond(trailhead.start(re_id), 'reentrancy job started')
    local re_job = trailhead.get(re_id)
    check(
        reentrant_calls >= 1
            and re_job ~= nil
            and re_job.steps[1].status == 'done'
            and re_job.steps[2].status == 'running',
        'reentrant report during emit applied exactly once, no corruption'
    )
    -- adversarial: non-string step name rejected while the job is running
    do
        ---@type any
        local any_trailhead = trailhead
        local ok_ns, err_ns = any_trailhead.complete_step(re_id, 42)
        acheck(ok_ns == false and err_ns == 'step name is required', 'complete_step with non-string name rejected')
    end
    precond(trailhead.cancel(re_id), 'reentrancy job cancelled')
end

-- fail_step on a step that is not the waiting one
local wrong_id = trailhead.enqueue({ kind = 'quest', title = 'wrong name' })
precond(wrong_id ~= nil, 'wrong-name job enqueued')
if wrong_id then
    trailhead.add_step(wrong_id, { name = 'first' })
    trailhead.add_step(wrong_id, { name = 'second' })
    precond(trailhead.start(wrong_id), 'wrong-name job started')
    local ok_fn, err_fn = trailhead.fail_step(wrong_id, 'second', 'boom')
    acheck(
        ok_fn == false
            and type(err_fn) == 'string'
            and err_fn:find('only the waiting step can be reported', 1, true) ~= nil,
        'fail_step on non-waiting step rejected'
    )
    precond(trailhead.cancel(wrong_id), 'wrong-name job cancelled')
end

-- double reporting and empty failure detail
local double_id = trailhead.enqueue({ kind = 'quest', title = 'double report' })
precond(double_id ~= nil, 'double-report job enqueued')
if double_id then
    trailhead.add_step(double_id, { name = 'one' })
    trailhead.add_step(double_id, { name = 'two' })
    precond(trailhead.start(double_id), 'double-report job started')
    precond(trailhead.complete_step(double_id, 'one'), 'first report accepted')
    local ok_twice, err_twice = trailhead.complete_step(double_id, 'one')
    acheck(
        ok_twice == false
            and type(err_twice) == 'string'
            and err_twice:find('only the waiting step can be reported', 1, true) ~= nil,
        'double report of a finished step rejected'
    )
    local ok_fe, _ = trailhead.fail_step(double_id, 'two', '')
    local failed2 = trailhead.get(double_id)
    acheck(
        ok_fe and failed2 ~= nil and failed2.steps[2].detail == 'reported as failed',
        'fail_step with empty detail degrades to a default message'
    )
end

-- reporting after cancellation: the generation is gone, the report must die
local stale_id = trailhead.enqueue({ kind = 'quest', title = 'stale probe' })
precond(stale_id ~= nil, 'stale probe enqueued')
if stale_id then
    trailhead.add_step(stale_id, { name = 'waiter' })
    precond(trailhead.start(stale_id), 'stale probe started')
    precond(trailhead.cancel(stale_id), 'stale probe cancelled')
    local ok_stale, err_stale = trailhead.complete_step(stale_id, 'waiter')
    acheck(
        ok_stale == false and type(err_stale) == 'string' and err_stale:find('job is not running', 1, true) ~= nil,
        'complete_step after cancel rejected'
    )
end

-- get()/list() return isolated copies; mutating them cannot touch live state
local alias_id = trailhead.enqueue({ kind = 'quest', title = 'alias probe' })
precond(alias_id ~= nil, 'alias probe enqueued')
if alias_id then
    trailhead.add_step(alias_id, { name = 's1' })
    local before = trailhead.get(alias_id)
    local log_n = before and #before.log or -1
    local probe = trailhead.get(alias_id)
    if probe then
        probe.title = 'MUTATED'
        probe.status = 'done'
        probe.steps[1].name = 'MUTATED'
        probe.steps[1].status = 'done'
        probe.log[#probe.log + 1] = 'MUTATED'
    end
    local fresh = trailhead.get(alias_id)
    acheck(
        fresh ~= nil
            and fresh.title == 'alias probe'
            and fresh.status == 'paused'
            and fresh.steps[1].name == 's1'
            and fresh.steps[1].status == 'pending'
            and #fresh.log == log_n,
        'get() returns an isolated copy'
    )
    local listed = trailhead.list()
    for _, job in ipairs(listed) do
        if job.id == alias_id then
            job.status = 'done'
            job.steps[1].status = 'done'
        end
    end
    local still = trailhead.get(alias_id)
    acheck(
        still ~= nil and still.status == 'paused' and still.steps[1].status == 'pending',
        'list() returns copies, not live jobs'
    )
end

-- steps per job are bounded
local step_bound_id = trailhead.enqueue({ kind = 'note', title = 'step bound' })
precond(step_bound_id ~= nil, 'step-bound job enqueued')
if step_bound_id then
    local steps_added = 0
    for i = 1, 300 do
        if trailhead.add_step(step_bound_id, { name = 's' .. i }) then
            steps_added = steps_added + 1
        end
    end
    local step_bound_job = trailhead.get(step_bound_id)
    acheck(
        steps_added == 256 and step_bound_job ~= nil and #step_bound_job.steps == 256,
        'steps bounded by STEPS_PER_JOB_MAX'
    )
end

-- subscribers are bounded
do
    ---@type any
    local any_trailhead = trailhead
    local filled = 0
    local last_err = nil
    for _ = 1, 20 do
        local ok_s, err_s = any_trailhead.on_event(function() end)
        if ok_s then
            filled = filled + 1
        else
            last_err = err_s
        end
    end
    acheck(filled == 15 and type(last_err) == 'string', 'subscribers bounded by SUBSCRIBER_COUNT_MAX')
end

-- adversarial: hostile persisted state is coerced, never trusted
local hostile_backup = nil
do
    local handle = io.open(state_file, 'r')
    if handle then
        hostile_backup = handle:read('*a')
        handle:close()
    end
end
local hostile = {
    {
        id = 'hostile-1',
        kind = 'not-a-real-kind',
        title = string.rep('T', 500),
        status = 'running',
        steps = {
            {
                name = string.rep('N', 500),
                argv = { 'echo', 42, string.rep('A', 5000) },
                status = 'running',
            },
            { name = 'ok step', note = 'hi' },
        },
        log = { 'fine', 42, string.rep('L', 5000) },
    },
    'not a table',
}
do
    local handle = io.open(state_file, 'w')
    if handle then
        handle:write(vim.json.encode(hostile))
        handle:close()
    end
end
package.loaded['dev.sf.trailhead'] = nil
local ok_hostile, th_hostile = pcall(require, 'dev.sf.trailhead')
local coerced = ok_hostile and th_hostile.get('hostile-1') or nil
acheck(
    ok_hostile
        and coerced ~= nil
        and coerced.kind == 'note'
        and #coerced.title == 200
        and #coerced.steps == 2
        and #coerced.steps[1].name == 200
        and coerced.steps[1].argv == nil
        and coerced.steps[1].status == 'pending'
        and #coerced.log == 2
        and coerced.log[1] == 'fine'
        and #coerced.log[2] == 1024,
    'hostile state coerced: kind falls back, strings truncated, bad argv dropped, log capped'
)
if ok_hostile then
    acheck(#th_hostile.list() == 1, 'non-table state entries skipped')
end

-- adversarial: hostile ids, empty names, unbounded result/error, argv shapes
local hostile2 = {
    -- Overlong id: rejected outright, never truncated into a by_id collision.
    {
        id = string.rep('I', 200),
        kind = 'note',
        title = 'too long',
        status = 'paused',
        steps = {},
    },
    -- Duplicate ids: the first job wins; the shadow never loads.
    { id = 'dup', kind = 'note', title = 'first', status = 'paused', steps = {} },
    { id = 'dup', kind = 'note', title = 'second', status = 'paused', steps = {} },
    {
        id = 'shapes',
        kind = 'note',
        title = 'shapes',
        status = 'paused',
        result = string.rep('R', 5000),
        error = string.rep('E', 5000),
        steps = {
            { name = '', note = 'empty names are skipped' },
            { name = 'overlong argv entry', argv = { 'echo', string.rep('B', 5000) } },
            { name = 'good', note = 'kept' },
        },
    },
}
do
    local handle = io.open(state_file, 'w')
    if handle then
        handle:write(vim.json.encode(hostile2))
        handle:close()
    end
end
package.loaded['dev.sf.trailhead'] = nil
local ok_h2, th_h2 = pcall(require, 'dev.sf.trailhead')
local dup = ok_h2 and th_h2.get('dup') or nil
local shapes = ok_h2 and th_h2.get('shapes') or nil
acheck(
    ok_h2
        and th_h2.get(string.rep('I', 200)) == nil
        and #th_h2.list() == 2
        and dup ~= nil
        and dup.title == 'first'
        and shapes ~= nil
        and #shapes.result == 4096
        and #shapes.error == 4096
        and #shapes.steps == 2
        and shapes.steps[1].name == 'overlong argv entry'
        and shapes.steps[1].argv == nil
        and shapes.steps[2].name == 'good',
    'hostile ids rejected/deduped, empty names skipped, result/error capped, bad argv dropped'
)

-- adversarial: a null gap in persisted argv rejects the whole argv
do
    local handle = io.open(state_file, 'w')
    if handle then
        handle:write(
            '[{"id":"gap-1","kind":"note","title":"gap","status":"paused",'
                .. '"steps":[{"name":"g","argv":["echo",null,"x"]}]}]'
        )
        handle:close()
    end
end
package.loaded['dev.sf.trailhead'] = nil
local ok_gap, th_gap = pcall(require, 'dev.sf.trailhead')
local gap_job = ok_gap and th_gap.get('gap-1') or nil
acheck(
    ok_gap and gap_job ~= nil and gap_job.steps[1].argv == nil,
    'null gap in persisted argv rejects the whole argv (external step, no spawn)'
)

-- adversarial: oversized state file is refused before it can exhaust memory
do
    local handle = io.open(state_file, 'w')
    if handle then
        handle:write('[' .. string.rep(' ', 16777217) .. ']')
        handle:close()
    end
end
package.loaded['dev.sf.trailhead'] = nil
local ok_big, th_big = pcall(require, 'dev.sf.trailhead')
acheck(ok_big and #th_big.list() == 0, 'oversized state file loads as empty')
if hostile_backup then
    local handle = io.open(state_file, 'w')
    if handle then
        handle:write(hostile_backup)
        handle:close()
    end
end
package.loaded['dev.sf.trailhead'] = nil
trailhead = require('dev.sf.trailhead')
acheck(vim.fn.filereadable(state_file .. '.tmp') == 0, 'no state temp file left behind after saves')

-- double cancel: the second one must fail, not double-decrement
local dc_id = trailhead.enqueue({ kind = 'quest', title = 'double cancel' })
precond(dc_id ~= nil, 'double-cancel job enqueued')
if dc_id then
    trailhead.add_step(dc_id, { name = 'w' })
    precond(trailhead.start(dc_id), 'double-cancel job started')
    precond(trailhead.cancel(dc_id), 'first cancel accepted')
    local ok_dc, err_dc = trailhead.cancel(dc_id)
    acheck(ok_dc == false and err_dc == 'job is not active', 'second cancel rejected')
end

-- active slots are bounded; a 5th concurrent start stays queued
local slot_ids = {}
for i = 1, 4 do
    local sid = trailhead.enqueue({ kind = 'quest', title = 'slot ' .. i })
    if sid then
        trailhead.add_step(sid, { name = 'wait' })
        slot_ids[#slot_ids + 1] = sid
    end
end
precond(#slot_ids == 4, 'four slot jobs enqueued')
for _, sid in ipairs(slot_ids) do
    precond(trailhead.start(sid), 'slot job started')
end
local q5 = trailhead.enqueue({ kind = 'quest', title = 'queued probe' })
precond(q5 ~= nil, 'queued probe enqueued')
if q5 then
    trailhead.add_step(q5, { name = 'wait' })
    precond(trailhead.start(q5), 'fifth start accepted')
    local q5_job = trailhead.get(q5)
    check(q5_job ~= nil and q5_job.status == 'queued', 'fifth job stays queued past ACTIVE_JOB_COUNT_MAX')
    local ok_q5, err_q5 = trailhead.start(q5)
    acheck(ok_q5 == false and err_q5 == 'job is already active', 'start on queued job rejected')
    local ok_rs, err_rs = trailhead.start(slot_ids[1])
    acheck(ok_rs == false and err_rs == 'job is already active', 'start on running job rejected')
    for _, sid in ipairs(slot_ids) do
        trailhead.cancel(sid)
    end
    trailhead.cancel(q5)
end

-- reporting on a finished job
local ok_done_report, err_done_report = trailhead.complete_step(manual_id, 'verify')
acheck(
    ok_done_report == false
        and type(err_done_report) == 'string'
        and err_done_report:find('job is not running', 1, true) ~= nil,
    'complete_step on done job rejected'
)

-- unknown ids degrade everywhere
local d0, t0, perr = trailhead.progress('no-such-job')
acheck(d0 == 0 and t0 == 0 and perr == 'unknown job id', 'progress on unknown id degrades')
local st_unknown = trailhead.status('no-such-job')
acheck(
    type(st_unknown) == 'string' and st_unknown:find('unknown job id', 1, true) ~= nil,
    'status on unknown id degrades'
)
do
    ---@type any
    local any_trailhead = trailhead
    local id_kind = any_trailhead.enqueue({ kind = 42, title = 'x' })
    acheck(id_kind == nil, 'enqueue with non-string kind rejected')
end

-- cancel_all cancels waiting external jobs; their reports die afterwards
local ca_id = trailhead.enqueue({ kind = 'quest', title = 'cancel all' })
precond(ca_id ~= nil, 'cancel-all job enqueued')
if ca_id then
    trailhead.add_step(ca_id, { name = 'w' })
    precond(trailhead.start(ca_id), 'cancel-all job started')
    local cancelled_n = trailhead.cancel_all()
    local ca_job = trailhead.get(ca_id)
    acheck(cancelled_n >= 1 and ca_job ~= nil and ca_job.status == 'cancelled', 'cancel_all cancels waiting jobs')
    local ok_ca, _ = trailhead.complete_step(ca_id, 'w')
    acheck(ok_ca == false, 'report after cancel_all rejected')
end

-- stale shell generation: a kill delivered after cancel must be ignored
if has_bin('sleep') then
    local sl_id = trailhead.enqueue({ kind = 'quest', title = 'stale shell' })
    precond(sl_id ~= nil, 'stale-shell job enqueued')
    if sl_id then
        trailhead.add_step(sl_id, { name = 'nap', argv = { 'sleep', '30' } })
        precond(trailhead.start(sl_id), 'stale-shell job started')
        check(trailhead.cancel(sl_id), 'stale-shell job cancelled')
        vim.wait(800)
        local sl_job = trailhead.get(sl_id)
        local marked_done = false
        if sl_job then
            for _, line in ipairs(sl_job.log) do
                if line:find('step done: nap', 1, true) ~= nil then
                    marked_done = true
                end
            end
        end
        acheck(
            sl_job ~= nil and sl_job.status == 'cancelled' and not marked_done,
            'cancelled shell job ignores its stale exit callback'
        )
    end
else
    skip('sleep unavailable: stale shell generation not tested')
end

-- a persisted 'running' shell step retries cleanly through resume()
if has_bin('true') then
    local retry_backup = nil
    do
        local handle = io.open(state_file, 'r')
        if handle then
            retry_backup = handle:read('*a')
            handle:close()
        end
    end
    local retry_state = {
        {
            id = 'retry-1',
            kind = 'quest',
            title = 'retry me',
            status = 'running',
            steps = { { name = 'quick', argv = { 'true' }, status = 'running' } },
            log = {},
        },
    }
    do
        local handle = io.open(state_file, 'w')
        if handle then
            handle:write(vim.json.encode(retry_state))
            handle:close()
        end
    end
    package.loaded['dev.sf.trailhead'] = nil
    local ok_retry, th_retry = pcall(require, 'dev.sf.trailhead')
    local resumed = ok_retry and th_retry.resume('retry-1')
    local retried = false
    if resumed then
        retried = vim.wait(5000, function()
            local job = th_retry.get('retry-1')
            return job ~= nil and job.status == 'done'
        end)
    end
    acheck(ok_retry and resumed and retried, 'reloaded running shell step retries to done via resume()')
    if retry_backup then
        local handle = io.open(state_file, 'w')
        if handle then
            handle:write(retry_backup)
            handle:close()
        end
    end
    package.loaded['dev.sf.trailhead'] = nil
    trailhead = require('dev.sf.trailhead')
else
    skip('true unavailable: resume-retry not tested')
end

-- command handlers never throw on bad input
acheck(
    pcall(function()
        vim.cmd('SfTrailheadDone bogus-id whatever')
    end),
    'SfTrailheadDone with unknown id does not throw'
)
acheck(
    pcall(function()
        vim.cmd('SfTrailheadStart')
    end),
    'SfTrailheadStart with no args does not throw'
)

-- job count is bounded (fills the queue; must run last)
do
    local created = 0
    for _ = 1, 200 do
        if trailhead.enqueue({ kind = 'note', title = 'fill' }) then
            created = created + 1
        end
    end
    acheck(created < 200 and #trailhead.list() == 128, 'enqueue bounded by JOB_COUNT_MAX')
end

-- ---- report ------------------------------------------------------------------
print(('trailhead: %d passed, %d failed, %d skipped'):format(passed, failed, skipped))
print(
    ('  validation: %d passed, %d failed | adversarial: %d passed, %d failed'):format(
        validation_passed,
        validation_failed,
        adversarial_passed,
        adversarial_failed
    )
)
if failed > 0 then
    for _, message in ipairs(failures) do
        print('  FAIL: ' .. message)
    end
    vim.cmd('cquit 1')
end
