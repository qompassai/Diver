-- tests/lua/pass.lua
-- Balanced suite for the pass module: exactly half adversarial and half
-- validation (7 checks each, 14 total). Run from the repo root with the
-- FULL config (never -u NONE, never --clean):
--   ~/workspace/tools/neovim-nightly/bin/nvim --headless -i NONE \
--     -u ~/workspace/repos/diver/init.lua -l tests/lua/pass.lua
-- Exit 0 when every check behaves, 1 otherwise. Report goes to
-- $PASS_REPORT (default /tmp/pass_report.txt).
-- pass is absent on the test machine: a fake `pass` on PATH answers
-- --version/ls/show/otp from canned fixtures; fake `oathtool` and `gpg`
-- cover the OTP and GPG probes; a bogus binary name exercises the
-- graceful "unavailable" paths. Nothing touches the real clipboard or a
-- real store.
local report_path = os.getenv('PASS_REPORT') or '/tmp/pass_report.txt'
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

local pass = require('pass')

-- Headless quirk (verified 2026-09-27): under the FULL config, touching the
-- real +/* registers emits a clipboard-provider message that silently
-- terminates the headless -l session with exit 0 (same class as the :echo
-- quirk; minimal configs only warn and continue). The module's contract is
-- about WHAT it writes to +/* and WHEN it clears them, so this test backs
-- vim.fn.setreg/getreg for +/* with a Lua table. The clear timer, the
-- notifications, and the register call sequences are all real.
local reg_store = {}
local orig_setreg = vim.fn.setreg
local orig_getreg = vim.fn.getreg
vim.fn.setreg = function(name, value, ...)
    if name == '+' or name == '*' then
        reg_store[name] = value
        return 0
    end
    return orig_setreg(name, value, ...)
end
vim.fn.getreg = function(name, ...)
    if name == '+' or name == '*' then
        local value = reg_store[name]
        if type(value) == 'string' then
            return value
        end
        return ''
    end
    return orig_getreg(name, ...)
end

local EXPECTED_COMMANDS = {
    'Pass',
    'PassClear',
    'PassDocs',
    'PassValidate',
    'PassUpdateCheck',
}

local LS_FIXTURE = table.concat({
    'Password Store',
    '├── bank',
    '│   └── savings',
    '├── email',
    '│   └── gmail',
    '├── README (not an entry)',
    '└── notes',
    '',
}, '\n')

local fakebin = '/tmp/pass_fakebin'
local fake_store = '/tmp/pass_fake_store'
local saved_path = vim.env.PATH or ''
vim.env.PATH = fakebin .. ':' .. saved_path
local function write_file(path, text)
    local f = io.open(path, 'w')
    assert(f ~= nil, 'cannot write ' .. path)
    f:write(text)
    f:close()
end
os.execute('mkdir -p ' .. fakebin)
os.execute('mkdir -p ' .. fake_store)
write_file(
    fakebin .. '/pass',
    [=[
#!/bin/sh
if [ "$1" = "--version" ]; then
  printf '============================================\n'
  printf '= pass: the standard unix password manager =\n'
  printf '=                  v1.7.4                  =\n'
  printf '============================================\n'
  exit 0
fi
cmd="$1"; shift
case "$cmd" in
  ls) printf '%s' "$PASS_FAKE_LS" ;;
  show)
    case "$1" in
      bank/savings) printf 's3cr3t-savings\nusername: matt\n' ;;
      email/gmail) printf 's3cr3t-gmail\n' ;;
      notes) printf 'note-body\n' ;;
      *) printf 'pass: error: %s is not in the password store.\n' "$1" >&2; exit 1 ;;
    esac
    ;;
  otp)
    case "$1" in
      bank/savings) printf '123456\n' ;;
      *) printf 'pass: error: %s has no OTP secret.\n' "$1" >&2; exit 1 ;;
    esac
    ;;
  *) printf 'unknown fake command: %s\n' "$cmd" >&2; exit 1 ;;
esac
exit 0
]=]
)
write_file(
    fakebin .. '/oathtool',
    [=[
#!/bin/sh
if [ "$1" = "--version" ]; then printf 'oathtool (OATH Toolkit) v2.6.9\n'; fi
exit 0
]=]
)
write_file(
    fakebin .. '/gpg',
    [=[
#!/bin/sh
if [ "$1 $2" = "--list-secret-keys --with-colons" ]; then
  printf 'sec:-:4096:1:ABCDEF1234567890:1234567890:::\n'
  exit 0
fi
exit 1
]=]
)
os.execute('chmod +x ' .. fakebin .. '/pass ' .. fakebin .. '/oathtool ' .. fakebin .. '/gpg')
vim.env.PASS_FAKE_LS = LS_FIXTURE

-- Answers each vim.ui.select call from a queue; nil answers cancel.
local function scripted(answers)
    local index = 0
    return function(_items, _opts, on_choice)
        index = index + 1
        on_choice(answers[index])
    end
end

local function base_setup(overrides)
    local base = {
        pass_bin = 'pass',
        gpg_bin = 'gpg',
        oathtool_bin = 'oathtool',
        store_dir = fake_store,
    }
    if overrides ~= nil then
        for key, value in pairs(overrides) do
            base[key] = value
        end
    end
    pass.setup(base)
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

local function count_occurrences(haystack, needle)
    local count = 0
    local from = 1
    while true do
        local found = haystack:find(needle, from, true)
        if found == nil then
            break
        end
        count = count + 1
        from = found + 1
    end
    return count
end

local function getreg_safe(name)
    local ok, value = pcall(vim.fn.getreg, name)
    return ok and value or nil
end
local function setreg_safe(name, value)
    pcall(vim.fn.setreg, name, value)
end

-- Validation ------------------------------------------------------------
do
    -- setup() already ran at boot (init.lua requires pass eagerly); it must
    -- be idempotent and leave exactly the 5 commands.
    base_setup()
    pass.setup()
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
        all_present and count == 5,
        'setup registers :Pass :PassClear :PassDocs :PassValidate :PassUpdateCheck; ' .. 'idempotent, still exactly 5'
    )
end

do
    local keys = {
        'clear_clipboard_after_ms',
        'docs_url',
        'entry_length_max',
        'entry_pattern',
        'gpg_bin',
        'known_upstream_version',
        'oathtool_bin',
        'pass_bin',
        'pass_version_min',
        'picker_prompt',
        'select_impl',
        'store_dir',
        'timeout_ms',
        'update_repo',
    }
    local explicit = true
    for _, key in ipairs(keys) do
        if pass.config[key] == nil and pass.default_config[key] ~= nil then
            explicit = false
        end
    end
    base_setup({ timeout_ms = 5000, picker_prompt = 'pick: ' })
    local override_ok = pass.config.timeout_ms == 5000 and pass.config.picker_prompt == 'pick: '
    base_setup()
    local restored = pass.config.timeout_ms == 30000 and pass.config.picker_prompt == 'pass entry: '
    local defaults_intact = pass.default_config.timeout_ms == 30000
        and pass.default_config.pass_bin == 'pass'
        and pass.default_config.clear_clipboard_after_ms == 15000
    local facts_ok = pass.config.docs_url == 'https://www.passwordstore.org/'
        and pass.config.update_repo == 'zx2c4/password-store'
        and pass.config.known_upstream_version == '1.7.4'
        and pass.config.pass_version_min == '1.7.0'
        and pass.PASS_VERSION_MIN == '1.7.0'
        and pass.config.entry_pattern == '^[A-Za-z0-9_./-]+$'
        and pass.config.entry_length_max == 256
        and pass.config.store_dir == fake_store
    val_check(
        explicit and override_ok and restored and defaults_intact and facts_ok,
        'config fully explicit; overrides apply, nil restores, default_config never mutated; '
            .. 'verified facts: passwordstore.org docs, zx2c4/password-store, 1.7.4 known upstream, '
            .. '1.7.0 minimum, strict entry pattern, 256-char bound'
    )
end

do
    -- entry_valid accepts the plain house shapes and the length boundary.
    base_setup()
    local good = {
        'bank',
        'bank/savings',
        'email/gmail',
        'my.entry-name_2',
        string.rep('x', 256),
    }
    local all_good = true
    for _, name in ipairs(good) do
        local valid, reason = pass.entry_valid(name)
        if not valid then
            all_good = false
            emit('  rejected good name: ' .. name .. ' (' .. tostring(reason) .. ')')
        end
    end
    local first_line = pass.password_line('s3cr3t\nusername: matt\n')
    val_check(
        all_good and first_line == 's3cr3t',
        'entry_valid accepts plain names, dotted/dashed/underscored names, slash paths, '
            .. 'and the 256-char boundary; password_line keeps only the first line'
    )
end

do
    -- list_entries reconstructs full slash-paths from real `pass ls` tree
    -- output and drops the header plus pattern-failing junk lines.
    base_setup()
    local entries, list_err = pass.list_entries()
    local same = false
    if entries ~= nil then
        local want = { 'bank', 'bank/savings', 'email', 'email/gmail', 'notes' }
        same = #entries == #want
        for i = 1, #want do
            if entries[i] ~= want[i] then
                same = false
            end
        end
    end
    base_setup()
    val_check(
        list_err == nil and same,
        'list_entries: tree output -> bank, bank/savings, email, email/gmail, notes in order; '
            .. 'header and "README (not an entry)" dropped, never passed to argv'
    )
end

do
    -- End-to-end picker: entry select then "Yank password" puts the first
    -- line into + and *, and the tiny clear timer empties them with exactly
    -- one notification.
    base_setup({ clear_clipboard_after_ms = 60, select_impl = scripted({ 'bank/savings', 'Yank password' }) })
    local yanked_ok, yanked_err, yanked_notes = capture_notify(function()
        pass.cmd_pass({ fargs = {} })
        assert(getreg_safe('+') == 's3cr3t-savings', 'password must land in +')
        assert(getreg_safe('*') == 's3cr3t-savings', 'password must land in *')
        vim.wait(400)
    end)
    local cleared_plus = getreg_safe('+') == ''
    local cleared_star = getreg_safe('*') == ''
    base_setup()
    val_check(
        yanked_ok
            and yanked_notes:find('bank/savings', 1, true) ~= nil
            and yanked_notes:find('s3cr3t-savings', 1, true) == nil
            and count_occurrences(yanked_notes, 'Pass: clipboard cleared') == 1
            and cleared_plus
            and cleared_star,
        'picker e2e: Yank password sets + and * to the first line only, timer clears both '
            .. 'after 60ms with exactly one "clipboard cleared" notify; the secret never appears '
            .. 'in a notification'
            .. (yanked_err ~= nil and (' (err: ' .. tostring(yanked_err) .. ')') or '')
    )
end

do
    -- Insert-as-snippet: password lands at the cursor, registers keep
    -- their values, and no clear timer is armed (still 'KEEP' after the
    -- delay that would have fired one).
    local buf = vim.api.nvim_create_buf(false, true)
    base_setup({ clear_clipboard_after_ms = 60, select_impl = scripted({ 'bank/savings', 'Insert as snippet' }) })
    setreg_safe('+', 'KEEP')
    setreg_safe('*', 'KEEP')
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    local run_ok, run_err = pcall(function()
        pass.cmd_pass({ fargs = {} })
    end)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    vim.wait(400)
    local plus_kept = getreg_safe('+') == 'KEEP'
    local star_kept = getreg_safe('*') == 'KEEP'
    local ok = run_ok and #lines == 1 and lines[1] == 's3cr3t-savings' and plus_kept and star_kept
    vim.api.nvim_buf_delete(buf, { force = true })
    base_setup()
    val_check(
        ok,
        'insert-as-snippet: first line lands at the cursor, + and * keep their values, '
            .. 'and no clear timer fires (still KEEP after 400ms): no clipboard exposure, '
            .. 'so nothing to time out'
            .. (run_err ~= nil and (' (err: ' .. tostring(run_err) .. ')') or '')
    )
end

do
    -- :PassValidate against the fakes: binary, store, GPG probe, and the
    -- optional oathtool all ok; statuses stay in the check vocabulary.
    base_setup()
    local checks_ok, checks = pcall(pass.checks)
    local by_name = {}
    local vocab_ok = true
    if checks_ok then
        for _, check in ipairs(checks) do
            by_name[check.name] = check
            if check.status ~= 'ok' and check.status ~= 'below minimum' and check.status ~= 'unavailable' then
                vocab_ok = false
            end
        end
    end
    local specs_ok, specs = pcall(pass.update_specs)
    base_setup()
    val_check(
        checks_ok
            and vocab_ok
            and #checks == 4
            and by_name['pass'] ~= nil
            and by_name['pass'].status == 'ok'
            and by_name['pass'].detail:find('1.7.4', 1, true) ~= nil
            and by_name['store'] ~= nil
            and by_name['store'].status == 'ok'
            and by_name['gpg-agent'] ~= nil
            and by_name['gpg-agent'].status == 'ok'
            and by_name['oathtool (optional)'] ~= nil
            and by_name['oathtool (optional)'].status == 'ok'
            and specs_ok
            and #specs == 1
            and specs[1].repo == 'zx2c4/password-store'
            and specs[1].known_upstream_version == '1.7.4'
            and specs[1].current_version == '1.7.4'
            and specs[1].migrations[1].description:find('[template]', 1, true) ~= nil,
        ':PassValidate: fake 1.7.4 meets the 1.7.0 floor, store dir found, GPG probe lists '
            .. 'keys read-only, optional oathtool ok; 4 checks, valid vocabulary; '
            .. 'update_specs: zx2c4/password-store, 1.7.4 known upstream, template-marked migrations'
    )
end

-- Adversarial -----------------------------------------------------------
adv_check(
    not pcall(pass.setup, 'nope')
        and not pcall(pass.setup, { clear_clipboard_after_ms = 'soon' })
        and not pcall(pass.setup, { clear_clipboard_after_ms = 0 })
        and not pcall(pass.setup, { entry_length_max = 0 })
        and not pcall(pass.setup, { entry_pattern = '([' })
        and not pcall(pass.setup, { pass_bin = '' })
        and not pcall(pass.setup, { pass_bin = '   ' })
        and not pcall(pass.setup, { store_dir = '' })
        and not pcall(pass.setup, { select_impl = 'x' })
        and not pcall(pass.setup, { timeout_ms = 'soon' })
        and not pcall(pass.setup, { update_repo = '' }),
    'setup() rejects a non-table config, a mistyped/non-positive clear_clipboard_after_ms, '
        .. 'a non-positive entry_length_max, an invalid entry_pattern, a blank/whitespace '
        .. 'pass_bin, a blank store_dir, a non-function select_impl, a mistyped timeout_ms, '
        .. 'and a blank update_repo'
)

do
    -- entry_valid rejects metacharacters, empties, overlong names, and
    -- non-strings; choose_action refuses before any select/spawn.
    base_setup()
    local bad = {
        '',
        'a;b',
        'a|b',
        'a&b',
        '$(x)',
        '`x`',
        'a b',
        'a\nb',
        'a*b',
        '../escape',
        string.rep('x', 257),
        nil,
        42,
    }
    local all_bad = true
    for _, name in ipairs(bad) do
        local valid = pass.entry_valid(name)
        if valid then
            all_bad = false
            emit('  accepted bad name: ' .. tostring(name))
        end
    end
    local spy_called = false
    local spy = function(_items, _opts, _on_choice)
        spy_called = true
    end
    base_setup({ select_impl = spy })
    local c_ok, _, c_note = capture_notify(function()
        pass.choose_action('bad;name')
    end)
    base_setup()
    adv_check(
        all_bad and c_ok and not spy_called and c_note:find('invalid entry name', 1, true) ~= nil,
        'entry_valid rejects ; | & $() backticks spaces newlines * ../ overlong empty '
            .. 'and non-strings; choose_action("bad;name") never opens a select and never spawns'
    )
end

do
    -- pass binary absent: every probe says "unavailable", never an error.
    base_setup({ pass_bin = 'definitely-not-pass-xyz' })
    local entries, list_err = pass.list_entries()
    local retrieve_secret, retrieve_err = pass.retrieve('bank', 'show')
    local checks_ok, checks = pcall(pass.checks)
    local bin_unavailable = false
    if checks_ok then
        for _, check in ipairs(checks) do
            if check.name == 'definitely-not-pass-xyz' and check.status == 'unavailable' then
                bin_unavailable = true
            end
        end
    end
    local p_ok, _, p_note = capture_notify(function()
        pass.cmd_pass({ fargs = {} })
    end)
    local v_ok = pcall(function()
        local orig = vim.notify
        vim.notify = function() end
        pass.cmd_pass({ fargs = {} })
        vim.notify = orig
    end)
    base_setup()
    adv_check(
        entries == nil
            and type(list_err) == 'string'
            and list_err:find('unavailable on PATH', 1, true) ~= nil
            and retrieve_secret == nil
            and type(retrieve_err) == 'string'
            and checks_ok
            and bin_unavailable
            and p_ok
            and p_note:find('unavailable on PATH', 1, true) ~= nil
            and v_ok,
        'missing pass binary: list_entries/retrieve nil + unavailable-on-PATH, checks() marks '
            .. 'the binary unavailable without throwing, :Pass notifies plainly'
    )
end

do
    -- Missing store dir and missing gpg: both 'unavailable', never errors.
    base_setup({ store_dir = '/tmp/definitely-not-a-store-xyz', gpg_bin = 'definitely-not-gpg-xyz' })
    local checks_ok, checks = pcall(pass.checks)
    local store_status, gpg_status = nil, nil
    if checks_ok then
        for _, check in ipairs(checks) do
            if check.name == 'store' then
                store_status = check.status
            elseif check.name == 'gpg-agent' then
                gpg_status = check.status
            end
        end
    end
    base_setup()
    adv_check(
        checks_ok and store_status == 'unavailable' and gpg_status == 'unavailable',
        'missing store dir and missing gpg: checks() never throws; store and gpg-agent '
            .. 'report unavailable (read-only probe, nothing decrypted)'
    )
end

do
    -- Timer single-owner proof: yank, then yank-again-replacing-yank, wait
    -- past the delay; exactly 2 clears fire (never 3), and registers end
    -- empty. Teardown and :PassClear are idempotent.
    local notes
    local run_ok, run_err = pcall(function()
        local _, _, n1 = capture_notify(function()
            base_setup({ clear_clipboard_after_ms = 60, select_impl = scripted({ 'bank/savings', 'Yank password' }) })
            pass.cmd_pass({ fargs = {} })
            vim.wait(300)
            base_setup({ clear_clipboard_after_ms = 60, select_impl = scripted({ 'bank/savings', 'Yank password' }) })
            pass.cmd_pass({ fargs = {} })
            base_setup({ clear_clipboard_after_ms = 60, select_impl = scripted({ 'bank/savings', 'Yank password' }) })
            pass.cmd_pass({ fargs = {} })
            vim.wait(300)
        end)
        notes = n1
    end)
    local cleared = getreg_safe('+') == '' and getreg_safe('*') == ''
    local fires = count_occurrences(notes or '', 'Pass: clipboard cleared')
    local teardown_ok = pcall(pass.stop_clear_timer) and pcall(pass.stop_clear_timer)
    local clear_ok, _, clear_note = capture_notify(function()
        pass.cmd_clear()
    end)
    base_setup()
    adv_check(
        run_ok
            and fires == 2
            and cleared
            and teardown_ok
            and clear_ok
            and clear_note:find('Pass: clipboard cleared', 1, true) ~= nil,
        're-yank replaces the live timer (2 fires for 3 yanks, never 3); registers end empty; '
            .. 'stop_clear_timer is idempotent; :PassClear cancels and clears immediately'
            .. (run_err ~= nil and (' (err: ' .. tostring(run_err) .. ')') or '')
    )
end

do
    -- oathtool absent: the OTP action is hidden from the menu and
    -- yank_otp refuses without touching registers.
    base_setup({ oathtool_bin = 'definitely-not-oathtool-xyz' })
    local actions = pass.available_actions()
    local otp_hidden = true
    for _, action in ipairs(actions) do
        if action == 'Yank OTP' then
            otp_hidden = false
        end
    end
    setreg_safe('+', 'KEEP')
    local o_ok, _, o_note = capture_notify(function()
        pass.yank_otp('bank/savings')
    end)
    local kept = getreg_safe('+') == 'KEEP'
    base_setup()
    adv_check(
        otp_hidden and #actions == 3 and o_ok and o_note:find('oathtool is unavailable', 1, true) ~= nil and kept,
        'oathtool absent: "Yank OTP" hidden from the action menu (3 actions left); '
            .. 'yank_otp refuses plainly and leaves the registers untouched'
    )
end

do
    -- Picker cancellations run nothing; unknown entries fail plainly.
    base_setup({ clear_clipboard_after_ms = 60, select_impl = scripted({ nil }) })
    setreg_safe('+', 'KEEP')
    local c1_ok, _, c1_note = capture_notify(function()
        pass.cmd_pass({ fargs = {} })
    end)
    base_setup({ clear_clipboard_after_ms = 60, select_impl = scripted({ 'bank/savings', nil }) })
    local c2_ok, _, c2_note = capture_notify(function()
        pass.cmd_pass({ fargs = {} })
    end)
    base_setup()
    local y_ok, _, y_note = capture_notify(function()
        pass.yank_password('no/such/entry')
    end)
    local kept = getreg_safe('+') == 'KEEP'
    local both_quiet = c1_note:find('yanked', 1, true) == nil and c2_note:find('yanked', 1, true) == nil
    base_setup()
    adv_check(
        c1_ok and c2_ok and both_quiet and kept and y_ok and y_note:find('pass show failed', 1, true) ~= nil,
        'cancelled entry pick and cancelled action pick run nothing; yank on an unknown entry '
            .. 'fails plainly ("pass show failed") without touching registers'
    )
end

-- Restore the world: default config, original PATH, registers, tmp files gone.
base_setup()
vim.fn.setreg = orig_setreg
vim.fn.getreg = orig_getreg
vim.env.PATH = saved_path
vim.env.PASS_FAKE_LS = nil
os.remove(fakebin .. '/pass')
os.remove(fakebin .. '/oathtool')
os.remove(fakebin .. '/gpg')
os.execute('rmdir ' .. fakebin .. ' 2>/dev/null')
os.execute('rmdir ' .. fake_store .. ' 2>/dev/null')

emit(string.format('adversarial: %d passed, %d failed', adv_passed, adv_failed))
emit(string.format('validation: %d passed, %d failed', val_passed, val_failed))
local f = io.open(report_path, 'w')
assert(f ~= nil, 'cannot open report path ' .. report_path)
f:write(table.concat(log_lines, '\n') .. '\n')
f:close()
os.exit((adv_failed == 0 and val_failed == 0) and 0 or 1)
