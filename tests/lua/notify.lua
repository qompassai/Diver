-- tests/lua/notify.lua
-- Balanced suite for the notify module: exactly half adversarial and half
-- validation (7 checks each, 14 total). Run from the repo root with the
-- FULL config (never -u NONE, never --clean):
--   ~/workspace/tools/neovim-nightly/bin/nvim --headless -i NONE \
--     -u ~/workspace/repos/diver/init.lua -l tests/lua/notify.lua
-- Exit 0 when every check behaves, 1 otherwise. Report goes to
-- $NOTIFY_REPORT (default /tmp/notify_report.txt).
-- A fake `notify-send` on PATH logs every argv it receives to
-- $NOTIFY_FAKE_LOG and exits $NOTIFY_FAKE_EXIT (default 0): no real
-- desktop toast ever fires. Threshold crossings are driven by the
-- clock_impl seam (a mutable counter), never by real time.
local report_path = os.getenv('NOTIFY_REPORT') or '/tmp/notify_report.txt'
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

local notify = require('tools.notify')

local fakebin = '/tmp/notify_fakebin'
local fake_log = '/tmp/notify_fake.log'
local saved_path = vim.env.PATH or ''
local saved_fake_exit = vim.env.NOTIFY_FAKE_EXIT

local function write_file(path, text)
    local f = io.open(path, 'w')
    assert(f ~= nil, 'cannot write ' .. path)
    f:write(text)
    f:close()
end
os.execute('mkdir -p ' .. fakebin)
write_file(
    fakebin .. '/notify-send',
    [=[
#!/bin/sh
log="${NOTIFY_FAKE_LOG:-/tmp/notify_fake.log}"
printf '%s\n' "$*" >> "$log"
exit "${NOTIFY_FAKE_EXIT:-0}"
]=]
)
os.execute('chmod +x ' .. fakebin .. '/notify-send')
vim.env.PATH = fakebin .. ':' .. saved_path
vim.env.NOTIFY_FAKE_LOG = fake_log

local function clear_log()
    os.remove(fake_log)
end
local function read_log()
    local f = io.open(fake_log, 'r')
    if f == nil then
        return ''
    end
    local text = f:read('*a') or ''
    f:close()
    return text
end

-- Mutable injected clock; the module reads it through M.now_ms().
local clock_now = 0

local function test_setup(overrides)
    local base = {
        clock_impl = function()
            return clock_now
        end,
        notify_send_bin = 'notify-send',
        system_backend_enabled = true,
        threshold_ms = 5000,
        timeout_ms = 3000,
    }
    if overrides ~= nil then
        for key, value in pairs(overrides) do
            base[key] = value
        end
    end
    notify.setup(base)
end

-- Capture vim.notify calls as { msg, level } records.
local function capture_notify(fn)
    local captured = {}
    local orig_notify = vim.notify
    vim.notify = function(msg, level, ...)
        captured[#captured + 1] = { msg = tostring(msg), level = level }
        return orig_notify(msg, level, ...)
    end
    local ok, err = pcall(fn)
    vim.notify = orig_notify
    return ok, err, captured
end

local function msgs(captured)
    local parts = {}
    for _, record in ipairs(captured) do
        parts[#parts + 1] = record.msg
    end
    return table.concat(parts, '\n')
end

-- Adversarial ---------------------------------------------------------
do
    -- Bad wrap opts raise before anything fires: missing label, zero
    -- threshold, non-function on_done.
    local ok1 = pcall(notify.wrap, {})
    local ok2 = pcall(notify.wrap, { label = 'x', threshold_ms = 0 })
    local ok3 = pcall(notify.wrap, { label = 'x', on_done = 'nope' })
    adv_check(not ok1 and not ok2 and not ok3, 'wrap raises on missing label, zero threshold, and non-function on_done')
end

do
    -- Under threshold: no desktop backend, no in-editor notice above DEBUG.
    clear_log()
    clock_now = 0
    test_setup()
    local _, _, captured = capture_notify(function()
        local done = notify.wrap({ label = 'compile', threshold_ms = 5000 })
        clock_now = 4999
        local notified, reason = done(0)
        assert(notified == false and reason == 'below threshold', 'expected silent below threshold')
    end)
    local debug_only = true
    for _, record in ipairs(captured) do
        if record.level ~= vim.log.levels.DEBUG then
            debug_only = false
        end
    end
    adv_check(
        read_log() == '' and debug_only,
        'under threshold: fake notify-send untouched; only a DEBUG-level vim.notify fires'
    )
end

do
    -- Exclusions: literal substring match; magic chars stay literal.
    clear_log()
    clock_now = 0
    test_setup({ exclude_patterns = { 'secret-build', 'a.b' } })
    local _, _, captured1 = capture_notify(function()
        local done = notify.wrap({ label = 'run secret-build now', threshold_ms = 1000 })
        clock_now = 65000
        local notified, reason = done(0)
        assert(notified == false and reason == 'excluded', 'expected exclusion')
    end)
    clock_now = 0
    local _, _, captured2 = capture_notify(function()
        local done = notify.wrap({ label = 'axb', threshold_ms = 1000 })
        clock_now = 65000
        local notified, reason = done(0)
        assert(notified == true and reason == 'notified', 'plain "a.b" must not match "axb"')
    end)
    test_setup()
    adv_check(
        #captured1 == 0
            and #captured2 == 1
            and msgs(captured2):find('Done in', 1, true) ~= nil
            and read_log():find('secret%-build') == nil,
        'excluded label stays silent over threshold; "a.b" does not match "axb" (plain search)'
    )
end

do
    -- Bogus notify-send binary: vim.notify still fires, never an error.
    clear_log()
    clock_now = 0
    test_setup({ notify_send_bin = 'definitely-not-notify-send-xyz' })
    local _, _, captured = capture_notify(function()
        local done = notify.wrap({ label = 'backup', threshold_ms = 1000 })
        clock_now = 65000
        local notified, reason = done(0)
        assert(notified == true and reason == 'notified', 'expected notification despite missing backend')
    end)
    test_setup()
    adv_check(
        msgs(captured):find('Done in 1m 5s', 1, true) ~= nil and read_log() == '',
        'absent notify-send: in-editor notice still fires, no error, nothing logged'
    )
end

do
    -- Disabled system backend: desktop side skipped, vim side unaffected.
    clear_log()
    clock_now = 0
    test_setup({ system_backend_enabled = false })
    local _, _, captured = capture_notify(function()
        local done = notify.wrap({ label = 'backup', threshold_ms = 1000 })
        clock_now = 65000
        done(0)
    end)
    test_setup()
    adv_check(
        read_log() == '' and msgs(captured):find('Done in 1m 5s', 1, true) ~= nil,
        'system_backend_enabled=false: vim.notify fires, no notify-send argv logged'
    )
end

do
    -- run() with a string argv: nil+err, no wrap, no notifications.
    clear_log()
    clock_now = 0
    test_setup()
    local _, _, captured = capture_notify(function()
        local result, err = notify.run('make test', { label = 'make test' })
        assert(result == nil and err ~= nil and err:find('argv', 1, true) ~= nil, 'expected argv rejection')
    end)
    local log_after_reject = read_log()
    -- run() on an unspawnable binary: nil+err, but the threshold still
    -- fires the notice (best-effort, exit unknown). The clock ticks on
    -- every read so wrap()->done() inside run() spans the threshold.
    clear_log()
    local tick = 0
    notify.setup({
        clock_impl = function()
            tick = tick + 1000
            return tick
        end,
        notify_send_bin = 'notify-send',
        system_backend_enabled = true,
        threshold_ms = 1000,
        timeout_ms = 3000,
    })
    local _, _, captured2 = capture_notify(function()
        local result, err = notify.run({ 'definitely-not-a-binary-xyz' }, {
            label = 'missing',
            threshold_ms = 1000,
        })
        assert(result == nil and err ~= nil, 'expected spawn failure')
    end)
    test_setup()
    local m1 = msgs(captured)
    local m2 = msgs(captured2)
    adv_check(
        m1 == '' and log_after_reject == '' and m2:find('Failed (-1)', 1, true) ~= nil,
        'run rejects string argv silently; unspawnable binary returns nil+err and still ' .. 'notifies with exit (-1)'
    )
end

do
    -- notify-send exits 1: best-effort means vim side still reports, no error.
    clear_log()
    clock_now = 0
    vim.env.NOTIFY_FAKE_EXIT = '1'
    test_setup()
    local info
    local _, _, captured = capture_notify(function()
        local done = notify.wrap({
            label = 'backup',
            threshold_ms = 1000,
            on_done = function(result)
                info = result
            end,
        })
        clock_now = 65000
        local notified, reason = done(0)
        assert(notified == true and reason == 'notified', 'vim side must still fire')
    end)
    vim.env.NOTIFY_FAKE_EXIT = saved_fake_exit
    test_setup()
    adv_check(
        info ~= nil
            and info.system_notified == false
            and info.system_note:find('exited 1', 1, true) ~= nil
            and msgs(captured):find('Done in 1m 5s', 1, true) ~= nil,
        'failing notify-send (exit 1): still (true, "notified"); on_done records system_notified=false'
    )
end

-- Validation ----------------------------------------------------------
do
    -- setup() is idempotent: exactly the four commands, config rebuilt.
    test_setup()
    notify.setup()
    local commands = vim.api.nvim_get_commands({})
    local expected = { NotifyDocs = true, NotifyTest = true, NotifyUpdateCheck = true, NotifyValidate = true }
    local found = 0
    for name, _ in pairs(expected) do
        if commands[name] ~= nil then
            found = found + 1
        end
    end
    local defaults_pristine = notify.default_config.threshold_ms == 5000
        and notify.default_config.notify_send_bin == 'notify-send'
        and notify.config ~= notify.default_config
    val_check(
        found == 4 and defaults_pristine,
        'setup is idempotent: exactly NotifyDocs/NotifyTest/NotifyUpdateCheck/NotifyValidate; '
            .. 'M.config rebuilt without mutating M.default_config'
    )
end

do
    -- Default config keys are explicit and alphabetical.
    local keys = {}
    for key, _ in pairs(notify.default_config) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    local expected = {
        'below_threshold_level',
        'clock_impl',
        'config_version',
        'duration_format',
        'exclude_patterns',
        'notify_send_bin',
        'system_backend_enabled',
        'threshold_ms',
        'timeout_ms',
        'vim_notify_level',
    }
    local same = #keys == #expected
    if same then
        for index, key in ipairs(keys) do
            if key ~= expected[index] then
                same = false
                break
            end
        end
    end
    val_check(same, 'default_config carries exactly the 10 documented keys, alphabetical')
end

do
    -- Over threshold: vim.notify + notify-send argv with normal urgency.
    clear_log()
    clock_now = 0
    test_setup()
    local _, _, captured = capture_notify(function()
        local done = notify.wrap({ label = 'backup', threshold_ms = 60000 })
        clock_now = 65000
        local notified, reason = done(0)
        assert(notified == true and reason == 'notified', 'expected notification')
    end)
    local log = read_log()
    val_check(
        msgs(captured):find('Done in 1m 5s', 1, true) ~= nil
            and log:find('--urgency=normal', 1, true) ~= nil
            and log:find('Done in 1m 5s', 1, true) ~= nil
            and log:find('backup', 1, true) ~= nil,
        'over threshold: vim.notify shows "Done in 1m 5s"; notify-send argv logged with '
            .. '--urgency=normal, title, and label'
    )
end

do
    -- Failure path: exit != 0 escalates to critical urgency.
    clear_log()
    clock_now = 0
    test_setup()
    local _, _, captured = capture_notify(function()
        local done = notify.wrap({ label = 'backup', threshold_ms = 60000 })
        clock_now = 65000
        done(2)
    end)
    local log = read_log()
    local failed_ok = msgs(captured):find('Failed (2) after 1m 5s', 1, true) ~= nil
        and log:find('--urgency=critical', 1, true) ~= nil
    val_check(failed_ok, 'non-zero exit: "Failed (2) after 1m 5s" and --urgency=critical on the desktop argv')
end

do
    -- on_done receives the full outcome record.
    clear_log()
    clock_now = 0
    test_setup()
    local info
    local _, _, _ = capture_notify(function()
        local done = notify.wrap({
            label = 'backup',
            threshold_ms = 60000,
            on_done = function(result)
                info = result
            end,
        })
        clock_now = 65000
        done(0)
    end)
    val_check(
        info ~= nil
            and info.label == 'backup'
            and info.duration_ms == 65000
            and info.exit_code == 0
            and info.notified == true
            and info.system_notified == true
            and info.system_note == 'sent',
        'on_done info: label backup, duration_ms 65000, exit_code 0, notified, system_notified, note "sent"'
    )
end

do
    -- Cargo composition shape: done_fn accepts a JobInfo table; M.run
    -- returns the safe_exec (result, err) pair for a real quick argv.
    clear_log()
    clock_now = 0
    test_setup()
    local _, _, captured = capture_notify(function()
        local wrap = notify.wrap({ label = 'cargo test' })
        clock_now = 65000
        local notified, reason = wrap({ exit_code = 0, duration_ms = 65000 })
        assert(notified == true and reason == 'notified', 'JobInfo table must work like an exit code')
    end)
    clock_now = 0
    local result, err = notify.run({ 'true' }, { label = 'quick true', threshold_ms = 100000000 })
    val_check(
        msgs(captured):find('Done in', 1, true) ~= nil and result ~= nil and result.code == 0 and err == nil,
        'cargo-style on_exit(info) fires the notice; run({"true"}) returns result.code 0, err nil'
    )
end

do
    -- :NotifyDocs opens a float; :NotifyValidate and :NotifyUpdateCheck
    -- report through vim.notify without erroring.
    test_setup()
    vim.cmd('NotifyDocs')
    local floats = {}
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local cfg = vim.api.nvim_win_get_config(win)
        if cfg.relative ~= nil and cfg.relative ~= '' then
            floats[#floats + 1] = win
        end
    end
    for _, win in ipairs(floats) do
        vim.api.nvim_win_close(win, true)
    end
    local _, _, captured_validate = capture_notify(function()
        vim.cmd('NotifyValidate')
    end)
    local _, _, captured_update = capture_notify(function()
        vim.cmd('NotifyUpdateCheck')
    end)
    local validate_text = msgs(captured_validate)
    local has_all = validate_text:find('notify-send', 1, true) ~= nil
        and validate_text:find('threshold', 1, true) ~= nil
        and validate_text:find('dry-run', 1, true) ~= nil
    val_check(
        #floats == 1 and has_all and msgs(captured_update):find('is current', 1, true) ~= nil,
        ':NotifyDocs opens one float; :NotifyValidate reports notify-send/threshold/dry-run; '
            .. ':NotifyUpdateCheck reports the config is current'
    )
end

-- Restore the world: default config, original PATH/env, fakes gone.
test_setup()
vim.env.PATH = saved_path
vim.env.NOTIFY_FAKE_LOG = nil
vim.env.NOTIFY_FAKE_EXIT = saved_fake_exit
os.remove(fakebin .. '/notify-send')
os.execute('rmdir ' .. fakebin .. ' 2>/dev/null')
os.remove(fake_log)

emit(string.format('adversarial: %d passed, %d failed', adv_passed, adv_failed))
emit(string.format('validation: %d passed, %d failed', val_passed, val_failed))
local f = io.open(report_path, 'w')
assert(f ~= nil, 'cannot open report path ' .. report_path)
f:write(table.concat(log_lines, '\n') .. '\n')
f:close()
os.exit((adv_failed == 0 and val_failed == 0) and 0 or 1)
