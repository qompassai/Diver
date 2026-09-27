-- tests/lua/calendar.lua
-- Balanced suite for the calendar module: exactly half adversarial and
-- half validation (7 checks each, 14 total). Run from the repo root with
-- the FULL config (never -u NONE, never --clean):
--   ~/workspace/tools/neovim-nightly/bin/nvim --headless -i NONE \
--     -u ~/workspace/repos/diver/init.lua -l tests/lua/calendar.lua
-- Exit 0 when every check behaves, 1 otherwise. Report goes to
-- $CALENDAR_REPORT (default /tmp/calendar_report.txt).
-- khal is almost certainly absent on the test machine: subprocess paths
-- are asserted graceful ("unavailable", never an error) via a bogus
-- khal_bin, and a fake khal on PATH exercises the confirm gate plus the
-- full read path. No real khal write is ever spawned.
local report_path = os.getenv('CALENDAR_REPORT') or '/tmp/calendar_report.txt'
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

local calendar = require('calendar')

local EXPECTED_COMMANDS = { 'Cal', 'CalNew', 'CalDocs', 'CalValidate', 'CalUpdateCheck' }

local function user_commands()
    return vim.api.nvim_get_commands({})
end

local JSON_FIXTURE = [[
[
 {"title":"Team standup","calendar":"qompass","start-date":"2026-09-28",
  "start-end-time-style":"09:00 - 09:30","start-time":"09:00","end-time":"09:30",
  "location":"Room 101","description":"Daily sync",
  "organizer":"Priya Nair (priya@example.com)","url":"","uid":"standup-001",
  "all-day":false,"categories":"work","repeat-pattern":""},
 {"title":"Dentist","calendar":"foamedmapgm","start-date":"2026-09-28",
  "start-end-time-style":"","start-time":"","end-time":"","location":"",
  "description":"","organizer":"","url":"","uid":"dentist-002",
  "all-day":true,"categories":"","repeat-pattern":""}
]
]]

-- Validation ------------------------------------------------------------
do
    -- setup() already ran at boot (init.lua requires calendar eagerly);
    -- it must be idempotent and leave exactly the 5 commands.
    calendar.setup()
    calendar.setup()
    local commands = user_commands()
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
        'setup registers :Cal :CalNew :CalDocs :CalValidate :CalUpdateCheck; idempotent, still exactly 5'
    )
end

do
    local explicit = true
    for key, _ in pairs(calendar.default_config) do
        if calendar.config[key] == nil then
            explicit = false
        end
    end
    calendar.setup({ float_width = 80 })
    local override_ok = calendar.config.float_width == 80
    calendar.setup()
    local restored = calendar.config.float_width == 100
    local defaults_intact = calendar.default_config.float_width == 100
        and calendar.default_config.confirm_writes == true
    local facts_ok = calendar.config.docs_url == 'https://khal.readthedocs.io/en/latest/'
        and calendar.config.update_repo == 'pimutils/khal'
        and calendar.config.known_upstream_version == '0.14.1'
        and calendar.config.khal_version_min == '0.11.4'
        and calendar.config.update_package == 'khal'
    val_check(
        explicit and override_ok and restored and defaults_intact and facts_ok,
        'config fully explicit; overrides apply, nil restores, default_config never mutated; '
            .. 'verified facts: docs URL, pimutils/khal, 0.14.1 known upstream, 0.11.4 minimum'
    )
end

do
    local items, err = calendar.parse_agenda(JSON_FIXTURE)
    local first = items ~= nil and items[1] or nil
    local second = items ~= nil and items[2] or nil
    val_check(
        err == nil
            and items ~= nil
            and #items == 2
            and first.date == '2026-09-28'
            and first.time == '09:00 - 09:30'
            and first.title == 'Team standup'
            and first.calendar == 'qompass'
            and first.location == 'Room 101'
            and first.uid == 'standup-001'
            and first.all_day == false
            and first.categories == 'work'
            and first.organizer == 'Priya Nair (priya@example.com)'
            and second.all_day == true
            and second.time == ''
            and second.title == 'Dentist'
            and second.calendar == 'foamedmapgm',
        'parse_agenda --json fixture: 2 items with date/time/title/calendar/location/uid/all_day/categories/organizer'
    )
end

do
    local items, _ = calendar.parse_agenda(JSON_FIXTURE)
    assert(items ~= nil, 'fixture must parse for the format checks')
    local lines, line_to_item = calendar.format_agenda(items)
    local empty_lines, empty_map = calendar.format_agenda({})
    local detail = calendar.format_detail(items[1])
    local detail_text = table.concat(detail, '\n')
    val_check(
        lines[1] == '== 2026-09-28 =='
            and line_to_item[1] == 0
            and line_to_item[2] == 1
            and line_to_item[3] == 2
            and lines[2]:find('[qompass]', 1, true) ~= nil
            and lines[2]:find('Team standup', 1, true) ~= nil
            and lines[2]:find('(Room 101)', 1, true) ~= nil
            and lines[3]:find('all-day', 1, true) ~= nil
            and empty_lines[1] == 'No events in range.'
            and empty_map[1] == 0
            and detail[1] == 'Team standup'
            and detail_text:find('calendar:   qompass', 1, true) ~= nil
            and detail_text:find('when:       2026-09-28 09:00 - 09:30', 1, true) ~= nil
            and detail_text:find('location:   Room 101', 1, true) ~= nil
            and detail_text:find('uid:        standup-001', 1, true) ~= nil,
        'format_agenda groups by date with header lines + line->item map; empty agenda message; '
            .. 'format_detail renders labeled calendar/when/location/uid lines'
    )
end

do
    local argv, err = calendar.new_argv('tomorrow 16:30 Coffee Break')
    local expanded = vim.fn.expand(calendar.config.khal_config)
    local argv_ok = err == nil
        and argv ~= nil
        and type(argv) == 'table'
        and argv[1] == calendar.config.khal_bin
        and argv[2] == '-c'
        and argv[3] == expanded
        and argv[4] == 'new'
        and argv[5] == 'tomorrow'
        and argv[6] == '16:30'
        and argv[7] == 'Coffee'
        and argv[8] == 'Break'
        and #argv == 8
    local argv2, err2 = calendar.new_argv('tomorrow 16:30 Coffee :: with Alice')
    local desc_ok = err2 == nil and argv2 ~= nil and argv2[8] == '::' and argv2[#argv2] == 'Alice'
    local empty_argv, empty_err = calendar.new_argv('   ')
    val_check(
        argv_ok and desc_ok and empty_argv == nil and type(empty_err) == 'string',
        'new_argv builds the exact argv table {khal, -c, config, new, words...}; '
            .. ':: description words preserved; blank text refused with nil+err'
    )
end

-- Fake-khal read path: the fake answers list/printcalendars/--version.
local fakebin = '/tmp/calendar_fakebin'
local saved_path = vim.env.PATH or ''
vim.env.PATH = fakebin .. ':' .. saved_path
local fake_list_path = '/tmp/calendar_fake_list.json'
local fake_argv_log = '/tmp/calendar_fake_argv.log'
do
    local f = io.open(fake_list_path, 'w')
    assert(f ~= nil, 'cannot write fake list fixture')
    f:write(JSON_FIXTURE)
    f:close()
    calendar.setup({
        khal_bin = 'khal-fake-diver-test',
        khal_config = vim.fn.expand('~/workspace/repos/dotfiles/.config/khal/config'),
    })
    local got_items, got_err = nil, 'pending'
    calendar.fetch_agenda(nil, function(items, err)
        got_items, got_err = items, err
    end)
    local names, names_err = calendar.calendars()
    local checks = calendar.checks()
    local by_name = {}
    local vocab_ok = true
    for _, check in ipairs(checks) do
        by_name[check.name] = check.status
        if check.status ~= 'ok' and check.status ~= 'below minimum' and check.status ~= 'unavailable' then
            vocab_ok = false
        end
    end
    val_check(
        got_err == nil
            and got_items ~= nil
            and #got_items == 2
            and got_items[1].title == 'Team standup'
            and got_items[2].title == 'Dentist'
            and names_err == nil
            and names ~= nil
            and #names == 3
            and names[1] == 'qompass'
            and names[2] == 'foamedmapgm'
            and names[3] == 'map26gm'
            and vocab_ok
            and by_name['khal-fake-diver-test'] == 'ok'
            and by_name['config'] == 'ok'
            and by_name['calendars'] == 'ok',
        'fake khal: fetch_agenda parses list --json output; calendars() reads printcalendars; '
            .. 'checks() reports khal/config/calendars ok with statuses in the check vocabulary'
    )
end

do
    -- The write gate: Cancel must spawn nothing; Create runs the exact argv.
    os.remove(fake_argv_log)
    local function chooser(choice)
        return function(_items, _opts, on_choice)
            on_choice(choice)
        end
    end
    calendar.setup({
        khal_bin = 'khal-fake-diver-test',
        khal_config = vim.fn.expand('~/workspace/repos/dotfiles/.config/khal/config'),
        select_impl = chooser(2),
    })
    local cancel_status, cancel_err = 'pending', 'pending'
    calendar.create_event('tomorrow 10:00 Fake Meeting', function(status, err)
        cancel_status, cancel_err = status, err
    end)
    local log_after_cancel = io.open(fake_argv_log, 'r')
    if log_after_cancel ~= nil then
        log_after_cancel:close()
    end
    calendar.setup({
        khal_bin = 'khal-fake-diver-test',
        khal_config = vim.fn.expand('~/workspace/repos/dotfiles/.config/khal/config'),
        select_impl = chooser(1),
    })
    local create_status, create_err = 'pending', 'pending'
    calendar.create_event('tomorrow 10:00 Fake Meeting', function(status, err)
        create_status, create_err = status, err
    end)
    local logged = ''
    local log_file = io.open(fake_argv_log, 'r')
    if log_file ~= nil then
        logged = log_file:read('*a') or ''
        log_file:close()
    end
    val_check(
        cancel_status == 'cancelled'
            and cancel_err == nil
            and log_after_cancel == nil
            and create_status == 'created'
            and create_err == nil
            and logged:find(' new ', 1, true) ~= nil
            and logged:find('Fake Meeting', 1, true) ~= nil,
        'CalNew confirm gate: Cancel spawns no khal (argv log untouched); '
            .. 'Create runs the exact `khal new` argv and reports created'
    )
end

-- Adversarial -----------------------------------------------------------
do
    local cases = { nil, 123, true, {} }
    local all_ok = true
    for _, bad in ipairs(cases) do
        local ok, items, err = pcall(calendar.parse_agenda, bad)
        if not (ok and items == nil and type(err) == 'string') then
            all_ok = false
        end
    end
    adv_check(all_ok, 'parse_agenda(nil/123/true/{}) returns nil+err, never throws')
end

do
    local items1, err1 = calendar.parse_agenda('')
    local items2, err2 = calendar.parse_agenda('   \n\n  \n')
    adv_check(
        err1 == nil and err2 == nil and items1 ~= nil and #items1 == 0 and items2 ~= nil and #items2 == 0,
        'empty and whitespace-only input: empty agenda, no error'
    )
end

do
    local items1, err1 = calendar.parse_agenda('this is not json {{{')
    local items2, err2 = calendar.parse_agenda('{"events": []}')
    local items3, err3 = calendar.parse_agenda('[1, "x", {"title": 42}, null, {"title": "ok", "calendar": "q"}]')
    adv_check(
        items1 == nil
            and type(err1) == 'string'
            and items2 == nil
            and type(err2) == 'string'
            and err3 == nil
            and items3 ~= nil
            and #items3 == 1
            and items3[1].title == 'ok',
        'malformed input: garbage and JSON objects refused with nil+err; '
            .. 'non-object / title-less entries skipped, never throws'
    )
end

do
    local big = string.rep('x', calendar.default_config.parse_line_max + 1)
    local ok, items, err = pcall(calendar.parse_agenda, big)
    adv_check(
        ok and items == nil and type(err) == 'string' and err:find('parse_line_max', 1, true) ~= nil,
        'oversized input refused with nil+err naming parse_line_max, never scanned unbounded'
    )
end

do
    local select_calls = 0
    local stub = function(_items, _opts, on_choice)
        select_calls = select_calls + 1
        on_choice(1)
    end
    calendar.setup({ khal_bin = 'definitely-not-khal-xyz', select_impl = stub })
    local status, err = 'pending', 'pending'
    calendar.create_event('tomorrow 10:00 X', function(cb_status, cb_err)
        status, err = cb_status, cb_err
    end)
    local status2, err2 = calendar.new_argv('   ')
    local fetch_status, fetch_err = 'pending', 'pending'
    calendar.fetch_agenda(nil, function(items, cb_err)
        fetch_status, fetch_err = items, cb_err
    end)
    local cal_names, cal_err = calendar.calendars()
    local checks = calendar.checks()
    local vocab_ok = true
    local khal_status = nil
    for _, check in ipairs(checks) do
        if check.name == 'definitely-not-khal-xyz' then
            khal_status = check.status
        end
        if check.status ~= 'ok' and check.status ~= 'below minimum' and check.status ~= 'unavailable' then
            vocab_ok = false
        end
    end
    adv_check(
        status == nil
            and type(err) == 'string'
            and err:find('not found on PATH', 1, true) ~= nil
            and select_calls == 0
            and status2 == nil
            and type(err2) == 'string'
            and fetch_status == nil
            and type(fetch_err) == 'string'
            and cal_names == nil
            and type(cal_err) == 'string'
            and khal_status == 'unavailable'
            and vocab_ok,
        'missing khal: create_event refuses BEFORE the confirm dialog (select never called); '
            .. 'fetch_agenda/calendars return nil+err; checks() says unavailable, never errors'
    )
end

do
    local bad_ranges = { {}, { 'today', '' }, { 'today', 42 } }
    local all_ok = true
    for _, bad in ipairs(bad_ranges) do
        local done_items, done_err = 'pending', 'pending'
        local ok = pcall(calendar.fetch_agenda, bad, function(items, err)
            done_items, done_err = items, err
        end)
        if not (ok and done_items == nil and type(done_err) == 'string') then
            all_ok = false
        end
    end
    adv_check(
        all_ok,
        'fetch_agenda({}/{"today",""}/{"today",42}) validates the range and returns nil+err, never throws'
    )
end

adv_check(
    not pcall(calendar.setup, 'nope')
        and not pcall(calendar.setup, { float_width = 'wide' })
        and not pcall(calendar.setup, { agenda_range_default = { 42 } })
        and not pcall(calendar.setup, { select_impl = 42 })
        and not pcall(calendar.setup, { confirm_writes = false }),
    'setup() rejects a non-table config, a mistyped float_width, a non-string range word, '
        .. 'a non-function select_impl, and confirm_writes=false (writes are never silent)'
)

-- Restore the world: default config, original PATH.
calendar.setup()
vim.env.PATH = saved_path
os.remove(fake_argv_log)
os.remove(fake_list_path)

emit(string.format('adversarial: %d passed, %d failed', adv_passed, adv_failed))
emit(string.format('validation: %d passed, %d failed', val_passed, val_failed))
local f = io.open(report_path, 'w')
assert(f ~= nil, 'cannot open report path ' .. report_path)
f:write(table.concat(log_lines, '\n') .. '\n')
f:close()
os.exit((adv_failed == 0 and val_failed == 0) and 0 or 1)
