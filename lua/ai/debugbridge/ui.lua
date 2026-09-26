-- /qompassai/Diver/lua/ai/debugbridge/ui.lua
-- Qompass AI Debug Bridge Dashboard (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Floating window over the debug bridge: active debug sessions,
-- DAP breakpoints (security-flagged first), recent security log lines,
-- and quarantined items. Sibling modules are required lazily inside
-- the functions below, so every read is pcall-guarded and missing data
-- renders as '(unavailable)' instead of raising.
--
-- A session counts as flagged when sessions.list() marks it flagged,
-- or when a security-flagged breakpoint sits on its target file.
--
-- Keymaps (buffer-local, silent): k kills the session under the cursor,
-- q closes the window.

local M = {}

local KEY_WIDTH_MAX = 20
local LANG_WIDTH_MAX = 10
local TARGET_DISPLAY_MAX = 40
local STATE_WIDTH_MAX = 6
local ROWS_DISPLAY_MAX = 200
local FINDINGS_DISPLAY_MAX = 8
local TAIL_SCAN_MAX = 200
local WINDOW_WIDTH_MAX = 100
local WINDOW_WIDTH_RATIO = 0.9
local WINDOW_HEIGHT_RATIO = 0.8
local WINDOW_HEIGHT_MIN = 6

-- Marker a security breakpoint carries in its condition or log message.
-- Convention ai.debugbridge.scanbreak must honor when it plants one.
local SECURITY_BP_MARKER = 'debugbridge:security'

-- Log kinds shown under RECENT FINDINGS: the contract names plus the
-- kinds ai.debugbridge.scanbreak actually writes.
local FINDING_KINDS = { 'scan_gate', 'scan_findings', 'stop_hook_hit', 'quarantine' }
local QUARANTINE_KINDS = { 'quarantine' }

---@class DebugbridgeSessionRow
---@field key string Session key.
---@field lang string Debug language.
---@field target string Debug target, shortened to TARGET_DISPLAY_MAX.
---@field refcount integer Session reference count.
---@field state string live|closed|unknown.
---@field flagged boolean True when security-flagged.

---@class DebugbridgeBreakpointRow
---@field file string Buffer file name, shortened.
---@field full_path string Unshortened buffer file name ('' when unnamed).
---@field line integer Breakpoint line (1-based).
---@field flagged boolean True when planted as a security breakpoint.

---@class DebugbridgeLogEntry
---@field kind string Entry kind (scan_gate, stop_hook_hit, quarantine, ...).
---@field text string Rendered line.
---@field path string? Quarantined path, when kind is quarantine.

local STATE_ORDER = {
    live = 1,
    closed = 2,
    unknown = 3,
}

local SESSION_ROW_FORMAT = string.format(
    '%%-%d.%ds | %%-%d.%ds | %%-%d.%ds | %%4s | %%-%d.%ds',
    KEY_WIDTH_MAX,
    KEY_WIDTH_MAX,
    LANG_WIDTH_MAX,
    LANG_WIDTH_MAX,
    TARGET_DISPLAY_MAX,
    TARGET_DISPLAY_MAX,
    STATE_WIDTH_MAX,
    STATE_WIDTH_MAX
)

local win = nil ---@type integer?
local buf = nil ---@type integer?
---Maps absolute buffer line number -> session key for the k keymap.
local line_keys = {} ---@type table<integer, string>

---Require ai.debugbridge.sessions lazily; never at load time.
---@return table? sessions
---@return string? err
local function sessions_module()
    local ok, sessions = pcall(require, 'ai.debugbridge.sessions')
    if not ok or type(sessions) ~= 'table' then
        return nil, 'ai.debugbridge.sessions unavailable: ' .. tostring(sessions)
    end
    return sessions
end

---Shorten a path for display: home-relative, then hard-truncated.
---@param path string
---@param width integer
---@return string
local function shorten(path, width)
    local short = vim.fn.fnamemodify(path, ':~:.')
    if #short > width then
        short = '…' .. short:sub(#short - width + 2)
    end
    return short
end

---Canonicalize a path for identity comparison: resolve symlinks so
---the same file matches however it was spelled (scan registry,
---buffer name, session target). Falls back to lexical normalization
---when the path does not resolve. Idempotent on realpaths.
---@param path string
---@return string canonical
local function canonical_path(path)
    local real_ok, real = pcall(vim.uv.fs_realpath, path)
    local candidate = (real_ok and type(real) == 'string') and real or path
    local norm_ok, norm = pcall(vim.fs.normalize, candidate)
    return (norm_ok and type(norm) == 'string') and norm or candidate
end

---Normalize one raw sessions.list() entry; drop rows without a key.
---The real entry shape is {key, lang, target, refcount, closed}; a
---string `state` field is also honored when present.
---@param entry any
---@param flagged_targets table<string, boolean> Targets with flagged breakpoints.
---@return DebugbridgeSessionRow? row
local function sanitize_session(entry, flagged_targets)
    if type(entry) ~= 'table' then
        return nil
    end
    if type(entry.key) ~= 'string' or entry.key == '' then
        return nil
    end
    local lang = '?'
    if type(entry.lang) == 'string' and entry.lang ~= '' then
        lang = entry.lang
    end
    local raw_target = type(entry.target) == 'string' and entry.target or ''
    local target = raw_target ~= '' and shorten(raw_target, TARGET_DISPLAY_MAX) or '?'
    local refcount = 0
    if type(entry.refcount) == 'number' and entry.refcount >= 0 then
        refcount = math.floor(entry.refcount)
    end
    local state = 'unknown'
    if type(entry.state) == 'string' and STATE_ORDER[entry.state] then
        state = entry.state
    elseif entry.closed == true then
        state = 'closed'
    elseif entry.closed == false then
        state = 'live'
    end
    local flagged = entry.flagged == true or flagged_targets[canonical_path(raw_target)] == true
    ---@type DebugbridgeSessionRow
    local row = {
        key = entry.key,
        lang = lang,
        target = target,
        refcount = refcount,
        state = state,
        flagged = flagged,
    }
    return row
end

---@param a DebugbridgeSessionRow
---@param b DebugbridgeSessionRow
---@return boolean
local function session_less(a, b)
    if a.flagged ~= b.flagged then
        return a.flagged
    end
    local order_a = STATE_ORDER[a.state] or STATE_ORDER.unknown
    local order_b = STATE_ORDER[b.state] or STATE_ORDER.unknown
    if order_a ~= order_b then
        return order_a < order_b
    end
    return a.key < b.key
end

---Read, sanitize, and sort sessions; cap at ROWS_DISPLAY_MAX rows.
---@param flagged_targets table<string, boolean>
---@return DebugbridgeSessionRow[] rows
---@return string? err
local function read_sessions(flagged_targets)
    local sessions, err = sessions_module()
    if sessions == nil then
        return {}, err
    end
    if type(sessions.list) ~= 'function' then
        return {}, 'ai.debugbridge.sessions has no list() function'
    end
    local ok, listed = pcall(sessions.list)
    if not ok then
        return {}, 'sessions.list() failed: ' .. tostring(listed)
    end
    if type(listed) ~= 'table' then
        return {}, 'sessions.list() returned no table'
    end
    local out = {} ---@type DebugbridgeSessionRow[]
    for i = 1, math.min(#listed, ROWS_DISPLAY_MAX) do
        local row = sanitize_session(listed[i], flagged_targets)
        if row ~= nil then
            out[#out + 1] = row
        end
    end
    table.sort(out, session_less)
    return out
end

---True when the breakpoint was planted as a security breakpoint: the
---scanbreak convention is state.flagged == true, or SECURITY_BP_MARKER
---embedded in the condition or log message.
---@param bp table
---@return boolean
local function bp_flagged(bp)
    local state = bp.state
    if type(state) == 'table' and state.flagged == true then
        return true
    end
    local condition = bp.condition
    if type(condition) == 'string' and condition:find(SECURITY_BP_MARKER, 1, true) then
        return true
    end
    local log_message = bp.logMessage
    if type(log_message) == 'string' and log_message:find(SECURITY_BP_MARKER, 1, true) then
        return true
    end
    return false
end

---Read all DAP breakpoints as file:line rows, flagged first.
---@return DebugbridgeBreakpointRow[] rows
---@return string? err
local function read_breakpoints()
    local ok, breakpoints_mod = pcall(require, 'dap.breakpoints')
    if not ok or type(breakpoints_mod) ~= 'table' then
        return {}, 'dap.breakpoints unavailable: ' .. tostring(breakpoints_mod)
    end
    if type(breakpoints_mod.get) ~= 'function' then
        return {}, 'dap.breakpoints has no get() function'
    end
    local get_ok, by_buf = pcall(breakpoints_mod.get)
    if not get_ok then
        return {}, 'dap.breakpoints.get() failed: ' .. tostring(by_buf)
    end
    if type(by_buf) ~= 'table' then
        return {}, 'dap.breakpoints.get() returned no table'
    end
    local out = {} ---@type DebugbridgeBreakpointRow[]
    -- Security-flagged lines armed by ai.debugbridge.scanbreak. The DAP
    -- objects carry no marker (by design), so the registry is the
    -- source of truth; absent module means no flagged lines.
    local flagged_lines = {} ---@type table<string, table<integer, boolean>>
    local sb_ok, scanbreak = pcall(require, 'ai.debugbridge.scanbreak')
    if sb_ok and type(scanbreak) == 'table' and type(scanbreak.flagged_breakpoints) == 'function' then
        local reg_ok, reg = pcall(scanbreak.flagged_breakpoints)
        if reg_ok and type(reg) == 'table' then
            for path, entry in pairs(reg) do
                if type(path) == 'string' and type(entry) == 'table' and type(entry.lines) == 'table' then
                    local set = {}
                    for _, line in ipairs(entry.lines) do
                        if type(line) == 'number' then
                            set[line] = true
                        end
                    end
                    flagged_lines[canonical_path(path)] = set
                end
            end
        end
    end
    local function registry_flagged(full_path, line)
        local set = flagged_lines[canonical_path(full_path)]
        return set ~= nil and set[line] == true
    end
    local names = {} ---@type string[]
    for bufnr, _ in pairs(by_buf) do
        if type(bufnr) == 'number' then
            names[#names + 1] = tostring(bufnr)
        end
    end
    table.sort(names)
    for _, name in ipairs(names) do
        local bufnr = tonumber(name)
        assert(bufnr ~= nil, 'sorted bufnr key must convert back to a number')
        local buf_name = vim.api.nvim_buf_get_name(bufnr)
        local file = shorten(buf_name ~= '' and buf_name or ('[buf ' .. name .. ']'), 60)
        local bps = by_buf[bufnr]
        if type(bps) == 'table' then
            for _, bp in ipairs(bps) do
                if type(bp) == 'table' and type(bp.line) == 'number' then
                    out[#out + 1] = {
                        file = file,
                        full_path = buf_name,
                        line = bp.line,
                        flagged = bp_flagged(bp) or registry_flagged(buf_name, bp.line),
                    }
                end
            end
        end
        if #out >= ROWS_DISPLAY_MAX then
            break
        end
    end
    table.sort(out, function(a, b)
        if a.flagged ~= b.flagged then
            return a.flagged
        end
        if a.file ~= b.file then
            return a.file < b.file
        end
        return a.line < b.line
    end)
    return out
end

---Render one decoded log detail as display text plus an optional path.
---@param detail table
---@return string text
---@return string? path
local function summarize_detail(detail)
    if type(detail.path) == 'string' and detail.path ~= '' then
        return detail.path, detail.path
    end
    local text = ''
    if type(detail.target) == 'string' then
        text = detail.target
    elseif type(detail.key) == 'string' then
        text = detail.key
    end
    if text == '' then
        local enc_ok, encoded = pcall(vim.json.encode, detail)
        text = (enc_ok and type(encoded) == 'string') and encoded or '?'
    end
    return text:sub(1, 120)
end

---Decode one JSON log line into a row; nil when unusable.
---@param line string
---@return DebugbridgeLogEntry? row
local function decode_log_line(line)
    if type(line) ~= 'string' then
        return nil
    end
    local ok, entry = pcall(vim.json.decode, line)
    if not ok or type(entry) ~= 'table' then
        return nil
    end
    if type(entry.kind) ~= 'string' then
        return nil
    end
    if type(entry.detail) ~= 'table' then
        return nil
    end
    local text, path = summarize_detail(entry.detail)
    ---@type DebugbridgeLogEntry
    return { kind = entry.kind, text = text, path = path }
end

---Tail the debugbridge log and keep the newest `limit` entries whose
---kind is wanted. log.tail(n) returns raw JSON lines, oldest first.
---@param kinds string[]
---@param limit integer
---@return DebugbridgeLogEntry[] rows
---@return string? err
local function read_log(kinds, limit)
    local ok, log = pcall(require, 'ai.debugbridge.log')
    if not ok or type(log) ~= 'table' then
        return {}, 'ai.debugbridge.log unavailable: ' .. tostring(log)
    end
    if type(log.tail) ~= 'function' then
        return {}, 'ai.debugbridge.log has no tail() function'
    end
    -- Scan wider than `limit`: tail() returns the last N raw lines, and
    -- most lines are not the kinds we want.
    local tail_ok, lines = pcall(log.tail, TAIL_SCAN_MAX)
    if not tail_ok then
        return {}, 'log.tail() failed: ' .. tostring(lines)
    end
    if type(lines) ~= 'table' then
        return {}, 'log.tail() returned no table'
    end
    local wanted = {} ---@type table<string, boolean>
    for _, kind in ipairs(kinds) do
        wanted[kind] = true
    end
    local matches = {} ---@type DebugbridgeLogEntry[]
    for _, line in ipairs(lines) do
        local row = decode_log_line(line)
        if row ~= nil and wanted[row.kind] then
            matches[#matches + 1] = row
        end
    end
    local out = {} ---@type DebugbridgeLogEntry[]
    local first = math.max(1, #matches - limit + 1)
    for i = first, #matches do
        out[#out + 1] = matches[i]
    end
    return out
end

---Append the ACTIVE SESSIONS section; records line -> key mapping.
---@param lines string[]
---@param flagged_targets table<string, boolean>
---@param keys table<integer, string> Line-number to session-key map, filled here.
---@return string? err
local function draw_sessions(lines, flagged_targets, keys)
    lines[#lines + 1] = '== ACTIVE SESSIONS =='
    local rows, err = read_sessions(flagged_targets)
    if err ~= nil then
        lines[#lines + 1] = '(unavailable)'
        return err
    end
    if #rows == 0 then
        lines[#lines + 1] = '(none)'
        return nil
    end
    local header = string.format(SESSION_ROW_FORMAT, 'key', 'lang', 'target', 'refs', 'state')
    lines[#lines + 1] = header
    for _, row in ipairs(rows) do
        local marker = row.flagged and '[FLAGGED] ' or ''
        -- 116 cols: stylua's 120-col repo config joins this; splitting it
        -- back fails `stylua --check`, so the repo gate wins over 100-col.
        local formatted =
            string.format(SESSION_ROW_FORMAT, row.key, row.lang, row.target, tostring(row.refcount), row.state)
        lines[#lines + 1] = marker .. formatted
        keys[#lines] = row.key
    end
    return nil
end

---Append the BREAKPOINTS section; returns the flagged file set.
---@param lines string[]
---@return table<string, boolean> flagged_targets
---@return string? err
local function draw_breakpoints(lines)
    lines[#lines + 1] = '== BREAKPOINTS =='
    local flagged_targets = {} ---@type table<string, boolean>
    local rows, err = read_breakpoints()
    if err ~= nil then
        lines[#lines + 1] = '(unavailable)'
        return flagged_targets, err
    end
    if #rows == 0 then
        lines[#lines + 1] = '(none)'
        return flagged_targets, nil
    end
    for _, row in ipairs(rows) do
        local marker = row.flagged and ' [FLAGGED]' or ''
        lines[#lines + 1] = row.file .. ':' .. tostring(row.line) .. marker
        if row.flagged and row.full_path ~= '' then
            flagged_targets[canonical_path(row.full_path)] = true
        end
    end
    return flagged_targets, nil
end

---Append the RECENT FINDINGS section.
---@param lines string[]
---@return string? err
local function draw_findings(lines)
    lines[#lines + 1] = '== RECENT FINDINGS =='
    local rows, err = read_log(FINDING_KINDS, FINDINGS_DISPLAY_MAX)
    if err ~= nil then
        lines[#lines + 1] = '(unavailable)'
        return err
    end
    if #rows == 0 then
        lines[#lines + 1] = '(none)'
        return nil
    end
    for _, row in ipairs(rows) do
        lines[#lines + 1] = '[' .. row.kind .. '] ' .. row.text
    end
    return nil
end

---Append the QUARANTINED section.
---@param lines string[]
---@return string? err
local function draw_quarantined(lines)
    lines[#lines + 1] = '== QUARANTINED =='
    local rows, err = read_log(QUARANTINE_KINDS, ROWS_DISPLAY_MAX)
    if err ~= nil then
        lines[#lines + 1] = '(unavailable)'
        return err
    end
    if #rows == 0 then
        lines[#lines + 1] = '(none)'
        return nil
    end
    for _, row in ipairs(rows) do
        lines[#lines + 1] = row.path or row.text
    end
    return nil
end

---Draw all sections into the dashboard buffer.
local function draw()
    assert(buf ~= nil, 'draw requires a buffer')
    assert(win ~= nil, 'draw requires a window')
    -- Stage the new key map locally: only publish it to line_keys after
    -- set_lines succeeds, so a failed render never leaves new keys mapped
    -- onto the old visible rows.
    local new_keys = {} ---@type table<integer, string>
    local lines = {
        'debug bridge',
        'k kill session | q close',
    }
    local problems = {} ---@type string[]
    local flagged_targets, bp_err = draw_breakpoints(lines)
    if bp_err ~= nil then
        problems[#problems + 1] = bp_err
    end
    local err = draw_sessions(lines, flagged_targets, new_keys)
    if err ~= nil then
        problems[#problems + 1] = err
    end
    err = draw_findings(lines)
    if err ~= nil then
        problems[#problems + 1] = err
    end
    err = draw_quarantined(lines)
    if err ~= nil then
        problems[#problems + 1] = err
    end
    -- Rendered strings come from session targets, buffer names, and
    -- decoded log details: all can carry control characters (a newline
    -- in a filename is legal on Linux). A single newline makes
    -- nvim_buf_set_lines throw and bricks the dashboard, so strip them
    -- here at the choke point. gsub never changes the line count, so
    -- line_keys stays aligned.
    for i, line in ipairs(lines) do
        lines[i] = line:gsub('[%c]', '')
    end
    vim.bo[buf].modifiable = true
    -- Restore modifiable even when set_lines throws: otherwise the
    -- dashboard is left editable after a failed render.
    local set_ok, set_err = pcall(vim.api.nvim_buf_set_lines, buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    assert(set_ok, set_err)
    -- Publish only on success: the buffer now shows these rows.
    line_keys = new_keys
    for _, problem in ipairs(problems) do
        vim.notify(problem, vim.log.levels.WARN)
    end
end

---Session key on the cursor line, or nil when the cursor is on chrome.
---@return string? key
local function key_under_cursor()
    if buf == nil or win == nil then
        return nil
    end
    if not vim.api.nvim_buf_is_valid(buf) then
        return nil
    end
    if not vim.api.nvim_win_is_valid(win) then
        return nil
    end
    local cursor = vim.api.nvim_win_get_cursor(win)
    return line_keys[cursor[1]]
end

---Kill the session under the cursor, then refresh the dashboard.
local function kill_row()
    local key = key_under_cursor()
    if key == nil then
        return
    end
    local sessions, err = sessions_module()
    if sessions == nil then
        vim.notify(err or 'ai.debugbridge.sessions unavailable', vim.log.levels.ERROR)
        return
    end
    if type(sessions.kill) ~= 'function' then
        vim.notify('ai.debugbridge.sessions has no kill()', vim.log.levels.ERROR)
        return
    end
    local ok, killed, kill_err = pcall(sessions.kill, key)
    if not ok then
        vim.notify('kill raised: ' .. tostring(killed), vim.log.levels.ERROR)
        return
    end
    if not killed then
        vim.notify('kill failed: ' .. tostring(kill_err), vim.log.levels.ERROR)
        return
    end
    M.refresh()
end

---Wire the buffer-local dashboard keymaps onto a fresh buffer.
---@param target integer Buffer handle.
local function set_keymaps(target)
    local function map(lhs, rhs, desc_text)
        local opts = { buffer = target, silent = true, desc = desc_text }
        vim.keymap.set('n', lhs, rhs, opts)
    end
    map('k', kill_row, 'Kill debug session')
    map('q', M.close, 'Close debug bridge')
end

---Open the debug bridge dashboard, or focus it when already open.
function M.open()
    if win ~= nil and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_set_current_win(win)
        M.refresh()
        return
    end
    if buf ~= nil and vim.api.nvim_buf_is_valid(buf) then
        for _, candidate in ipairs(vim.api.nvim_list_wins()) do
            if vim.api.nvim_win_get_buf(candidate) == buf then
                win = candidate
                vim.api.nvim_set_current_win(win)
                M.refresh()
                return
            end
        end
    end
    -- Reuse the dashboard buffer from a previous open when it still
    -- exists: naming a fresh buffer 'debugbridge://dashboard' while the
    -- old one lives raises E95.
    local existing = vim.fn.bufnr('debugbridge://dashboard')
    if existing ~= -1 and vim.api.nvim_buf_is_valid(existing) then
        buf = existing
    else
        buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(buf, 'debugbridge://dashboard')
    end
    vim.bo[buf].filetype = 'debugbridge-dashboard'
    set_keymaps(buf)
    local max_width = math.floor(vim.o.columns * WINDOW_WIDTH_RATIO)
    local width = math.min(WINDOW_WIDTH_MAX, max_width)
    local max_height = math.floor(vim.o.lines * WINDOW_HEIGHT_RATIO)
    local height = math.max(WINDOW_HEIGHT_MIN, max_height)
    win = vim.api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        style = 'minimal',
        border = 'rounded',
        title = ' Debug Bridge ',
    })
    M.refresh()
end

---Re-read all sections and redraw. No-op when the window is not open.
function M.refresh()
    if win == nil or buf == nil then
        return
    end
    if not vim.api.nvim_win_is_valid(win) then
        return
    end
    if not vim.api.nvim_buf_is_valid(buf) then
        return
    end
    draw()
end

---Close the dashboard; safe to call when it is already closed.
function M.close()
    if win ~= nil and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
    end
    win = nil
    buf = nil
end

return M
