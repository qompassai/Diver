-- /qompassai/Diver/lua/research/deadlines.lua
-- Qompass AI Diver Research Deadlines Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
--
-- Research-opportunity deadlines (grants, contests, events, CFPs,
-- journal deadlines) from a plain JSON data file, rendered in the
-- editor and synced one-way into khal through the calendar util
-- (lua/utils/calendar.lua).
--
-- Deliberate boundaries:
-- - One-way sync, data file -> calendar. v1 never deletes or mutates
--   an existing calendar event: when a synced event's date no longer
--   matches the data file, the entry is reported as changed for a
--   human decision. (Deleting by vdir UID is the obvious v2 step.)
-- - Sync writes are all-day events carrying a stable marker in the
--   description, 'research-deadline:<id>', plus the source URL. The
--   marker is the dedup key: before creating, the agenda for each
--   candidate date is fetched and ids already present are skipped.
-- - The create path is a 'khal new' argv in the exact shape
--   utils.calendar.new_argv produces (same binary and -c config from
--   calendar.config), run through security.rce.safe_exec -- the same
--   executor calendar.create_event uses. create_event itself is not
--   called: its per-event vim.ui.select confirmation cannot serve a
--   batch sync, so :DeadlinesSync confirms ONCE up front instead,
--   mirroring :CalNew's always-confirms-first discipline, and
--   M.sync() itself is confirm-free for headless callers and tests.
-- - khal facts verified 2026-10-08 against khal 0.14.1 with Matt's
--   config (which has no [locale] section): 'khal new' start dates
--   must be %m/%d/%y ('11/15/26'); a date-only start makes an all-day
--   event; '-a CAL' targets a calendar, otherwise khal's configured
--   default_calendar receives the event. Agenda start-date values
--   arrive in the same %m/%d/%y shape and are normalized back to ISO
--   for comparison.
-- - The dedup marker index comes from ONE 'khal search' call for the
--   marker prefix (all calendars, all dates), parsed through
--   calendar.parse_agenda. Two verified constraints force
--   this shape: 'khal list' over a multi-day range emits one JSON
--   array per day, which parse_agenda refuses; and fetching only each
--   candidate's own date can never see an event whose date moved --
--   changed-date detection would be blind (proven in exercise: a
--   per-date fetch created a duplicate of a moved event). 'khal
--   search' emits one single-event JSON array per match, which the
--   util's parser consumes directly. Dedup is global across
--   calendars (ids are global keys); the target calendar only
--   decides where creates land.
-- - The data file is operator-owned input: it is size-bounded,
--   schema-checked entry by entry, and rejected whole on a duplicate
--   id (deterministic: a silent dedup could hide a data bug). A
--   missing file is a clean 'no deadlines file' state, not an error.
local api = vim.api
local fn = vim.fn
local uv = vim.uv

local M = {}

local calendar = require('utils.calendar')
local rce = require('security.rce')
local toolmgr = require('utils.toolmgr')

local DATA_BYTES_MAX = 262144 -- 256 KiB cap on the deadlines data file.
local DEFAULT_DATA_PATH = fn.expand('~/.local/share/diver/research-deadlines.json')
local DISPLAY_LINES_MAX = 200
local ENTRIES_MAX = 256 -- cap on entries kept from the data file.
local ID_CHARS_MAX = 80
local MARKER_PREFIX = 'research-deadline:'
local SEARCH_OUTPUT_BYTES_MAX = 1048576 -- 1 MiB cap on khal search output.
local TITLE_CHARS_MAX = 200
local TITLE_INPUT_CHARS_MAX = 300

---@type table<string, boolean> Deadline kinds the data file may use.
local KIND_SET = {
    cfp = true,
    contest = true,
    event = true,
    grant = true,
    ['journal-deadline'] = true,
}

---@class DeadlinesConfig
---@field calendar string|nil khal calendar name (nil = khal's configured default)
---@field data_path string deadlines JSON data file
---@field select_impl function|nil test seam for the :DeadlinesSync confirmation

---@type DeadlinesConfig
local config = {
    calendar = nil,
    data_path = DEFAULT_DATA_PATH,
    select_impl = nil,
}

---@class DeadlineEntry One validated row of the data file.
---@field id string stable id; also the calendar dedup key
---@field title string
---@field kind string one of KIND_SET
---@field opens string|nil ISO date
---@field closes string|nil ISO date
---@field deadline string|nil ISO date
---@field cycle string|nil human cycle note ('annual', ...)
---@field url string|nil source URL
---@field notes string|nil
---@field verified boolean true when a human/agent verified the dates

---@class DeadlineDated A DeadlineEntry with its effective date resolved.
---@field entry DeadlineEntry
---@field date string ISO effective date (deadline, else closes)
---@field days_remaining integer date minus today, in days (negative = past due)
---@field past_due boolean

---Days from civil date (Howard Hinnant's algorithm): a pure,
---timezone-free day count for an ISO calendar date, so day arithmetic
---never depends on os.time or the local timezone.
---@param year integer
---@param month integer
---@param day integer
---@return integer days
local function days_from_civil(year, month, day)
    local shifted_year = month <= 2 and year - 1 or year
    local era = math.floor(shifted_year / 400)
    local year_of_era = shifted_year - era * 400
    local shifted_month = month > 2 and month - 3 or month + 9
    local day_of_year = math.floor((153 * shifted_month + 2) / 5) + day - 1
    local day_of_era = year_of_era * 365 + math.floor(year_of_era / 4) - math.floor(year_of_era / 100) + day_of_year
    return era * 146097 + day_of_era - 719468
end

---@param month integer
---@param year integer
---@return integer days
local function days_in_month(month, year)
    local lengths = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    if month == 2 then
        local leap = (year % 4 == 0 and year % 100 ~= 0) or year % 400 == 0
        return leap and 29 or 28
    end
    return lengths[month]
end

---Parse a strict ISO date ('YYYY-MM-DD') into parts, validating the
---day against the real calendar (2026-02-30 is not a date).
---@param text any
---@return table|nil parts { year, month, day }
local function parse_iso_parts(text)
    if type(text) ~= 'string' then
        return nil
    end
    local year, month, day = text:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    if year == nil then
        return nil
    end
    local y, m, d = tonumber(year), tonumber(month), tonumber(day)
    assert(y ~= nil and m ~= nil and d ~= nil, 'ISO capture groups are digits')
    if m < 1 or m > 12 or d < 1 or d > days_in_month(m, y) then
        return nil
    end
    return { year = y, month = m, day = d }
end

---@param text any
---@return boolean ok
local function is_iso_date(text)
    return parse_iso_parts(text) ~= nil
end

---@param iso string valid ISO date
---@return integer days
local function iso_to_days(iso)
    local parts = parse_iso_parts(iso)
    assert(parts ~= nil, 'iso_to_days needs a valid ISO date')
    return days_from_civil(parts.year, parts.month, parts.day)
end

---Format an ISO date the way Matt's khal config parses start dates:
---%m/%d/%y (verified 2026-10-08; see the header).
---@param iso string valid ISO date
---@return string khal_date e.g. '11/15/26'
local function iso_to_khal_date(iso)
    local parts = parse_iso_parts(iso)
    assert(parts ~= nil, 'iso_to_khal_date needs a valid ISO date')
    return ('%02d/%02d/%02d'):format(parts.month, parts.day, parts.year % 100)
end

---Normalize an agenda start-date back to ISO. khal returns dates in
---its configured format (%m/%d/%y under Matt's config); ISO input is
---passed through. Returns nil when neither shape parses.
---@param text any
---@return string|nil iso
local function normalize_agenda_date(text)
    if type(text) ~= 'string' then
        return nil
    end
    if is_iso_date(text) then
        return text
    end
    local month, day, year = text:match('^(%d%d?)%/(%d%d?)%/(%d%d%d%d)$')
    if month == nil then
        month, day, year = text:match('^(%d%d?)%/(%d%d?)%/(%d%d)$')
        if month ~= nil then
            year = '20' .. year
        end
    end
    if month == nil then
        return nil
    end
    local iso = ('%s-%02d-%02d'):format(year, tonumber(month), tonumber(day))
    if not is_iso_date(iso) then
        return nil
    end
    return iso
end

---Notification helper for command-layer errors: scheduled, because a
---stock vim.notify ERROR echoes with err=true and makes nvim_exec2
---fail the calling command for API/RPC callers (the research modules'
---standing pattern).
---@param message string
---@return nil
local function notify_error(message)
    vim.schedule(function()
        vim.notify(message, vim.log.levels.ERROR)
    end)
end

---Render lines into a scratch markdown buffer in a bottom split (the
---research modules' display pattern), bounded at DISPLAY_LINES_MAX.
---@param title string
---@param lines string[]
---@return nil
local function show_lines(title, lines)
    local buf = api.nvim_create_buf(false, true)
    local bounded = {}
    for index, line in ipairs(lines) do
        if index > DISPLAY_LINES_MAX then
            bounded[#bounded + 1] = '... (truncated)'
            break
        end
        bounded[#bounded + 1] = line
    end
    api.nvim_buf_set_lines(buf, 0, -1, false, bounded)
    vim.bo[buf].filetype = 'markdown'
    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].bufhidden = 'wipe'
    vim.cmd('botright split')
    api.nvim_win_set_buf(0, buf)
    api.nvim_buf_set_name(buf, 'research://' .. title)
end

---Read the data file with a hard size bound.
---@param path string
---@return string|nil text
---@return string|nil err
local function read_data_file(path)
    local stat = uv.fs_stat(path)
    if stat == nil then
        return nil, ('deadlines file not found: %s'):format(path)
    end
    if stat.size > DATA_BYTES_MAX then
        return nil, ('deadlines file %s is %d bytes, over the %d byte cap'):format(path, stat.size, DATA_BYTES_MAX)
    end
    local fd, open_err = uv.fs_open(path, 'r', 438)
    if fd == nil then
        return nil, ('cannot open deadlines file %s: %s'):format(path, tostring(open_err))
    end
    local text, read_err = uv.fs_read(fd, stat.size, 0)
    uv.fs_close(fd)
    if text == nil then
        return nil, ('cannot read deadlines file %s: %s'):format(path, tostring(read_err))
    end
    return text, nil
end

---JSON null decodes to vim.NIL, which is truthy: optional fields must
---treat it as absent (the survey seed writes explicit nulls).
---@param value any
---@return any value nil when the input was nil or vim.NIL
local function nil_or(value)
    if value == nil or value == vim.NIL then
        return nil
    end
    return value
end

---Validate one optional ISO-date field of a raw entry.
---@param raw table
---@param field string
---@param index integer entry position for the error message
---@return string|nil err
local function validate_date_field(raw, field, index)
    local value = nil_or(raw[field])
    if value == nil then
        return nil
    end
    if not is_iso_date(value) then
        return ('entry %d: %s must be an ISO date (YYYY-MM-DD) or null, got %s'):format(index, field, tostring(value))
    end
    return nil
end

---Validate one raw decoded entry into a DeadlineEntry. Every rejected
---shape names its field; nothing is silently coerced.
---@param raw any
---@param index integer
---@return DeadlineEntry|nil entry
---@return string|nil err
local function validate_entry(raw, index)
    if type(raw) ~= 'table' then
        return nil, ('entry %d: must be a JSON object'):format(index)
    end
    if type(raw.id) ~= 'string' or raw.id == '' or #raw.id > ID_CHARS_MAX or raw.id:match('^[%w][%w%-_]*$') == nil then
        return nil,
            ('entry %d: id must start with a letter or digit, then letters, digits, dash or underscore, at most %d chars'):format(
                index,
                ID_CHARS_MAX
            )
    end
    if type(raw.title) ~= 'string' or raw.title == '' or #raw.title > TITLE_INPUT_CHARS_MAX then
        return nil,
            ('entry %d (%s): title must be a non-empty string of at most %d chars'):format(
                index,
                raw.id,
                TITLE_INPUT_CHARS_MAX
            )
    end
    if type(raw.kind) ~= 'string' or KIND_SET[raw.kind] ~= true then
        return nil,
            ('entry %d (%s): kind must be one of cfp, contest, event, grant, journal-deadline'):format(index, raw.id)
    end
    for _, field in ipairs({ 'opens', 'closes', 'deadline' }) do
        local date_err = validate_date_field(raw, field, index)
        if date_err ~= nil then
            return nil, date_err
        end
    end
    for _, field in ipairs({ 'cycle', 'notes' }) do
        if nil_or(raw[field]) ~= nil and type(raw[field]) ~= 'string' then
            return nil, ('entry %d (%s): %s must be a string or null'):format(index, raw.id, field)
        end
    end
    if nil_or(raw.url) ~= nil and (type(raw.url) ~= 'string' or raw.url:match('^https?://') == nil) then
        return nil, ('entry %d (%s): url must be an http(s) URL or null'):format(index, raw.id)
    end
    if nil_or(raw.verified) ~= nil and type(raw.verified) ~= 'boolean' then
        return nil, ('entry %d (%s): verified must be a boolean'):format(index, raw.id)
    end
    return {
        id = raw.id,
        title = raw.title,
        kind = raw.kind,
        opens = nil_or(raw.opens),
        closes = nil_or(raw.closes),
        deadline = nil_or(raw.deadline),
        cycle = nil_or(raw.cycle),
        url = nil_or(raw.url),
        notes = nil_or(raw.notes),
        verified = raw.verified == true,
    },
        nil
end

---Load and validate the whole data file. A duplicate id rejects the
---file (documented, deterministic). Returns the entries in file
---order; sorting is upcoming()'s job.
---@param path string
---@return DeadlineEntry[]|nil entries
---@return string|nil err
function M.load_entries(path)
    assert(type(path) == 'string', 'path must be a string')
    local text, read_err = read_data_file(path)
    if text == nil then
        return nil, read_err
    end
    local ok, decoded = pcall(vim.json.decode, text)
    if not ok or type(decoded) ~= 'table' then
        return nil, ('deadlines file %s is not valid JSON'):format(path)
    end
    if #decoded > ENTRIES_MAX then
        return nil, ('deadlines file %s holds %d entries, over the %d cap'):format(path, #decoded, ENTRIES_MAX)
    end
    local entries = {}
    local seen_ids = {}
    for index, raw in ipairs(decoded) do
        local entry, entry_err = validate_entry(raw, index)
        if entry == nil then
            return nil, ('deadlines file %s: %s'):format(path, entry_err)
        end
        assert(entry ~= nil, 'validate_entry returned no entry and no error')
        if seen_ids[entry.id] then
            return nil, ('deadlines file %s: duplicate id %q (ids are the calendar dedup key)'):format(path, entry.id)
        end
        seen_ids[entry.id] = true
        entries[#entries + 1] = entry
    end
    return entries, nil
end

---Resolve an entry's effective date: deadline wins, closes is the
---fallback, opens alone never syncs (an opening date is not a due
---date).
---@param entry DeadlineEntry
---@return string|nil iso
local function effective_date(entry)
    if entry.deadline ~= nil then
        return entry.deadline
    end
    return entry.closes
end

---Load the data file and split it into dated entries (sorted by
---urgency, ties by id) and dateless ones (cycle-only, sorted by id).
---A missing data file is a state, not an error. opts.today (ISO) is
---the test seam for "now"; the default is the local date.
---@param opts table|nil { data_path = string, today = string }
---@return table|nil result { state, today, dated, dateless, total }
---@return string|nil err
function M.upcoming(opts)
    opts = opts or {}
    assert(type(opts) == 'table', 'opts must be a table')
    local path = opts.data_path or config.data_path
    local today = opts.today or os.date('%Y-%m-%d')
    assert(is_iso_date(today), 'today must be an ISO date')
    if uv.fs_stat(path) == nil then
        return { state = 'missing', today = today, dated = {}, dateless = {}, total = 0, path = path }, nil
    end
    local entries, load_err = M.load_entries(path)
    if entries == nil then
        return nil, load_err
    end
    local today_days = iso_to_days(today)
    local dated = {}
    local dateless = {}
    for _, entry in ipairs(entries) do
        local date = effective_date(entry)
        if date == nil then
            dateless[#dateless + 1] = entry
        else
            local remaining = iso_to_days(date) - today_days
            dated[#dated + 1] = {
                entry = entry,
                date = date,
                days_remaining = remaining,
                past_due = remaining < 0,
            }
        end
    end
    table.sort(dated, function(a, b)
        if a.days_remaining ~= b.days_remaining then
            return a.days_remaining < b.days_remaining
        end
        return a.entry.id < b.entry.id
    end)
    table.sort(dateless, function(a, b)
        return a.id < b.id
    end)
    return {
        state = 'ok',
        today = today,
        dated = dated,
        dateless = dateless,
        total = #entries,
        path = path,
    },
        nil
end

---Render an upcoming() result as display lines (pure).
---@param result table upcoming() result
---@return string[] lines
function M.format_upcoming(result)
    assert(type(result) == 'table', 'result must be a table')
    local lines = { '# Research Deadlines', '' }
    if result.state == 'missing' then
        lines[#lines + 1] = ('No deadlines file at %s.'):format(tostring(result.path))
        lines[#lines + 1] = 'Add one (a JSON array of deadline entries) or point setup({ data_path = ... }) at it.'
        return lines
    end
    lines[#lines + 1] = ('As of %s · %d tracked'):format(result.today, result.total)
    lines[#lines + 1] = ''
    if #result.dated == 0 then
        lines[#lines + 1] = '(no dated deadlines)'
    end
    for _, record in ipairs(result.dated) do
        local entry = record.entry
        local when
        if record.days_remaining < 0 then
            when = ('PAST DUE by %d day(s)'):format(-record.days_remaining)
        elseif record.days_remaining == 0 then
            when = 'TODAY'
        elseif record.days_remaining == 1 then
            when = 'tomorrow'
        else
            when = ('in %d days'):format(record.days_remaining)
        end
        local line = ('- %s · %s · %s — %s'):format(record.date, entry.kind, entry.title, when)
        if not entry.verified then
            line = line .. ' (unverified)'
        end
        lines[#lines + 1] = line
        if entry.url ~= nil then
            lines[#lines + 1] = '  ' .. entry.url
        end
    end
    if #result.dateless > 0 then
        lines[#lines + 1] = ''
        lines[#lines + 1] = '## Cycle known — date unverified'
        lines[#lines + 1] = ''
        for _, entry in ipairs(result.dateless) do
            local line = ('- %s · %s'):format(entry.kind, entry.title)
            if entry.cycle ~= nil then
                line = line .. ' — ' .. entry.cycle
            end
            lines[#lines + 1] = line
            if entry.url ~= nil then
                lines[#lines + 1] = '  ' .. entry.url
            end
        end
    end
    return lines
end

---Show the upcoming deadlines in a scratch buffer (:ResearchDeadlines).
---@return nil
function M.show_upcoming()
    local result, err = M.upcoming({})
    if result == nil then
        notify_error(('Deadlines: %s'):format(err))
        return
    end
    show_lines('Research Deadlines', M.format_upcoming(result))
end

---The stable dedup marker an entry's calendar event carries.
---@param id string
---@return string marker
function M.marker_for(id)
    assert(type(id) == 'string', 'id must be a string')
    return MARKER_PREFIX .. id
end

---Make a title safe as one khal summary argument: control characters
---become spaces, runs of whitespace collapse, length is capped.
---@param title string
---@return string cleaned
local function sanitize_title(title)
    local cleaned = title:gsub('[%c]+', ' '):gsub('%s+', ' '):match('^%s*(.-)%s*$') or ''
    if #cleaned > TITLE_CHARS_MAX then
        cleaned = cleaned:sub(1, TITLE_CHARS_MAX)
    end
    return cleaned
end

---Build the exact 'khal new' argv for one dated entry (pure; the
---shape mirrors utils.calendar.new_argv: binary, -c config, 'new',
---then words). The date word is %m/%d/%y per the verified khal
---config format (see header); the description is the dedup marker
---plus the source URL; --url is set when the entry has one.
---@param record DeadlineDated
---@param calendar_name string|nil nil = khal's configured default calendar
---@return string[] argv
function M.event_argv(record, calendar_name)
    assert(type(record) == 'table' and type(record.entry) == 'table', 'record must be a dated deadline')
    assert(is_iso_date(record.date), 'record.date must be an ISO date')
    local entry = record.entry
    local argv = { calendar.config.khal_bin, '-c', fn.expand(calendar.config.khal_config), 'new' }
    if calendar_name ~= nil then
        argv[#argv + 1] = '-a'
        argv[#argv + 1] = calendar_name
    end
    argv[#argv + 1] = iso_to_khal_date(record.date)
    argv[#argv + 1] = sanitize_title(entry.title)
    argv[#argv + 1] = '::'
    local description = M.marker_for(entry.id)
    if entry.url ~= nil then
        description = description .. ' ' .. entry.url
        argv[#argv + 1] = description
        argv[#argv + 1] = '--url'
        argv[#argv + 1] = entry.url
    else
        argv[#argv + 1] = description
    end
    return argv
end

---Scan agenda items for deadline markers: id -> the item carrying it
---(first occurrence wins). Pure.
---@param items table[] calendar.AgendaItem-like tables (description, date)
---@return table<string, table> by_id
function M.markers_in_items(items)
    assert(type(items) == 'table', 'items must be a table')
    local by_id = {}
    for _, item in ipairs(items) do
        if type(item) == 'table' and type(item.description) == 'string' then
            local id = item.description:match('research%-deadline:([%w][%w%-_]*)')
            if id ~= nil and by_id[id] == nil then
                by_id[id] = item
            end
        end
    end
    return by_id
end

---Default create seam: run the event argv through
---security.rce.safe_exec, mirroring calendar.create_event's binary
---check and error strings. done is called synchronously.
---@param record DeadlineDated
---@param calendar_name string|nil
---@param done fun(status: string|nil, err: string|nil)
---@return nil
local function default_create_impl(record, calendar_name, done)
    if not toolmgr.binary_present(calendar.config.khal_bin) then
        done(nil, ("khal binary '%s' not found on PATH"):format(calendar.config.khal_bin))
        return
    end
    local result, exec_err = rce.safe_exec(M.event_argv(record, calendar_name), {
        timeout_ms = calendar.config.timeout_ms,
    })
    if exec_err ~= nil then
        done(nil, exec_err)
        return
    end
    assert(result ~= nil, 'safe_exec returned no error but no result')
    if result.code ~= 0 then
        done(nil, 'khal new exited ' .. result.code .. ': ' .. (result.stderr or ''):sub(1, 200))
        return
    end
    done('created', nil)
end

---Split concatenated top-level JSON arrays out of khal search
---output. khal wraps long arrays across physical lines (observed at
---~80 columns), but raw newlines never occur inside JSON string
---values, so lines are joined first and the arrays are re-split by
---bracket depth with string/escape tracking.
---@param text string
---@return string[] segments
---@return boolean balanced false when the text ends mid-array
local function split_json_arrays(text)
    local joined = text:gsub('\n', '')
    local segments = {}
    local depth = 0
    local in_string = false
    local escaped = false
    local start = nil
    for i = 1, #joined do
        local ch = joined:sub(i, i)
        if in_string then
            if escaped then
                escaped = false
            elseif ch == '\\' then
                escaped = true
            elseif ch == '"' then
                in_string = false
            end
        elseif ch == '"' then
            in_string = true
        elseif ch == '[' then
            if depth == 0 then
                start = i
            end
            depth = depth + 1
        elseif ch == ']' then
            depth = depth - 1
            if depth == 0 and start ~= nil then
                segments[#segments + 1] = joined:sub(start, i)
                start = nil
            end
        end
    end
    return segments, depth == 0 and start == nil
end

---Default search seam: ONE 'khal search' for the marker prefix,
---run with the calendar util's binary/config (the same prefix
---calendar.khal_prefix builds), parsed through
---calendar.parse_agenda (search emits one single-event JSON array
---per match). done is called synchronously with every agenda item
---whose text mentions the marker prefix; markers_in_items applies
---the strict description pattern on top.
---@param done fun(items: table[]|nil, err: string|nil)
---@return nil
local function default_search_impl(done)
    if not toolmgr.binary_present(calendar.config.khal_bin) then
        done(nil, ("khal binary '%s' not found on PATH"):format(calendar.config.khal_bin))
        return
    end
    local argv = { calendar.config.khal_bin, '-c', fn.expand(calendar.config.khal_config), 'search', MARKER_PREFIX }
    for _, field in ipairs({ 'calendar', 'description', 'start-date', 'title', 'uid' }) do
        argv[#argv + 1] = '--json'
        argv[#argv + 1] = field
    end
    local result, exec_err = rce.safe_exec(argv, { timeout_ms = calendar.config.timeout_ms })
    if exec_err ~= nil then
        done(nil, exec_err)
        return
    end
    assert(result ~= nil, 'safe_exec returned no error but no result')
    if result.code ~= 0 then
        done(nil, 'khal search exited ' .. result.code .. ': ' .. (result.stderr or ''):sub(1, 200))
        return
    end
    local items = {}
    local stdout = (result.stdout or ''):sub(1, SEARCH_OUTPUT_BYTES_MAX)
    local segments, balanced = split_json_arrays(stdout)
    if not balanced then
        done(nil, 'khal search output did not parse: unbalanced JSON arrays')
        return
    end
    for _, segment in ipairs(segments) do
        local parsed, parse_err = calendar.parse_agenda(segment)
        if parsed == nil then
            done(nil, 'khal search output did not parse: ' .. tostring(parse_err))
            return
        end
        for _, item in ipairs(parsed) do
            items[#items + 1] = item
        end
    end
    done(items, nil)
end

---@class DeadlinesSyncOpts
---@field calendar string|nil target calendar (nil = khal default)
---@field create_impl function|nil seam: fun(record, calendar_name, done)
---@field data_path string|nil data file override
---@field search_impl function|nil seam: fun(done) yielding marker-bearing agenda items
---@field today string|nil ISO test seam for "now"

---@class DeadlinesSyncResult
---@field calendar string|nil
---@field changed table[] { id, calendar_date, data_date }
---@field created string[] ids
---@field errors table[] { id, err }
---@field past_due_count integer dated entries skipped as past due
---@field skipped string[] ids already on the calendar with the same date

---One-way sync of dated, not-past-due entries into khal. Confirm-free
---by design (the confirmation lives in :DeadlinesSync). Builds the
---marker index through the search seam, skips ids whose marker is
---present with the same date, reports ids whose marker date differs
---as changed WITHOUT touching the event, and creates the rest one
---at a time. A failed create is collected, not fatal.
---@param opts DeadlinesSyncOpts
---@param on_done fun(result: DeadlinesSyncResult|nil, err: string|nil)
---@return nil
function M.sync(opts, on_done)
    opts = opts or {}
    assert(type(opts) == 'table', 'opts must be a table')
    if type(on_done) ~= 'function' then
        error('deadlines: sync requires an on_done callback', 2)
    end
    local upcoming, upcoming_err = M.upcoming(opts)
    if upcoming == nil then
        on_done(nil, upcoming_err)
        return
    end
    assert(upcoming ~= nil, 'upcoming returned no result and no error')
    local calendar_name = opts.calendar or config.calendar
    local search_impl = opts.search_impl or default_search_impl
    local create_impl = opts.create_impl or default_create_impl
    local candidates = {}
    local past_due_count = 0
    for _, record in ipairs(upcoming.dated) do
        if record.past_due then
            past_due_count = past_due_count + 1
        else
            candidates[#candidates + 1] = record
        end
    end
    ---@type DeadlinesSyncResult
    local result = {
        calendar = calendar_name,
        changed = {},
        created = {},
        errors = {},
        past_due_count = past_due_count,
        skipped = {},
    }
    if #candidates == 0 then
        on_done(result, nil)
        return
    end
    local markers = {}
    local function create_from(index)
        if index > #candidates then
            on_done(result, nil)
            return
        end
        local record = candidates[index]
        local existing = markers[record.entry.id]
        if existing ~= nil then
            local existing_iso = normalize_agenda_date(existing.date)
            if existing_iso == record.date then
                result.skipped[#result.skipped + 1] = record.entry.id
            else
                result.changed[#result.changed + 1] = {
                    id = record.entry.id,
                    calendar_date = existing_iso or tostring(existing.date),
                    data_date = record.date,
                }
            end
            create_from(index + 1)
            return
        end
        create_impl(record, calendar_name, function(status, create_err)
            if create_err ~= nil then
                result.errors[#result.errors + 1] = { id = record.entry.id, err = create_err }
            elseif status == 'created' then
                result.created[#result.created + 1] = record.entry.id
            else
                result.errors[#result.errors + 1] = {
                    id = record.entry.id,
                    err = 'create returned unexpected status ' .. tostring(status),
                }
            end
            create_from(index + 1)
        end)
    end
    search_impl(function(items, search_err)
        if search_err ~= nil then
            on_done(nil, ('deadlines sync: marker search failed: %s'):format(search_err))
            return
        end
        for id, item in pairs(M.markers_in_items(items or {})) do
            if markers[id] == nil then
                markers[id] = item
            end
        end
        create_from(1)
    end)
end

---Render a sync result as display lines (pure). Changed entries are
---spelled out: v1 reports them, it never edits the existing event.
---@param result DeadlinesSyncResult
---@return string[] lines
function M.format_sync_report(result)
    assert(type(result) == 'table', 'result must be a table')
    local lines = { '# Deadlines Sync', '' }
    local target = result.calendar or "khal's default calendar"
    lines[#lines + 1] = ('Target calendar: %s'):format(target)
    local summary =
        'Created: %d · Skipped (already present): %d · Changed: %d · Errors: %d · Past due (not synced): %d'
    lines[#lines + 1] =
        summary:format(#result.created, #result.skipped, #result.changed, #result.errors, result.past_due_count)
    for _, id in ipairs(result.created) do
        lines[#lines + 1] = ('- CREATED %s'):format(id)
    end
    for _, id in ipairs(result.skipped) do
        lines[#lines + 1] = ('- SKIPPED %s (already on the calendar)'):format(id)
    end
    for _, change in ipairs(result.changed) do
        local detail = ('- CHANGED %s: calendar has %s, data file says %s'):format(
            change.id,
            change.calendar_date,
            change.data_date
        )
        lines[#lines + 1] = detail .. ' — left untouched (v1 never edits events)'
    end
    for _, failure in ipairs(result.errors) do
        lines[#lines + 1] = ('- ERROR %s: %s'):format(failure.id, failure.err)
    end
    return lines
end

---:DeadlinesSync — confirm once (CalNew discipline), then sync.
---@return nil
function M.cmd_sync()
    local upcoming, err = M.upcoming({})
    if upcoming == nil then
        notify_error(('Deadlines: %s'):format(err))
        return
    end
    assert(upcoming ~= nil, 'upcoming returned no result and no error')
    local pending = 0
    for _, record in ipairs(upcoming.dated) do
        if not record.past_due then
            pending = pending + 1
        end
    end
    if pending == 0 then
        vim.notify('Deadlines: nothing to sync (no dated, not-past-due entries)', vim.log.levels.INFO)
        return
    end
    local target = config.calendar or "khal's default calendar"
    local prompt = ('Sync %d research deadline(s) to %s? Existing events are never edited.'):format(pending, target)
    local select_impl = config.select_impl or vim.ui.select
    select_impl({ 'Sync deadlines', 'Cancel' }, { prompt = prompt }, function(choice)
        if choice ~= 1 then
            vim.notify('DeadlinesSync: cancelled', vim.log.levels.INFO)
            return
        end
        M.sync({}, function(result, sync_err)
            if result == nil then
                notify_error(('Deadlines: %s'):format(sync_err))
                return
            end
            assert(result ~= nil, 'sync returned no result and no error')
            show_lines('Deadlines Sync', M.format_sync_report(result))
            vim.schedule(function()
                vim.notify(
                    ('DeadlinesSync: %d created, %d skipped, %d changed, %d errors'):format(
                        #result.created,
                        #result.skipped,
                        #result.changed,
                        #result.errors
                    ),
                    vim.log.levels.INFO
                )
            end)
        end)
    end)
end

---@param opts? DeadlinesConfig partial overrides (calendar, data_path, select_impl)
---@return nil
function M.setup(opts)
    opts = opts or {}
    if opts.calendar ~= nil then
        assert(type(opts.calendar) == 'string', 'calendar must be a string')
        config.calendar = opts.calendar
    end
    if opts.data_path ~= nil then
        assert(type(opts.data_path) == 'string', 'data_path must be a string')
        config.data_path = opts.data_path
    end
    if opts.select_impl ~= nil then
        assert(type(opts.select_impl) == 'function', 'select_impl must be a function')
        config.select_impl = opts.select_impl
    end

    api.nvim_create_user_command('ResearchDeadlines', function()
        M.show_upcoming()
    end, { desc = 'Show upcoming research deadlines (grants, contests, events, CFPs)' })

    api.nvim_create_user_command('DeadlinesSync', function()
        M.cmd_sync()
    end, { desc = 'Sync research deadlines into khal as all-day events (confirms first; never edits events)' })
end

return M
