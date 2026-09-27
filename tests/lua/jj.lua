-- tests/lua/jj.lua
-- Balanced suite for the jj module: exactly half adversarial and half
-- validation (7 checks each, 14 total). Run from the repo root with the
-- FULL config (never -u NONE, never --clean):
--   ~/workspace/tools/neovim-nightly/bin/nvim --headless -i NONE \
--     -u ~/workspace/repos/diver/init.lua -l tests/lua/jj.lua
-- Exit 0 when every check behaves, 1 otherwise. Report goes to
-- $JJ_REPORT (default /tmp/jj_report.txt).
-- jj is absent on the test machine: a fake `jj` on PATH answers read-only
-- and write probes from canned fixtures; a bogus binary name exercises the
-- graceful "unavailable" paths. The fake repo presence is gated on the
-- JJ_FAKE_REPO env var; the fake signing answers on JJ_FAKE_SIGNING.
local report_path = os.getenv('JJ_REPORT') or '/tmp/jj_report.txt'
local log_lines = {}
local function emit(line)
    log_lines[#log_lines + 1] = line
end
local adv_passed, adv_failed = 0, 0
local val_passed, val_failed = 0, 0
local function adv_check(cond, msg)
    if cond then
        adv_passed = adv_passed + 1
        emit('ok [A] - ' .. msg)
    else
        adv_failed = adv_failed + 1
        emit('NOT OK [A] - ' .. msg)
    end
end
local function val_check(cond, msg)
    if cond then
        val_passed = val_passed + 1
        emit('ok [V] - ' .. msg)
    else
        val_failed = val_failed + 1
        emit('NOT OK [V] - ' .. msg)
    end
end

local jj = require('jj')

local EXPECTED_COMMANDS = {
    'Jj',
    'JjDocs',
    'JjValidate',
    'JjUpdateCheck',
}

local STATUS_FIXTURE = [[Working copy : testuser@fake
Parent commit : zzz00000 empty (no description set)
The working copy is clean
]]
local LOG_FIXTURE = [[@  kkk11111 2026-09-27 10:00 testuser@fake
│  working copy (@)
◉  yyy22222 2026-09-26 09:00 testuser@fake
│  second commit
◉  xxx33333 2026-09-25 08:00 testuser@fake
   first commit
]]
local DIFF_FIXTURE = [[Modified regular file README.md:
--- a/README.md
+++ b/README.md
@@ -1,1 +1,2 @@
 line one
+line two
]]

local fakebin = '/tmp/jj_fakebin'
local saved_path = vim.env.PATH or ''
vim.env.PATH = fakebin .. ':' .. saved_path
local function write_file(path, text)
    local f = io.open(path, 'w')
    assert(f ~= nil, 'cannot write ' .. path)
    f:write(text)
    f:close()
end
os.execute('mkdir -p ' .. fakebin)
write_file(
    fakebin .. '/jj',
    [=[
#!/bin/sh
if [ "$1" = "--version" ]; then printf 'jj 0.45.1\n'; exit 0; fi
# Skip global flags like --color=never / --no-pager before dispatching.
while [ $# -gt 0 ]; do
  case "$1" in
    --*) shift ;;
    *) break ;;
  esac
done
cmd="$1"; shift
in_repo() {
  if [ -z "$JJ_FAKE_REPO" ]; then
    printf 'Error: There is no jj repo in "%s"\n' "$PWD" >&2
    exit 1
  fi
}
case "$cmd" in
  root) in_repo; printf '%s\n' "$JJ_FAKE_REPO" ;;
  status) in_repo; printf '%s' "$JJ_FAKE_STATUS" ;;
  log) in_repo; printf '%s' "$JJ_FAKE_LOG" ;;
  diff) in_repo; printf '%s' "$JJ_FAKE_DIFF" ;;
  new) in_repo; printf 'Created new change (args: %s)\n' "$*" ;;
  squash) in_repo; printf 'Squashed working copy changes into parent\n' ;;
  config)
    if [ -n "$JJ_FAKE_SIGNING" ]; then
      case "$1 $2" in
        'get signing.backend') printf 'gpg\n' ;;
        'get signing.behavior') printf 'own\n' ;;
        *) exit 1 ;;
      esac
    else
      exit 1
    fi
    ;;
  *) printf 'unknown fake command: %s\n' "$cmd" >&2; exit 1 ;;
esac
exit 0
]=]
)
os.execute('chmod +x ' .. fakebin .. '/jj')
-- The fake `jj root` reports this dir, so it must exist: run_jj spawns
-- with cwd=root, and a missing dir fails the spawn (as it would for a
-- stale real root).
local fake_repo = '/tmp/jj_fake_repo'
os.execute('mkdir -p ' .. fake_repo)

local function chooser(choice)
    return function(_items, _opts, on_choice)
        on_choice(choice)
    end
end

local function base_setup(overrides)
    local base = { jj_bin = 'jj' }
    if overrides ~= nil then
        for key, value in pairs(overrides) do
            base[key] = value
        end
    end
    jj.setup(base)
end

local function with_repo(fn)
    vim.env.JJ_FAKE_REPO = '/tmp/jj_fake_repo'
    vim.env.JJ_FAKE_STATUS = STATUS_FIXTURE
    vim.env.JJ_FAKE_LOG = LOG_FIXTURE
    vim.env.JJ_FAKE_DIFF = DIFF_FIXTURE
    vim.env.JJ_FAKE_SIGNING = '1'
    local ok, err = pcall(fn)
    vim.env.JJ_FAKE_REPO = nil
    vim.env.JJ_FAKE_STATUS = nil
    vim.env.JJ_FAKE_LOG = nil
    vim.env.JJ_FAKE_DIFF = nil
    vim.env.JJ_FAKE_SIGNING = nil
    return ok, err
end

local function capture_notify(fn)
    local captured = {}
    local orig_notify = vim.notify
    vim.notify = function(msg, ...)
        captured[#captured + 1] = tostring(msg)
        return orig_notify(msg, ...)
    end
    local ok, err = pcall(fn)
    vim.notify = orig_notify
    return ok, err, table.concat(captured, '\n')
end

local function float_text(buf_name)
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local ok, name = pcall(vim.api.nvim_buf_get_name, buf)
        if ok and name == buf_name then
            return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
        end
    end
    return nil
end

-- Validation ------------------------------------------------------------
do
    -- setup() already ran at boot (init.lua requires jj eagerly); it must
    -- be idempotent and leave exactly the 4 commands.
    base_setup()
    jj.setup()
    local commands = vim.api.nvim_get_commands({})
    local count = 0
    local all_present = true
    for _, name in ipairs(EXPECTED_COMMANDS) do
        if commands[name] ~= nil then
            count = count + 1
        else
            all_present = false
        end
    end
    val_check(
        all_present and count == 4,
        'setup registers :Jj :JjDocs :JjValidate :JjUpdateCheck; idempotent, still exactly 4'
    )
end

do
    local keys = {
        'confirm_writes',
        'docs_url',
        'float_height',
        'float_width',
        'jj_bin',
        'jj_version_min',
        'known_upstream_version',
        'log_limit',
        'select_impl',
        'timeout_ms',
        'update_repo',
    }
    local explicit = true
    for _, key in ipairs(keys) do
        if jj.config[key] == nil and jj.default_config[key] ~= nil then
            explicit = false
        end
    end
    base_setup({ float_width = 80, confirm_writes = false })
    local override_ok = jj.config.float_width == 80 and jj.config.confirm_writes == false
    base_setup()
    local restored = jj.config.float_width == 100 and jj.config.confirm_writes == true
    local defaults_intact = jj.default_config.float_width == 100 and jj.default_config.jj_bin == 'jj'
    local facts_ok = jj.config.docs_url == 'https://docs.jj-vcs.dev/latest'
        and jj.config.update_repo == 'jj-vcs/jj'
        and jj.config.known_upstream_version == '0.45.1'
        and jj.config.jj_version_min == '0.44.0'
        and jj.JJ_VERSION_MIN == '0.44.0'
    val_check(
        explicit and override_ok and restored and defaults_intact and facts_ok,
        'config fully explicit; overrides apply, nil restores, default_config never mutated; '
            .. 'verified facts: docs.jj-vcs.dev/latest, jj-vcs/jj, 0.45.1 known upstream, 0.44.0 minimum'
    )
end

do
    -- Fake-jj end-to-end: repo detection, the three read-only floats, and
    -- confirmed new/squash writes.
    local ok = with_repo(function()
        base_setup({ select_impl = chooser(1) })
        local root, root_err = jj.repo_root()
        jj.cmd_jj({ fargs = { 'st' } })
        jj.cmd_jj({ fargs = { 'log' } })
        jj.cmd_jj({ fargs = { 'diff' } })
        local st_ok, _, st_note = capture_notify(function()
            jj.cmd_jj({ fargs = { 'new' } })
        end)
        local sq_ok, _, sq_note = capture_notify(function()
            jj.cmd_jj({ fargs = { 'squash' } })
        end)
        local st_text = float_text('jj://st')
        local log_text = float_text('jj://log')
        local diff_text = float_text('jj://diff')
        assert(root_err == nil and root == '/tmp/jj_fake_repo', 'repo_root must report the fake root')
        assert(jj.in_repo(), 'in_repo must be true inside the fake repo')
        assert(st_text ~= nil and st_text:find('The working copy is clean', 1, true) ~= nil, 'st float shows status')
        assert(log_text ~= nil and log_text:find('second commit', 1, true) ~= nil, 'log float shows log')
        assert(diff_text ~= nil and diff_text:find('line two', 1, true) ~= nil, 'diff float shows diff')
        assert(st_ok and st_note:find('Created new change', 1, true) ~= nil, 'new writes behind confirm')
        assert(sq_ok and sq_note:find('Squashed working copy', 1, true) ~= nil, 'squash writes behind confirm')
    end)
    base_setup()
    val_check(
        ok,
        'fake jj end-to-end: repo_root/in_repo ok; st/log/diff floats show fixtures; '
            .. 'new+squash run after confirm and notify their results'
    )
end

do
    -- :JjValidate against the fake: binary, repo, and signing all ok.
    local ok = with_repo(function()
        base_setup()
        local checks = jj.checks()
        local by_name = {}
        local vocab_ok = true
        for _, check in ipairs(checks) do
            by_name[check.name] = check
            if check.status ~= 'ok' and check.status ~= 'below minimum' and check.status ~= 'unavailable' then
                vocab_ok = false
            end
        end
        assert(vocab_ok, 'every status must be in the check vocabulary')
        assert(by_name['jj'] ~= nil and by_name['jj'].status == 'ok', 'jj binary ok at 0.45.1')
        assert(by_name['repo'] ~= nil and by_name['repo'].status == 'ok', 'repo ok')
        assert(by_name['signing'] ~= nil and by_name['signing'].status == 'ok', 'signing ok')
        assert(by_name['signing'].detail:find('backend=gpg', 1, true) ~= nil, 'signing detail names gpg backend')
        assert(#checks == 3, 'exactly 3 checks')
    end)
    base_setup()
    val_check(
        ok,
        ':JjValidate: fake 0.45.1 meets the 0.44.0 floor, repo detected, '
            .. 'signing.backend=gpg reported (reported, not enforced); 3 checks, valid vocabulary'
    )
end

do
    local exceed72, err72 = jj.check_message_lines(string.rep('a', 72))
    local exceed73, err73 = jj.check_message_lines('short\n' .. string.rep('b', 73) .. '\ntiny')
    local exceed_multi, errm = jj.check_message_lines('a\n' .. string.rep('c', 80) .. '\nok\n' .. string.rep('d', 75))
    local exceed_empty, erre = jj.check_message_lines('')
    val_check(
        err72 == nil
            and exceed72 ~= nil
            and #exceed72 == 0
            and err73 == nil
            and exceed73 ~= nil
            and #exceed73 == 1
            and exceed73[1].lnum == 2
            and exceed73[1].len == 73
            and errm == nil
            and exceed_multi ~= nil
            and #exceed_multi == 2
            and exceed_multi[1].lnum == 2
            and exceed_multi[2].lnum == 4
            and erre == nil
            and exceed_empty ~= nil
            and #exceed_empty == 0,
        'check_message_lines: 72 cols pass, a 73-col line 2 flagged with length, '
            .. 'two overlong lines reported with correct lnums, empty message clean'
    )
end

do
    val_check(
        jj.package_for_manager('pacman') == 'jujutsu'
            and jj.package_for_manager('apt') == 'jujutsu'
            and jj.package_for_manager('dnf') == 'jujutsu'
            and jj.package_for_manager('brew') == 'jj'
            and jj.package_for_manager(nil) == 'jujutsu'
            and jj.package_for_manager('unknown-pm') == 'jujutsu',
        'package_for_manager: pacman/apt/dnf/nil/unknown -> jujutsu, brew -> jj'
    )
end

do
    local empty_lead = jj.complete_subcommand('')
    local s_lead = jj.complete_subcommand('s')
    local x_lead = jj.complete_subcommand('zzz')
    local specs = with_repo(function()
        base_setup()
        local s = jj.update_specs()
        assert(#s == 1, 'exactly one update spec')
        assert(s[1].repo == 'jj-vcs/jj', 'canonical upstream repo')
        assert(s[1].known_upstream_version == '0.45.1', 'verified recent release tag')
        assert(s[1].current_version == '0.45.1', 'fake binary version parsed')
        assert(s[1].migrations[1].description:find('[template]', 1, true) ~= nil, 'migration clearly template-marked')
    end)
    base_setup()
    local function same(a, b)
        if #a ~= #b then
            return false
        end
        for i = 1, #a do
            if a[i] ~= b[i] then
                return false
            end
        end
        return true
    end
    val_check(
        specs
            and same(empty_lead, { 'st', 'log', 'diff', 'new', 'squash' })
            and same(s_lead, { 'st', 'squash' })
            and #x_lead == 0,
        ':Jj subcommand completion: empty lead -> all five, "s" -> st+squash, no-match -> empty; '
            .. 'update_specs: jj-vcs/jj, 0.45.1 known upstream, template-marked migrations'
    )
end

-- Adversarial -----------------------------------------------------------
adv_check(
    not pcall(jj.setup, 'nope')
        and not pcall(jj.setup, { float_width = 'wide' })
        and not pcall(jj.setup, { confirm_writes = 42 })
        and not pcall(jj.setup, { select_impl = 'x' })
        and not pcall(jj.setup, { jj_bin = '' })
        and not pcall(jj.setup, { jj_bin = '   ' })
        and not pcall(jj.setup, { timeout_ms = 'soon' })
        and not pcall(jj.setup, { update_repo = '' }),
    'setup() rejects a non-table config, a mistyped float_width, a non-boolean confirm_writes, '
        .. 'a non-function select_impl, a blank/whitespace jj_bin, a mistyped timeout_ms, '
        .. 'and a blank update_repo'
)

do
    -- Outside a jj repo (JJ_FAKE_REPO unset): plain "not a jj repo" reports,
    -- never errors; jj and git state are never inferred from each other.
    base_setup()
    vim.env.JJ_FAKE_REPO = nil
    local root, root_err = jj.repo_root()
    local in_repo = jj.in_repo()
    local st_ok, _, st_note = capture_notify(function()
        jj.cmd_jj({ fargs = { 'st' } })
    end)
    local sq_ok, _, sq_note = capture_notify(function()
        jj.cmd_jj({ fargs = { 'squash' } })
    end)
    base_setup()
    adv_check(
        root == nil
            and type(root_err) == 'string'
            and root_err:find('not inside a jj repo', 1, true) ~= nil
            and in_repo == false
            and st_ok
            and st_note:find('not inside a jj repo', 1, true) ~= nil
            and sq_ok
            and sq_note:find('not inside a jj repo', 1, true) ~= nil,
        'outside a jj repo: repo_root nil + plain "not inside a jj repo", in_repo false, '
            .. ':Jj st and :Jj squash notify instead of erroring (no git inference)'
    )
end

do
    -- jj binary absent: every probe says "unavailable", never an error.
    base_setup({ jj_bin = 'definitely-not-jj-xyz' })
    local result, run_err = jj.run_jj({ 'root' }, {})
    local root, root_err = jj.repo_root()
    local checks_ok, checks = pcall(jj.checks)
    local vocab_ok = true
    local bin_check_ok = false
    if checks_ok then
        for _, check in ipairs(checks) do
            if check.status ~= 'ok' and check.status ~= 'below minimum' and check.status ~= 'unavailable' then
                vocab_ok = false
            end
        end
        bin_check_ok = checks[1] ~= nil
            and checks[1].name == 'definitely-not-jj-xyz'
            and checks[1].status == 'unavailable'
    end
    local st_ok, _, st_note = capture_notify(function()
        jj.cmd_jj({ fargs = { 'st' } })
    end)
    base_setup()
    adv_check(
        result == nil
            and type(run_err) == 'string'
            and run_err:find('unavailable on PATH', 1, true) ~= nil
            and root == nil
            and root_err == run_err
            and checks_ok
            and vocab_ok
            and bin_check_ok
            and st_ok
            and st_note:find('unavailable on PATH', 1, true) ~= nil,
        'missing jj binary: run_jj nil + unavailable-on-PATH, repo_root surfaces it, '
            .. 'checks() never throws and marks the binary unavailable, :Jj st notifies plainly'
    )
end

do
    -- new/squash confirm paths: cancel runs nothing; confirm_writes=false
    -- skips the prompt; extra args pass through to the write.
    local ok = with_repo(function()
        base_setup({ select_impl = chooser(nil) })
        local c_ok, _, c_note = capture_notify(function()
            jj.cmd_jj({ fargs = { 'new' } })
        end)
        assert(c_ok and c_note:find('cancelled', 1, true) ~= nil, 'cancel must notify and run nothing')
        base_setup({ confirm_writes = false })
        local d_ok, _, d_note = capture_notify(function()
            jj.cmd_jj({ fargs = { 'new', '-m', 'extra args pass' } })
        end)
        assert(d_ok and d_note:find('extra args pass', 1, true) ~= nil, 'passthrough args reach jj new')
        assert(d_note:find('Created new change', 1, true) ~= nil, 'no-confirm new runs directly')
    end)
    base_setup()
    adv_check(
        ok,
        'confirm cancel runs nothing and notifies "cancelled"; '
            .. 'confirm_writes=false skips the prompt; extra args pass through to the write'
    )
end

do
    -- check_message_lines adversarial: non-strings and oversized input
    -- return nil+err, never throw.
    local cases = { nil, 123, true, {} }
    local all_ok = true
    for _, bad in ipairs(cases) do
        local ok, exceed, err = pcall(jj.check_message_lines, bad)
        if not (ok and exceed == nil and type(err) == 'string') then
            all_ok = false
        end
    end
    local big = string.rep('x', 65537)
    local ok2, exceed2, err2 = pcall(jj.check_message_lines, big)
    adv_check(
        all_ok and ok2 and exceed2 == nil and type(err2) == 'string' and err2:find('MESSAGE_BYTES_MAX', 1, true) ~= nil,
        'check_message_lines(nil/123/true/{}) returns nil+err, never throws; '
            .. 'oversized message refused with nil+err naming MESSAGE_BYTES_MAX'
    )
end

do
    -- trim_output bounds; unknown :Jj subcommand reports plainly.
    local big = {}
    for i = 1, 5000 do
        big[i] = 'line ' .. i
    end
    local kept = jj.trim_output(big)
    local kept_nil = jj.trim_output(nil)
    local kept_str = jj.trim_output('nope')
    local u_ok, _, u_note = capture_notify(function()
        base_setup()
        jj.cmd_jj({ fargs = { 'bogus' } })
    end)
    local n_ok, _, n_note = capture_notify(function()
        jj.cmd_jj({})
    end)
    local m_ok, _, m_note = capture_notify(function()
        jj.cmd_jj({ fargs = 'not-a-table' })
    end)
    adv_check(
        #kept == 4000
            and kept[4000] == 'line 4000'
            and #kept_nil == 0
            and #kept_str == 0
            and u_ok
            and u_note:find('unknown subcommand "bogus"', 1, true) ~= nil
            and u_note:find('st | log | diff | new | squash', 1, true) ~= nil
            and n_ok
            and n_note:find('subcommand required', 1, true) ~= nil
            and m_ok
            and m_note:find('subcommand required', 1, true) ~= nil,
        'trim_output: 5000 lines -> 4000 (float bound), nil/string -> empty, never throws; '
            .. 'unknown subcommand names itself + the valid set; missing/mistyped args ask for a subcommand'
    )
end

do
    -- Signing unconfigured: reported as unavailable (report, don't
    -- enforce), never an error.
    local ok = with_repo(function()
        vim.env.JJ_FAKE_SIGNING = nil
        base_setup()
        local checks = jj.checks()
        local signing = nil
        for _, check in ipairs(checks) do
            if check.name == 'signing' then
                signing = check
            end
        end
        assert(signing ~= nil, 'signing check must exist')
        assert(signing.status == 'unavailable', 'unconfigured signing is unavailable')
        assert(signing.detail:find('backend=gpg', 1, true) ~= nil, 'detail still references his config.toml')
    end)
    base_setup()
    adv_check(
        ok,
        'unconfigured signing reported as unavailable (detail references his config.toml), '
            .. 'never enforced as an error'
    )
end

-- Restore the world: default config, original PATH, tmp files gone.
base_setup()
vim.env.PATH = saved_path
os.remove(fakebin .. '/jj')
os.execute('rmdir ' .. fakebin .. ' 2>/dev/null')
os.execute('rmdir ' .. fake_repo .. ' 2>/dev/null')

emit(string.format('adversarial: %d passed, %d failed', adv_passed, adv_failed))
emit(string.format('validation: %d passed, %d failed', val_passed, val_failed))
local f = io.open(report_path, 'w')
assert(f ~= nil, 'cannot open report path ' .. report_path)
f:write(table.concat(log_lines, '\n') .. '\n')
f:close()
os.exit((adv_failed == 0 and val_failed == 0) and 0 or 1)
