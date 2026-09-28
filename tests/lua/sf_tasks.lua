-- Tests for dev.sf.tasks -- the async Salesforce agent-task dispatcher.
-- Run from the repo root:  lua tests/lua/sf_tasks.lua
-- Harness follows tests/lua/research_docs_make_header.lua (plain-lua
-- `check` counting, stubbed vim since `vim` is nil outside Neovim).
-- `vim.system` is stubbed with scripted responses (success / failing
-- org probe / malformed stdout / never-completing) so every run is
-- hermetic: no real `sf`, no network, no org.
-- Exactly 50% validation / 50% adversarial: 10 + 10 CASES.
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

-- Scripted `sf` behaviour for the vim.system stub.
local STUB = {
    mode = 'success', -- success | fail_probe | malformed | hang
    sf_present = 1,
    calls = {},
    notifies = {},
    doc_root = nil,
}

local function stub_response(argv)
    if STUB.mode == 'fail_probe' and argv[2] == 'org' and argv[3] == 'list' then
        return { code = 1, stdout = '', stderr = 'Error: No orgs found. Authenticate first.' }
    end
    if STUB.mode == 'malformed' and argv[2] == 'org' and argv[3] == 'list' then
        return { code = 0, stdout = 'not-json{{{', stderr = '' }
    end
    return { code = 0, stdout = '{"status":0,"result":[]}', stderr = '' }
end

_G.vim = {
    api = {
        nvim_buf_get_name = function()
            return ''
        end,
    },
    fn = {
        executable = function(name)
            if name == 'sf' then
                return STUB.sf_present
            end
            return 0
        end,
        stdpath = function()
            return '/tmp/diver-sf-tasks-stub-data'
        end,
        fnamemodify = function(path, mods)
            assert(mods == ':h', 'stub only implements :h')
            return path:match('^(.*)/[^/]*$') or '.'
        end,
        isdirectory = function()
            return 0
        end,
        mkdir = function(path)
            os.execute('mkdir -p "' .. path .. '"')
            return 1
        end,
        getfsize = function()
            return nil -- no persisted state in tests; trailhead skips load.
        end,
    },
    fs = {
        find = function()
            return {}
        end,
    },
    uv = {
        cwd = function()
            return '/tmp/diver-sf-tasks-stub-cwd'
        end,
    },
    system = function(argv, _opts, callback)
        STUB.calls[#STUB.calls + 1] = argv
        local handle = {
            killed = nil,
            kill = function(self, sig)
                self.killed = sig
            end,
        }
        if STUB.mode ~= 'hang' then
            local r = stub_response(argv)
            callback({ code = r.code, stdout = r.stdout, stderr = r.stderr })
        end
        return handle
    end,
    schedule = function(f)
        f()
    end,
    notify = function(msg, _level)
        STUB.notifies[#STUB.notifies + 1] = msg
    end,
    inspect = tostring,
    json = {
        encode = function()
            error('stub: no json encode in tests')
        end,
        decode = function()
            return nil
        end,
    },
    split = function(s, sep)
        local parts = {}
        for part in s:gmatch('[^' .. sep .. ']+') do
            parts[#parts + 1] = part
        end
        return parts
    end,
    log = { levels = { DEBUG = 0, INFO = 1, WARN = 2, ERROR = 3 } },
}

local tasks = require('dev.sf.tasks')

local tmpbase = os.tmpname() .. '-sf-tasks'
os.execute('mkdir -p "' .. tmpbase .. '"')
local doc_root = tmpbase .. '/docs'
tasks.set_doc_root(doc_root)

local counts = { validation = 0, adversarial = 0 }
local failures = {}

---@param name string
---@param kind string 'validation' | 'adversarial'
---@param cond boolean
local function check(name, kind, cond)
    counts[kind] = counts[kind] + 1
    if not cond then
        failures[#failures + 1] = kind .. ': ' .. name
        print('FAIL [' .. kind .. '] ' .. name)
    else
        print('ok   [' .. kind .. '] ' .. name)
    end
end

local function read_file(path)
    local h = io.open(path, 'r')
    if h == nil then
        return nil
    end
    local text = h:read('*a')
    h:close()
    return text
end

local function reset_stub(mode, sf_present)
    STUB.mode = mode or 'success'
    STUB.sf_present = sf_present == nil and 1 or sf_present
    STUB.calls = {}
    STUB.notifies = {}
end

-- ============================ validation ============================

-- V1: org-auth dispatches the exact verified argv for both steps, and runs green.
reset_stub('success')
local id1, err1 = tasks.dispatch('org-auth', { mode = 'hermetic' })
local job1 = id1 and tasks.job(id1)
local argv1 = job1 and job1.steps[1] and job1.steps[1].argv
local argv2 = job1 and job1.steps[2] and job1.steps[2].argv
check(
    'org-auth dispatches exact argv and completes',
    'validation',
    id1 ~= nil
        and err1 == nil
        and job1 ~= nil
        and job1.status == 'done'
        and argv1 ~= nil
        and table.concat(argv1, ' ') == 'sf org list --json'
        and argv2 ~= nil
        and table.concat(argv2, ' ') == 'sf config get target-org --json'
)

-- V2: --target-org is appended to org-targeted steps only.
reset_stub('success')
local id2 = tasks.dispatch('apex-basics', { target_org = 'myorg', mode = 'hermetic' })
local job2 = id2 and tasks.job(id2)
local s1 = job2 and job2.steps[1] and table.concat(job2.steps[1].argv, ' ')
local s2 = job2 and job2.steps[2] and table.concat(job2.steps[2].argv, ' ')
local s3 = job2 and job2.steps[3] and table.concat(job2.steps[3].argv, ' ')
check(
    'target-org appended to needs_org steps only',
    'validation',
    s1 == 'sf org list --json'
        and s2 == 'sf project deploy start --source-dir force-app/main/default/classes/Teatime.cls --json --target-org myorg'
        and s3 == 'sf apex run --file scripts/apex/water_if_else.apex --json --target-org myorg'
)

-- V3: without target_org, no --target-org flag is emitted (default config).
reset_stub('success')
local id3 = tasks.dispatch('soql-for-admins', { mode = 'hermetic' })
local job3 = id3 and tasks.job(id3)
local blob3 = job3
    and table.concat({
        table.concat(job3.steps[1].argv, ' '),
        table.concat(job3.steps[2].argv, ' '),
        table.concat(job3.steps[3].argv, ' '),
    }, '|')
check('no target-org means no flag', 'validation', blob3 ~= nil and not blob3:find('--target-org', 1, true))

-- V4: teach-doc is written automatically on completion: exact commands,
-- outcome, and the hermetic banner (never presented as live evidence).
local doc4 = read_file(doc_root .. '/soql-for-admins.md')
check(
    'teach-doc auto-written with commands, outcome, banner',
    'validation',
    doc4 ~= nil
        and doc4:find('sf data query', 1, true) ~= nil
        and doc4:find('SELECT Name, AnnualRevenue FROM Account LIMIT 5', 1, true) ~= nil
        and doc4:find('- **Outcome:** done', 1, true) ~= nil
        and doc4:find('hermetic dry-run', 1, true) ~= nil
)
-- V5: catalog listing returns exactly the three slugs, sorted.
local slugs = tasks.list_modules()
check(
    'list_modules slugs',
    'validation',
    #slugs == 3 and slugs[1] == 'apex-basics' and slugs[2] == 'org-auth' and slugs[3] == 'soql-for-admins'
)

-- V6: doc_for regenerates a deleted teach-doc.
os.remove(doc_root .. '/org-auth.md')
local regen, regen_err = tasks.doc_for(id1)
local doc7 = read_file(doc_root .. '/org-auth.md')
check('doc_for regenerates', 'validation', regen ~= nil and regen_err == nil and doc7 ~= nil)

-- V7: a running job can be cancelled; the partial run still gets a doc.
reset_stub('hang')
local id8 = tasks.dispatch('org-auth', { mode = 'hermetic' })
local running8 = id8 and tasks.job(id8)
local ok8, err8 = tasks.cancel(id8)
local job8 = id8 and tasks.job(id8)
local doc8 = read_file(doc_root .. '/org-auth.md')
check(
    'cancel running job, doc records cancellation',
    'validation',
    running8 ~= nil
        and running8.status == 'running'
        and ok8
        and err8 == nil
        and job8 ~= nil
        and job8.status == 'cancelled'
        and doc8 ~= nil
        and doc8:find('Outcome:** cancelled', 1, true) ~= nil
)

-- V8: when the org probe fails, later steps never run (stay pending).
reset_stub('fail_probe')
local id9 = tasks.dispatch('apex-basics', { mode = 'hermetic' })
local job9 = id9 and tasks.job(id9)
check(
    'probe failure stops the plan',
    'validation',
    job9 ~= nil
        and job9.status == 'failed'
        and job9.steps[1].status == 'failed'
        and job9.steps[2].status == 'pending'
        and job9.steps[3].status == 'pending'
)

-- V9: job snapshot and module lookup expose titles and step state.
local mod10 = tasks.get_module('apex-basics')
check(
    'get_module and job snapshot',
    'validation',
    mod10 ~= nil and mod10.title == 'Apex Basics & Database (sf CLI edition)' and job9 ~= nil and #job9.steps == 3
)

-- V10: dispatch announces the module and job id via notification.
reset_stub('success')
tasks.set_doc_root(doc_root)
local id10 = tasks.dispatch('org-auth', { mode = 'hermetic' })
local announced = false
for _, msg in ipairs(STUB.notifies) do
    if msg:find('agent task dispatched: org-auth', 1, true) and id10 ~= nil and msg:find(id10, 1, true) then
        announced = true
    end
end
check('dispatch announces job', 'validation', id10 ~= nil and announced)

-- ============================ adversarial ============================

-- A1: unknown module slug is rejected; no job is created.
reset_stub('success')
local before_a1 = #STUB.calls
local id_a1, err_a1 = tasks.dispatch('nope-not-real', { mode = 'hermetic' })
check('unknown module rejected', 'adversarial', id_a1 == nil and err_a1 ~= nil and #STUB.calls == before_a1)

-- A2: path traversal in the slug is rejected; nothing escapes the doc root.
local id_a2, err_a2 = tasks.dispatch('../../etc/passwd', { mode = 'hermetic' })
local escaped = io.open(tmpbase .. '/passwd.md', 'r')
if escaped ~= nil then
    escaped:close()
end
check('traversal slug rejected', 'adversarial', id_a2 == nil and err_a2 ~= nil and escaped == nil)

-- A3: missing `sf` binary fails dispatch honestly instead of faking a run.
reset_stub('success', 0)
local id_a3, err_a3 = tasks.dispatch('org-auth', { mode = 'hermetic' })
check(
    'missing sf fails honestly',
    'adversarial',
    id_a3 == nil and err_a3 ~= nil and err_a3:find('sf CLI', 1, true) ~= nil and #STUB.calls == 0
)

-- A4: non-zero exit marks the job failed; the doc never claims success.
reset_stub('fail_probe')
local id_a4 = tasks.dispatch('org-auth', { mode = 'hermetic' })
local job_a4 = id_a4 and tasks.job(id_a4)
local doc_a4 = read_file(doc_root .. '/org-auth.md')
check(
    'non-zero exit is failure',
    'adversarial',
    job_a4 ~= nil
        and job_a4.status == 'failed'
        and doc_a4 ~= nil
        and doc_a4:find('FAILED at step 1', 1, true) ~= nil
        and doc_a4:find('All 2 steps exited 0', 1, true) == nil
)

-- A5: malformed stdout is recorded raw; the doc invents no parsed results.
reset_stub('malformed')
local id_a5 = tasks.dispatch('org-auth', { mode = 'hermetic' })
local job_a5 = id_a5 and tasks.job(id_a5)
local doc_a5 = read_file(doc_root .. '/org-auth.md')
check(
    'malformed output kept raw',
    'adversarial',
    job_a5 ~= nil and job_a5.status == 'done' and doc_a5 ~= nil and doc_a5:find('not-json{{{', 1, true) ~= nil
)

-- A6: hostile or empty target-org aliases are rejected before any spawn.
reset_stub('success')
local id_a6, err_a6 = tasks.dispatch('apex-basics', { target_org = 'a; rm -rf /', mode = 'hermetic' })
local id_a6b, err_a6b = tasks.dispatch('apex-basics', { target_org = '', mode = 'hermetic' })
check(
    'bad target-org rejected',
    'adversarial',
    id_a6 == nil and err_a6 ~= nil and id_a6b == nil and err_a6b ~= nil and #STUB.calls == 0
)

-- A7: wrong opts type and nil slug are rejected.
local id_a7, err_a7 = tasks.dispatch('org-auth', 'not-a-table')
local id_a7b, err_a7b = tasks.dispatch(nil, { mode = 'hermetic' })
check('bad dispatch args rejected', 'adversarial', id_a7 == nil and err_a7 ~= nil and id_a7b == nil and err_a7b ~= nil)

-- A8: cancelling an unknown job id fails cleanly.
local ok_a8, err_a8 = tasks.cancel('trail-does-not-exist')
check('cancel unknown job', 'adversarial', ok_a8 == false and err_a8 ~= nil)

-- A9: doc_for on an unknown job id fails cleanly.
local doc_a9, err_a9 = tasks.doc_for('trail-does-not-exist')
check('doc_for unknown job', 'adversarial', doc_a9 == nil and err_a9 ~= nil)

-- A10: an unwritable doc root cannot break the job; the failure is a warning.
local blocker = os.tmpname()
tasks.set_doc_root(blocker)
reset_stub('success')
local ok_a10, id_a10 = pcall(tasks.dispatch, 'org-auth', { mode = 'hermetic' })
local job_a10 = ok_a10 and id_a10 and tasks.job(id_a10)
check(
    'unwritable doc root is non-fatal',
    'adversarial',
    ok_a10 and job_a10 ~= nil and job_a10.status == 'done' and #STUB.notifies > 0
)
os.remove(blocker)

-- ============================ summary ============================
print(string.format('validation=%d adversarial=%d failures=%d', counts.validation, counts.adversarial, #failures))
assert(counts.validation == 10, 'expected 10 validation cases, got ' .. counts.validation)
assert(counts.adversarial == 10, 'expected 10 adversarial cases, got ' .. counts.adversarial)
if #failures > 0 then
    print('FAILURES:')
    for _, f in ipairs(failures) do
        print('  ' .. f)
    end
    os.exit(1)
end
print('sf_tasks: 20/20 checks passed (10 validation + 10 adversarial)')
