-- #################################################################
-- /qompassai/diver/lua/calendar/init.lua
-- Qompass AI Diver Khal Calendar
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
--- Khal calendar integration: a floating agenda window over
--- `khal list --json`, read-only event detail on <CR>, and a
--- confirmation-gated `khal new` quick-add. Mirrors the agenda-format
--- sensibilities of his khal config
--- (~/.config/khal/config: {calendar-color}{start-end-time-style}
--- {title} ({location}), dark theme, qompass + gmail calendars).
---
--- <CR> detail renders from the read-only `khal list --json` payload the
--- agenda already fetched -- khal has no dedicated `show` subcommand
--- (usage.rst command list: list, at, calendar, configure, import,
--- interactive, new, printcalendars, printformats, search), so no extra
--- subprocess is invented for it.
---
--- Every subprocess goes through security.rce.safe_exec in argv form --
--- never a shell string. Requiring this module performs no I/O and
--- registers nothing. M.setup() registers the :Cal* commands and is
--- idempotent.

---@module 'calendar'

local api = vim.api
local fn = vim.fn

local M = {}

local rce = require('security.rce')
local toolmgr = require('utils.toolmgr')

local AGENDA_ITEMS_MAX = 4000 -- cap on agenda items kept from one `khal list`.
local CALENDARS_MAX = 128 -- cap on calendar names kept from printcalendars.
local DETAIL_WRAP_MIN = 40 -- floor for the detail float's wrap width.
local OUTPUT_BYTES_MAX = 1048576 -- 1 MiB cap on khal output handed anywhere.

--- --json fields requested from `khal list`. Explicit list rather than
--- `all`: --json itself landed in khal 0.11.4 (CHANGELOG.rst) and these
--- fields are the documented template subset (usage.rst, verified
--- 2026-09-27).
---@type string[]
local JSON_FIELDS = {
    'title',
    'calendar',
    'start-date',
    'start-end-time-style',
    'start',
    'start-time',
    'end',
    'end-time',
    'location',
    'description',
    'organizer',
    'url',
    'uid',
    'all-day',
    'categories',
    'repeat-pattern',
}

local MIGRATIONS_TEMPLATE_NOTE = '[template] no khal config rename verified upstream; shape only, no-op'

---@type utils.toolmgr.Migration[]
local MIGRATIONS = {
    {
        version = '0.14.1',
        description = MIGRATIONS_TEMPLATE_NOTE,
        apply = function()
            return true, 'template migration: no changes applied'
        end,
    },
}

--- Factory defaults: explicit, alphabetical, one-line comment per key.
--- Never mutated; M.config is rebuilt from this on every setup().
M.default_config = {
    -- Default `khal list` range for :Cal with no arguments.
    agenda_range_default = { 'today', '7d' },
    -- Safety interlock: CalNew always confirms via vim.ui.select before
    -- running `khal new`. Setting this false is a programmer error and
    -- setup() raises; there is no silent-write mode.
    confirm_writes = true,
    -- Canonical khal docs (verified 2026-09-27: the README badge links here).
    docs_url = 'https://khal.readthedocs.io/en/latest/',
    -- Rows of the floating agenda/detail windows.
    float_height = 24,
    -- Cols of the floating agenda/detail windows.
    float_width = 100,
    -- Khal binary name on PATH.
    khal_bin = 'khal',
    -- Khal config khal reads; mirrors his dotfiles .config/khal/config.
    khal_config = '~/.config/khal/config',
    -- Minimum supported khal: --json output used by the agenda float
    -- landed in 0.11.4 (CHANGELOG.rst).
    khal_version_min = '0.11.4',
    -- Newest khal release verified at build time (0.14.1, 2026-08-21;
    -- 0.14.2 unreleased per CHANGELOG.rst); the update check refreshes this live.
    known_upstream_version = '0.14.1',
    -- Bytes of `khal list` output parse_agenda scans; larger input is
    -- refused with nil+err rather than scanned unbounded.
    parse_line_max = 1048576,
    -- Test seam for vim.ui.select (CalNew confirm, CalUpdateCheck dialog).
    select_impl = nil,
    -- Wall-clock cap for one-shot khal probes (list, printcalendars, new).
    timeout_ms = 30000,
    -- System package name for the updater (pacman/apt/dnf/brew all ship
    -- `khal`; install.rst verified 2026-09-27).
    update_package = 'khal',
    -- Canonical GitHub repo whose releases track khal (verified 2026-09-27).
    update_repo = 'pimutils/khal',
}

--- Live config, rebuilt by every setup() call. Never mutated in place.
---@type table
M.config = vim.deepcopy(M.default_config)

---@class calendar.AgendaItem One event from `khal list --json`.
---@field date string start-date, e.g. '2026-09-27'.
---@field time string start-end-time-style, '' for all-day events.
---@field title string Event title.
---@field calendar string Calendar name, e.g. 'qompass'.
---@field location string Event location, '' when none.
---@field description string Event description, '' when none.
---@field organizer string Organizer, '' when none.
---@field url string Event URL, '' when none.
---@field uid string Event UID, '' when unknown.
---@field all_day boolean True for all-day events.
---@field categories string Event categories, '' when none.
---@field repeat_pattern string Raw iCal recurrence rule, '' when none.

---@class calendar.Check
---@field name string
---@field status string 'ok' | 'below minimum' | 'unavailable'
---@field detail string One-line human summary.

--- State for the live agenda float: buffer handle, the parsed items, and
--- the buffer-line -> items-index map (0 marks a date header line).
---@type { buf: integer, items: calendar.AgendaItem[], map: table<integer, integer> }
local agenda_state = { buf = 0, items = {}, map = {} }

--- Type-check one config option. Mirrors the house pattern in git/cargo:
--- programmer errors raise, expected absences stay nil.
---@param name string Option name for the error message.
---@param value any Value to check.
---@param expected string Expected type() string.
local function check_type(name, value, expected)
    if type(value) ~= expected then
        error(('calendar: option %s must be %s, got %s'):format(name, expected, type(value)), 2)
    end
end

--- Build the live config: factory defaults deep-copied, overrides merged,
--- every key type-checked. Never mutates M.default_config.
---@param config table|nil Overrides; nil restores factory defaults.
---@return table merged Live config table.
function M.setup_config(config)
    if config ~= nil and type(config) ~= 'table' then
        error(('calendar: setup expects a table or nil, got %s'):format(type(config)), 2)
    end
    local merged = vim.tbl_deep_extend('force', vim.deepcopy(M.default_config), config or {})
    check_type('agenda_range_default', merged.agenda_range_default, 'table')
    check_type('confirm_writes', merged.confirm_writes, 'boolean')
    if merged.confirm_writes ~= true then
        error('calendar: confirm_writes must stay true; khal writes are never silent', 2)
    end
    check_type('docs_url', merged.docs_url, 'string')
    check_type('float_height', merged.float_height, 'number')
    check_type('float_width', merged.float_width, 'number')
    check_type('khal_bin', merged.khal_bin, 'string')
    check_type('khal_config', merged.khal_config, 'string')
    check_type('khal_version_min', merged.khal_version_min, 'string')
    check_type('known_upstream_version', merged.known_upstream_version, 'string')
    check_type('parse_line_max', merged.parse_line_max, 'number')
    check_type('timeout_ms', merged.timeout_ms, 'number')
    check_type('update_package', merged.update_package, 'string')
    check_type('update_repo', merged.update_repo, 'string')
    if #merged.agenda_range_default < 1 then
        error('calendar: agenda_range_default needs at least one word', 2)
    end
    for index, word in ipairs(merged.agenda_range_default) do
        if type(word) ~= 'string' or word == '' then
            error(('calendar: agenda_range_default[%d] must be a non-empty string'):format(index), 2)
        end
    end
    if merged.select_impl ~= nil and type(merged.select_impl) ~= 'function' then
        error('calendar: option select_impl must be a function or nil', 2)
    end
    return merged
end

--- Read one string field off a decoded --json entry. Non-string values
--- degrade to '' rather than throwing on unexpected khal output shapes.
---@param entry table Decoded JSON object for one event.
---@param name string Field name.
---@return string value
local function str_field(entry, name)
    local value = entry[name]
    if type(value) == 'string' then
        return value
    end
    return ''
end

--- Coerce one decoded --json entry into an AgendaItem. Returns nil for
--- entries that are not usable event objects (never throws).
---@param entry any One element of the decoded JSON array.
---@return calendar.AgendaItem|nil item
local function coerce_entry(entry)
    if type(entry) ~= 'table' then
        return nil
    end
    local title = entry.title
    if type(title) ~= 'string' then
        return nil
    end
    local time = str_field(entry, 'start-end-time-style')
    if time == '' then
        local start_time = str_field(entry, 'start-time')
        local end_time = str_field(entry, 'end-time')
        if start_time ~= '' then
            time = end_time ~= '' and (start_time .. '-' .. end_time) or start_time
        end
    end
    return {
        date = str_field(entry, 'start-date'),
        time = time,
        title = title,
        calendar = str_field(entry, 'calendar'),
        location = str_field(entry, 'location'),
        description = str_field(entry, 'description'),
        organizer = str_field(entry, 'organizer'),
        url = str_field(entry, 'url'),
        uid = str_field(entry, 'uid'),
        all_day = entry['all-day'] == true,
        categories = str_field(entry, 'categories'),
        repeat_pattern = str_field(entry, 'repeat-pattern'),
    }
end

--- Parse `khal list --json` output into agenda items. Pure and bounded:
--- input past parse_line_max is refused, at most AGENDA_ITEMS_MAX items
--- are kept, malformed entries are skipped, and every failure mode
--- returns nil+err instead of throwing.
---@param text string Raw `khal list` output.
---@return calendar.AgendaItem[]|nil items
---@return string|nil err
function M.parse_agenda(text)
    if type(text) ~= 'string' then
        return nil, 'parse_agenda expects a string, got ' .. type(text)
    end
    if #text > M.config.parse_line_max then
        return nil, ('input %d bytes exceeds parse_line_max %d'):format(#text, M.config.parse_line_max)
    end
    if text:match('^%s*$') then
        return {}, nil
    end
    local ok, decoded = pcall(vim.json.decode, text)
    if not ok or type(decoded) ~= 'table' then
        -- Without --json (or on an empty db) khal prints a human "No
        -- events..." line; treat that sentinel as an empty agenda.
        if text:match('No events') ~= nil then
            return {}, nil
        end
        return nil, 'parse_agenda: output is not a JSON array (' .. text:sub(1, 80) .. ')'
    end
    ---@type table
    local array = decoded
    if #array == 0 and next(array) ~= nil then
        return nil, 'parse_agenda: expected a JSON array of events, got an object'
    end
    local items = {}
    for _, entry in ipairs(array) do
        if #items >= AGENDA_ITEMS_MAX then
            break
        end
        local item = coerce_entry(entry)
        if item ~= nil then
            items[#items + 1] = item
        end
    end
    return items, nil
end

--- Pure renderer: groups items by date and lays out one line per event,
--- mirroring his agenda_event_format sensibilities
--- ({start-end-time-style} {title} ({location})), calendar-prefixed
--- because --json strips the calendar color. Also returns the
--- buffer-line -> items-index map (0 marks a date header).
---@param items calendar.AgendaItem[]
---@return string[] lines
---@return table<integer, integer> line_to_item
function M.format_agenda(items)
    local lines = {}
    ---@type table<integer, integer>
    local line_to_item = {}
    local last_date = nil
    for index, item in ipairs(items) do
        if item.date ~= last_date then
            last_date = item.date
            lines[#lines + 1] = '== ' .. item.date .. ' =='
            line_to_item[#lines] = 0
        end
        local time = item.time ~= '' and item.time or 'all-day'
        local line = ('[%s] %s %s'):format(item.calendar, time, item.title)
        if item.location ~= '' then
            line = line .. ' (' .. item.location .. ')'
        end
        lines[#lines + 1] = line
        line_to_item[#lines] = index
    end
    if #lines == 0 then
        lines[1] = 'No events in range.'
        line_to_item[1] = 0
    end
    return lines, line_to_item
end

--- Wrap text to a width, hard-bounded by the input length. Returns the
--- wrapped lines; never throws on non-string input.
---@param text string
---@param width integer
---@return string[] lines
local function wrap_text(text, width)
    local lines = {}
    local rest = text
    while #rest > width do
        local cut = width
        local space = rest:sub(1, width):match('.*()%s')
        if space ~= nil and space > width / 2 then
            cut = space - 1
        end
        lines[#lines + 1] = rest:sub(1, cut):match('^(.-)%s*$')
        rest = rest:sub(cut + 1):match('^%s*(.*)$')
    end
    lines[#lines + 1] = rest
    return lines
end

--- Pure renderer for the read-only detail view: every --json field the
--- agenda fetched, one labeled line each, description wrapped.
---@param item calendar.AgendaItem
---@return string[] lines
function M.format_detail(item)
    local width = math.max(M.config.float_width - 4, DETAIL_WRAP_MIN)
    local lines = { item.title, '' }
    lines[#lines + 1] = ('calendar:   %s'):format(item.calendar)
    local when = item.date
    if item.time ~= '' then
        when = when .. ' ' .. item.time
    elseif item.all_day then
        when = when .. ' (all-day)'
    end
    lines[#lines + 1] = ('when:       %s'):format(when)
    if item.location ~= '' then
        lines[#lines + 1] = ('location:   %s'):format(item.location)
    end
    if item.organizer ~= '' then
        lines[#lines + 1] = ('organizer:  %s'):format(item.organizer)
    end
    if item.url ~= '' then
        lines[#lines + 1] = ('url:        %s'):format(item.url)
    end
    if item.categories ~= '' then
        lines[#lines + 1] = ('categories: %s'):format(item.categories)
    end
    if item.repeat_pattern ~= '' then
        lines[#lines + 1] = ('repeats:    %s'):format(item.repeat_pattern)
    end
    if item.description ~= '' then
        lines[#lines + 1] = 'description:'
        for _, wrapped in ipairs(wrap_text(item.description, width)) do
            lines[#lines + 1] = '  ' .. wrapped
        end
    end
    lines[#lines + 1] = ('uid:        %s'):format(item.uid)
    return lines
end

--- Open a centered, minimal, read-only float. `q` closes it (mirrors the
--- cargo/git float idiom).
---@param title string Float title.
---@param lines string[] Buffer content.
---@return integer buf
---@return integer win
local function open_float(title, lines)
    local buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    api.nvim_buf_set_name(buf, 'khal://' .. title)
    local win_width = math.min(M.config.float_width, vim.o.columns - 4)
    local win_height = math.min(M.config.float_height, vim.o.lines - 4)
    local win = api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = win_width,
        height = win_height,
        row = math.floor((vim.o.lines - win_height) / 2),
        col = math.floor((vim.o.columns - win_width) / 2),
        style = 'minimal',
        border = 'rounded',
        title = ' ' .. title .. ' ',
        title_pos = 'center',
    })
    vim.keymap.set('n', 'q', '<cmd>close<cr>', { buffer = buf, silent = true, desc = 'Close khal float' })
    return buf, win
end

--- Show the read-only detail float for one agenda item.
---@param item calendar.AgendaItem
function M.show_detail(item)
    open_float('event detail', M.format_detail(item))
end

--- <CR> on the agenda float: open the detail view for the event under
--- the cursor. Header lines and dead buffers are ignored silently.
function M.agenda_detail()
    local state = agenda_state
    if not api.nvim_buf_is_valid(state.buf) then
        return
    end
    local cursor = api.nvim_win_get_cursor(0)
    local index = state.map[cursor[1]]
    if index == nil or index == 0 then
        return
    end
    local item = state.items[index]
    if item ~= nil then
        M.show_detail(item)
    end
end

--- Render parsed items into the agenda float and arm <CR>/q.
---@param items calendar.AgendaItem[]
function M.show_agenda(items)
    local lines, line_to_item = M.format_agenda(items)
    local buf, _ = open_float('khal agenda', lines)
    agenda_state = { buf = buf, items = items, map = line_to_item }
    vim.keymap.set('n', '<CR>', M.agenda_detail, { buffer = buf, silent = true, desc = 'Show event detail' })
end

--- Global khal options shared by every read/write probe: the explicit
--- config file (usage.rst documents -c as a global option).
---@return string[] prefix e.g. { 'khal', '-c', '/home/.../.config/khal/config' }
local function khal_prefix()
    return { M.config.khal_bin, '-c', fn.expand(M.config.khal_config) }
end

--- Fetch the agenda: validate the range, run `khal list <range> --json`
--- (argv form, never a shell string), parse the output. Every expected
--- failure -- bad range, missing binary, khal error, unparsable output --
--- arrives as on_done(nil, err); M.fetch_agenda never throws.
---@param range_args string[]|nil Date-range words; nil uses agenda_range_default.
---@param on_done fun(items: calendar.AgendaItem[]|nil, err: string|nil)
function M.fetch_agenda(range_args, on_done)
    if type(on_done) ~= 'function' then
        error('calendar: fetch_agenda requires an on_done callback', 2)
    end
    local range = range_args
    if range == nil then
        range = M.config.agenda_range_default
    end
    if type(range) ~= 'table' or #range < 1 then
        on_done(nil, 'fetch_agenda needs a non-empty range word list')
        return
    end
    for index, word in ipairs(range) do
        if type(word) ~= 'string' or word == '' then
            on_done(nil, ('fetch_agenda range[%d] must be a non-empty string'):format(index))
            return
        end
    end
    if not toolmgr.binary_present(M.config.khal_bin) then
        on_done(nil, ("khal binary '%s' not found on PATH"):format(M.config.khal_bin))
        return
    end
    local argv = khal_prefix()
    argv[#argv + 1] = 'list'
    for _, word in ipairs(range) do
        argv[#argv + 1] = word
    end
    for _, field in ipairs(JSON_FIELDS) do
        argv[#argv + 1] = '--json'
        argv[#argv + 1] = field
    end
    local result, exec_err = rce.safe_exec(argv, { timeout_ms = M.config.timeout_ms })
    if exec_err ~= nil then
        on_done(nil, exec_err)
        return
    end
    assert(result ~= nil, 'safe_exec returned no error but no result')
    if result.code ~= 0 then
        on_done(nil, 'khal list exited ' .. result.code .. ': ' .. (result.stderr or ''):sub(1, 200))
        return
    end
    local stdout = (result.stdout or ''):sub(1, OUTPUT_BYTES_MAX)
    local items, parse_err = M.parse_agenda(stdout)
    if parse_err ~= nil then
        on_done(nil, parse_err)
        return
    end
    on_done(items, nil)
end

--- Build the exact `khal new` argv that would run for free-form event
--- text (e.g. 'tomorrow 16:30 Coffee :: with Alice'). Words are split on
--- whitespace -- the same split a shell would do -- and passed as argv
--- elements, never interpolated into a string. Pure: no I/O.
---@param text string Event text from the input prompt.
---@return string[]|nil argv
---@return string|nil err
function M.new_argv(text)
    if type(text) ~= 'string' then
        return nil, 'new_argv expects a string, got ' .. type(text)
    end
    local words = {}
    for word in text:gmatch('%S+') do
        words[#words + 1] = word
    end
    if #words == 0 then
        return nil, 'new_argv needs event text, e.g. "tomorrow 16:30 Coffee Break"'
    end
    local argv = khal_prefix()
    argv[#argv + 1] = 'new'
    for _, word in ipairs(words) do
        argv[#argv + 1] = word
    end
    return argv, nil
end

--- Quick-add an event. Shows the exact argv, then runs it ONLY after the
--- explicit vim.ui.select confirmation ("Create event" / "Cancel") --
--- confirm_writes has no silent path. The missing-binary check happens
--- before any confirm so the dialog never promises a doomed write.
--- on_done fires with ('created'|'cancelled', err|nil); M.create_event
--- never throws.
---@param text string Event text, e.g. 'tomorrow 16:30 Coffee Break'.
---@param on_done fun(status: string|nil, err: string|nil)
function M.create_event(text, on_done)
    if type(on_done) ~= 'function' then
        error('calendar: create_event requires an on_done callback', 2)
    end
    local argv, argv_err = M.new_argv(text)
    if argv_err ~= nil then
        on_done(nil, argv_err)
        return
    end
    assert(argv ~= nil, 'new_argv returned no error but no argv')
    if not toolmgr.binary_present(M.config.khal_bin) then
        on_done(nil, ("khal binary '%s' not found on PATH"):format(M.config.khal_bin))
        return
    end
    vim.notify('CalNew would run: ' .. table.concat(argv, ' '), vim.log.levels.INFO)
    local select_impl = M.config.select_impl or vim.ui.select
    select_impl({ 'Create event', 'Cancel' }, { prompt = 'Create this event?' }, function(choice)
        if choice ~= 1 then
            on_done('cancelled', nil)
            return
        end
        local result, exec_err = rce.safe_exec(argv, { timeout_ms = M.config.timeout_ms })
        if exec_err ~= nil then
            on_done(nil, exec_err)
            return
        end
        assert(result ~= nil, 'safe_exec returned no error but no result')
        if result.code ~= 0 then
            on_done(nil, 'khal new exited ' .. result.code .. ': ' .. (result.stderr or ''):sub(1, 200))
            return
        end
        on_done('created', nil)
    end)
end

--- Read-only probe of the configured calendars via `khal printcalendars`
--- (usage.rst, verified 2026-09-27). Never throws; failures degrade to
--- nil+err so :CalValidate can report 'unavailable'.
---@return string[]|nil names
---@return string|nil err
function M.calendars()
    if not toolmgr.binary_present(M.config.khal_bin) then
        return nil, ("khal binary '%s' not found on PATH"):format(M.config.khal_bin)
    end
    local argv = khal_prefix()
    argv[#argv + 1] = 'printcalendars'
    local result, exec_err = rce.safe_exec(argv, { timeout_ms = M.config.timeout_ms })
    if exec_err ~= nil then
        return nil, exec_err
    end
    assert(result ~= nil, 'safe_exec returned no error but no result')
    if result.code ~= 0 then
        return nil, 'khal printcalendars exited ' .. result.code .. ': ' .. (result.stderr or ''):sub(1, 200)
    end
    local names = {}
    for line in ((result.stdout or '') .. '\n'):gmatch('([^\n]*)\n') do
        local name = line:match('^%s*(.-)%s*$')
        if name ~= '' and #names < CALENDARS_MAX then
            names[#names + 1] = name
        end
    end
    return names, nil
end

--- Map a toolmgr binary report onto the check status vocabulary.
--- Mirrors cargo/git: missing tools are 'unavailable', never an error.
---@param report utils.toolmgr.BinaryReport
---@return calendar.Check
local function to_check(report)
    local status = 'unavailable'
    if report.present and report.meets_minimum then
        status = 'ok'
    elseif report.present then
        status = 'below minimum'
    end
    return { name = report.name, status = status, detail = report.detail }
end

--- Per-check validation. Never throws and never errors: a missing tool
--- is 'unavailable', a too-old one 'below minimum'.
---@return calendar.Check[] checks
function M.checks()
    local cfg = M.config
    local checks = {}
    checks[#checks + 1] = to_check(toolmgr.check_binary({ name = cfg.khal_bin, min_version = cfg.khal_version_min }))
    local config_path = fn.expand(cfg.khal_config)
    if vim.uv.fs_stat(config_path) ~= nil then
        checks[#checks + 1] = { name = 'config', status = 'ok', detail = 'readable: ' .. config_path }
    else
        checks[#checks + 1] = { name = 'config', status = 'unavailable', detail = 'not readable: ' .. config_path }
    end
    local names, names_err = M.calendars()
    if names ~= nil and #names > 0 then
        checks[#checks + 1] = { name = 'calendars', status = 'ok', detail = 'khal sees: ' .. table.concat(names, ', ') }
    else
        checks[#checks + 1] = {
            name = 'calendars',
            status = 'unavailable',
            detail = 'khal reports no calendars: ' .. tostring(names_err),
        }
    end
    checks[#checks + 1] = to_check(toolmgr.check_binary({ name = 'vdirsyncer' }))
    return checks
end

--- :Cal [range] -- floating agenda window over `khal list <range> --json`.
--- No range uses agenda_range_default (today 7d). Read-only.
---@param cmd_opts table nvim_create_user_command callback options.
function M.cmd_cal(cmd_opts)
    local fargs = cmd_opts.fargs or {}
    local range = #fargs > 0 and fargs or nil
    M.fetch_agenda(range, function(items, err)
        if err ~= nil then
            vim.notify('Cal: ' .. err, vim.log.levels.WARN)
            return
        end
        assert(items ~= nil, 'fetch_agenda returned no error but no items')
        M.show_agenda(items)
    end)
end

--- :CalNew -- prompt for event text, show the exact `khal new` argv,
--- execute only after the explicit vim.ui.select confirmation.
---@param _cmd_opts table nvim_create_user_command callback options.
function M.cmd_new(_cmd_opts)
    vim.ui.input({ prompt = 'khal new: ' }, function(text)
        if text == nil or text:match('^%s*$') then
            return
        end
        M.create_event(text, function(status, err)
            if status == 'cancelled' then
                vim.notify('CalNew: cancelled', vim.log.levels.INFO)
            elseif err ~= nil then
                vim.notify('CalNew: ' .. err, vim.log.levels.ERROR)
            else
                vim.notify('CalNew: event created', vim.log.levels.INFO)
            end
        end)
    end)
end

--- :CalDocs -- open the verified khal docs.
---@param _cmd_opts table nvim_create_user_command callback options.
function M.cmd_docs(_cmd_opts)
    local url = M.config.docs_url
    local opened = vim.ui.open ~= nil and pcall(vim.ui.open, url)
    if not opened then
        vim.notify('khal docs: ' .. url, vim.log.levels.INFO)
    end
end

--- :CalValidate -- one vim.notify per check; missing pieces say
--- "unavailable", never an error.
---@param _cmd_opts table nvim_create_user_command callback options.
function M.cmd_validate(_cmd_opts)
    for _, check in ipairs(M.checks()) do
        local level = check.status == 'ok' and vim.log.levels.INFO or vim.log.levels.WARN
        vim.notify(('khal %-10s %-13s %s'):format(check.name, check.status, check.detail), level)
    end
end

--- :CalUpdateCheck -- toolmgr update dialog for khal against the verified
--- pimutils/khal releases.
---@param _cmd_opts table nvim_create_user_command callback options.
function M.cmd_update_check(_cmd_opts)
    local current = toolmgr.command_version({ M.config.khal_bin, '--version' })
    toolmgr.check_update({
        tool_label = 'khal',
        repo = M.config.update_repo,
        package = M.config.update_package,
        current_version = current,
        known_upstream_version = M.config.known_upstream_version,
        migrations = MIGRATIONS,
        select_impl = M.config.select_impl,
    })
end

local setup_done = false

--- Register the :Cal* commands. Idempotent: commands are created once;
--- the config is rebuilt on every call. Performs no subprocess I/O
--- itself.
---@param config? table Overrides merged over M.default_config.
function M.setup(config)
    M.config = M.setup_config(config)
    if setup_done then
        return
    end
    setup_done = true
    api.nvim_create_user_command('Cal', M.cmd_cal, {
        nargs = '*',
        desc = 'Floating khal agenda (default: today 7d); <CR> on an event shows detail',
    })
    api.nvim_create_user_command('CalNew', M.cmd_new, { desc = 'Quick-add a khal event (always confirms first)' })
    api.nvim_create_user_command('CalDocs', M.cmd_docs, { desc = 'Open the khal documentation' })
    api.nvim_create_user_command('CalValidate', M.cmd_validate, { desc = 'Khal per-check validation report' })
    api.nvim_create_user_command('CalUpdateCheck', M.cmd_update_check, { desc = 'Khal update check' })
end

return M
