-- tests/lua/tmux.lua
-- Balanced suite for the tmux module: exactly half adversarial and half
-- validation (7 checks each, 14 total). Run from the repo root with the
-- FULL config (never -u NONE, never --clean):
--   ~/workspace/tools/neovim-nightly/bin/nvim --headless -i NONE \
--     -u ~/workspace/repos/diver/init.lua -l tests/lua/tmux.lua
-- Exit 0 when every check behaves, 1 otherwise. Report goes to
-- $TMUX_REPORT (default /tmp/tmux_report.txt).
-- tmux is absent on the test machine: a fake `tmux` on PATH answers -V,
-- display-message, select-pane, new-window and split-window from canned
-- fixtures and logs every argv it receives; a bogus binary name exercises
-- the graceful "unavailable" paths. Nothing touches a real tmux server.
local report_path = os.getenv('TMUX_REPORT') or '/tmp/tmux_report.txt'
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

local tmux = require('tmux')

local fakebin = '/tmp/tmux_fakebin'
local fake_log = '/tmp/tmux_fake.log'
local saved_path = vim.env.PATH or ''
local saved_tmux_env = vim.env.TMUX
local saved_ui_open = vim.ui.open
local orig_win_in_direction = tmux.win_in_direction

local function write_file(path, text)
    local f = io.open(path, 'w')
    assert(f ~= nil, 'cannot write ' .. path)
    f:write(text)
    f:close()
end
os.execute('mkdir -p ' .. fakebin)
write_file(
    fakebin .. '/tmux',
    [=[
#!/bin/sh
log="${TMUX_FAKE_LOG:-/tmp/tmux_fake.log}"
printf '%s\n' "$*" >> "$log"
case "$1" in
  -V) printf 'tmux 3.7c\n' ;;
  display-message) printf 'fake-session\n' ;;
  select-pane|new-window|split-window) ;;
  *) printf 'unknown fake command: %s\n' "$1" >&2; exit 1 ;;
esac
exit 0
]=]
)
os.execute('chmod +x ' .. fakebin .. '/tmux')
vim.env.PATH = fakebin .. ':' .. saved_path
vim.env.TMUX_FAKE_LOG = fake_log

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
        tmux_bin = 'tmux',
        keymaps_enabled = true,
        timeout_ms = 5000,
    }
    if overrides ~= nil then
        for key, value in pairs(overrides) do
            base[key] = value
        end
    end
    tmux.setup(base)
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

local function stub_no_window()
    tmux.win_in_direction = function(_)
        return false
    end
end
local function unstub_window()
    tmux.win_in_direction = orig_win_in_direction
end

-- Adversarial ---------------------------------------------------------
do
    -- Unknown direction: (nil, err), and the fake tmux never sees a call.
    clear_log()
    stub_no_window()
    local moved, err = tmux.navigate('sideways')
    unstub_window()
    adv_check(
        moved == nil and err ~= nil and err:find('unknown direction', 1, true) ~= nil and read_log() == '',
        'unknown direction returns (nil, "unknown direction") and never shells out'
    )
end

do
    -- Floating window focused: navigation is skipped, tmux never called.
    clear_log()
    vim.env.TMUX = '/tmp/fake-tmux-socket'
    stub_no_window()
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, { relative = 'editor', width = 20, height = 5, row = 2, col = 2 })
    local moved, err = tmux.navigate('left')
    vim.api.nvim_win_close(win, true)
    unstub_window()
    vim.env.TMUX = saved_tmux_env
    adv_check(
        moved == false and err ~= nil and err:find('floating', 1, true) ~= nil and read_log() == '',
        'floating window focused: navigate skips with a floating notice and never shells out'
    )
end

do
    -- Not inside tmux: no shell-out even though the binary is present.
    clear_log()
    vim.env.TMUX = nil
    stub_no_window()
    local moved, err = tmux.navigate('right')
    unstub_window()
    adv_check(
        moved == false and err ~= nil and err:find('not inside tmux', 1, true) ~= nil and read_log() == '',
        'outside tmux: navigate refuses without shelling out (binary present but $TMUX unset)'
    )
end

do
    -- Bogus binary: navigate and apply_layout report unavailable, no error.
    clear_log()
    vim.env.TMUX = '/tmp/fake-tmux-socket'
    stub_no_window()
    base_setup({ tmux_bin = 'definitely-not-tmux-xyz' })
    local moved, nav_err = tmux.navigate('up')
    local laid, layout_err = tmux.apply_layout('dev')
    unstub_window()
    vim.env.TMUX = saved_tmux_env
    base_setup()
    adv_check(
        moved == false
            and nav_err ~= nil
            and nav_err:find('unavailable', 1, true) ~= nil
            and laid == nil
            and layout_err ~= nil
            and layout_err:find('unavailable', 1, true) ~= nil,
        'bogus tmux_bin: navigate and apply_layout report "unavailable", never an error'
    )
end

do
    -- Unknown layout and invalid layout shapes fail plainly.
    clear_log()
    local ok1, err1 = tmux.apply_layout('no-such-layout')
    base_setup({
        layouts = {
            bad = {
                { window = 'x', splits = { { direction = 'horizontal', percent = 0 } } },
            },
        },
    })
    local ok2, err2 = tmux.validate_layout('bad')
    base_setup()
    adv_check(
        ok1 == nil
            and err1 ~= nil
            and err1:find('unknown layout', 1, true) ~= nil
            and ok2 == false
            and err2 ~= nil
            and err2:find('percent', 1, true) ~= nil,
        'unknown layout name and out-of-range split percent fail plainly with reasons'
    )
end

do
    -- Keymap collision: the core <C-h> mapping wins; tmux skips with notice.
    local _, _, note = capture_notify(function()
        base_setup()
    end)
    local map = vim.fn.maparg('<C-h>', 'n', false, true)
    local desc = type(map) == 'table' and map.desc or ''
    adv_check(
        note:find('already mapped', 1, true) ~= nil
            and note:find('<C-h>', 1, true) ~= nil
            and desc:find('^Tmux: navigate', 1) ~= 1,
        'collision: setup notifies about the occupied <C-h> and leaves the existing mapping in place'
    )
end

do
    -- :TmuxLayout refuses outside tmux even with a working binary.
    clear_log()
    vim.env.TMUX = nil
    base_setup()
    local ok, err = tmux.apply_layout('dev')
    vim.env.TMUX = saved_tmux_env
    adv_check(
        ok == nil and err ~= nil and err:find('not inside tmux', 1, true) ~= nil and read_log() == '',
        'apply_layout outside tmux refuses before any new-window/split-window call'
    )
end

-- Validation ----------------------------------------------------------
do
    -- setup() is idempotent: exactly the four commands, config rebuilt.
    base_setup()
    tmux.setup()
    local commands = vim.api.nvim_get_commands({})
    local expected = { TmuxDocs = true, TmuxLayout = true, TmuxUpdateCheck = true, TmuxValidate = true }
    local found = 0
    for name, _ in pairs(expected) do
        if commands[name] ~= nil then
            found = found + 1
        end
    end
    local defaults_pristine = tmux.default_config.keymaps_enabled == true
        and tmux.default_config.tmux_bin == 'tmux'
        and tmux.config ~= tmux.default_config
    val_check(
        found == 4 and defaults_pristine,
        'setup is idempotent: exactly TmuxDocs/TmuxLayout/TmuxUpdateCheck/TmuxValidate; '
            .. 'M.config rebuilt without mutating M.default_config'
    )
end

do
    -- Default config keys are explicit and alphabetical.
    local keys = {}
    for key, _ in pairs(tmux.default_config) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    local expected = {
        'docs_url',
        'keymaps_enabled',
        'known_upstream_version',
        'layouts',
        'nav_down',
        'nav_left',
        'nav_right',
        'nav_up',
        'select_impl',
        'timeout_ms',
        'tmux_bin',
        'tmux_version_min',
        'update_repo',
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
    val_check(same, 'default_config carries exactly the 13 documented keys, alphabetical')
end

do
    -- Neovim-window path: stub says a window exists; wincmd fires, no tmux.
    clear_log()
    vim.env.TMUX = '/tmp/fake-tmux-socket'
    tmux.win_in_direction = function(_)
        return true
    end
    local moved, where = tmux.navigate('left')
    unstub_window()
    vim.env.TMUX = saved_tmux_env
    local real_impl_no_window = orig_win_in_direction('left') == false
    val_check(
        moved == true and where == 'nvim' and read_log() == '' and real_impl_no_window,
        'nvim-window path: navigate moves via wincmd without shelling out; '
            .. 'real win_in_direction reports no window left of a lone window'
    )
end

do
    -- tmux path: no nvim window, inside tmux -> argv select-pane -R.
    clear_log()
    vim.env.TMUX = '/tmp/fake-tmux-socket'
    stub_no_window()
    base_setup()
    local moved, where = tmux.navigate('right')
    unstub_window()
    vim.env.TMUX = saved_tmux_env
    local log = read_log()
    val_check(
        moved == true and where == 'tmux' and log:find('select-pane -R', 1, true) ~= nil,
        'tmux path: navigate("right") runs argv `tmux select-pane -R` (logged verbatim)'
    )
end

do
    -- Version probe: fake `tmux -V` -> 3.7 meets the 3.0 floor.
    base_setup()
    local toolmgr = require('utils.toolmgr')
    local version, version_err = tmux.tmux_version()
    local version_ok = version == '3.7'
        and version_err == nil
        and toolmgr.compare_versions(version, tmux.config.tmux_version_min) >= 0
    val_check(version_ok, 'tmux_version parses fake `tmux -V` to 3.7, meeting tmux_version_min 3.0')
end

do
    -- Layout apply: dev builds editor window + one even horizontal split.
    clear_log()
    vim.env.TMUX = '/tmp/fake-tmux-socket'
    base_setup()
    local ok, err = tmux.apply_layout('dev')
    vim.env.TMUX = saved_tmux_env
    local log = read_log()
    val_check(
        ok == true
            and err == nil
            and log:find('new-window -n editor', 1, true) ~= nil
            and log:find('split-window -t editor -h -p 50', 1, true) ~= nil,
        'apply_layout("dev"): new-window -n editor then split-window -t editor -h -p 50, all argv'
    )
end

do
    -- checks() shape and update_specs() fields; picker path stays quiet.
    clear_log()
    vim.env.TMUX = '/tmp/fake-tmux-socket'
    base_setup({ select_impl = scripted({ nil }) })
    local checks = tmux.checks()
    local names = {}
    local states_ok = true
    for _, check in ipairs(checks) do
        names[#names + 1] = check.name
        if check.status ~= 'ok' and check.status ~= 'unavailable' then
            states_ok = false
        end
    end
    local spec = tmux.update_specs()[1]
    vim.env.TMUX = saved_tmux_env
    base_setup()
    local names_match = table.concat(names, ',') == 'binary,version,inside,server,keymaps'
    local binary_ok = checks[1].status == 'ok'
    local version_ok = checks[2].status == 'ok'
    local inside_ok = checks[3].status == 'ok'
    local server_ok = checks[4].status == 'ok' and checks[4].detail:find('fake-session', 1, true) ~= nil
    local spec_ok = spec.repo == 'tmux/tmux'
        and spec.package == 'tmux'
        and spec.tool_label == 'tmux'
        and spec.known_upstream_version == '3.7c'
        and spec.current_version == '3.7'
    val_check(
        names_match and states_ok and binary_ok and version_ok and inside_ok and server_ok and spec_ok,
        'checks(): binary/version/inside/server/keymaps with ok|unavailable; server probe sees '
            .. 'fake-session; update_specs(): tmux/tmux, package tmux, known 3.7c, current 3.7'
    )
end

-- Restore the world: default config, original PATH/env, stubs gone.
base_setup()
vim.env.PATH = saved_path
vim.env.TMUX = saved_tmux_env
vim.env.TMUX_FAKE_LOG = nil
vim.ui.open = saved_ui_open
tmux.win_in_direction = orig_win_in_direction
os.remove(fakebin .. '/tmux')
os.execute('rmdir ' .. fakebin .. ' 2>/dev/null')
os.remove(fake_log)

emit(string.format('adversarial: %d passed, %d failed', adv_passed, adv_failed))
emit(string.format('validation: %d passed, %d failed', val_passed, val_failed))
local f = io.open(report_path, 'w')
assert(f ~= nil, 'cannot open report path ' .. report_path)
f:write(table.concat(log_lines, '\n') .. '\n')
f:close()
os.exit((adv_failed == 0 and val_failed == 0) and 0 or 1)
