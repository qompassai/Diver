-- /qompassai/Diver/lua/config/ui/startup_profile.lua
-- Qompass AI Diver Startup Profiler
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- Parses Neovim --startuptime logs and displays the slowest-loading
-- scripts/plugins in a floating window. Inspired by Brendan Gregg's
-- Systems Performance methodology: measure first, optimize second.
--
-- Plain-language version: when Neovim starts slowly, this shows you
-- exactly which files took the longest to load, sorted slowest-first.
-- Run nvim with --startuptime /tmp/nvim-startup.log, then :StartupProfile.
---@module 'config.ui.startup_profile'

local M = {}

-- Bounded constants.
local AUTO_DISMISS_MS = 5000
local FLOAT_WIDTH_COLS = 72
local FLOAT_HEIGHT_MAX = 25
local FLOAT_HEIGHT_MIN = 5
local MAX_ENTRIES_SHOWN = 30
local DEFAULT_LOG_PATH = vim.fn.stdpath('cache') .. '/startuptime.log'

---@class StartupEntry
---@field time_ms number Self+sourced time in milliseconds
---@field path string Script path or event description
---@field absolute_ms number Absolute time since startup in milliseconds

local dashboard_win = nil
local dashboard_buf = nil
local dismiss_timer = nil
local augroup_id = nil

-- Marker file: signals that a fresh profile was captured and should auto-open.
local PENDING_MARKER = vim.fn.stdpath('cache') .. '/startup_profile_pending'

---Parse a --startuptime log file into sorted entries.
---@param log_path string Path to the startuptime log
---@return StartupEntry[]|nil entries Sorted by time_ms descending, nil on error
---@return string|nil err Error message if parsing failed
local function parse_startup_log(log_path)
    assert(type(log_path) == 'string', 'log_path must be a string')
    assert(log_path ~= '', 'log_path must not be empty')

    local file = io.open(log_path, 'r')
    if file == nil then
        return nil, 'Cannot open: ' .. log_path
    end

    -- Read all lines, find the LAST Primary run header (log may have multiple runs appended).
    local all_lines = {}
    for l in file:lines() do
        all_lines[#all_lines + 1] = l
    end
    file:close()

    local start_idx = 1
    for i = #all_lines, 1, -1 do
        if all_lines[i]:find('Startup times for process: Primary', 1, true) then
            start_idx = i
            break
        end
    end

    ---@type StartupEntry[]
    local entries = {}
    local line_count = 0
    local max_lines = 10000

    for idx = start_idx, #all_lines do
        local line = all_lines[idx]
        line_count = line_count + 1
        if line_count > max_lines then
            break
        end
        -- Format: "123.456  012.345  001.234:  /path/to/file"
        -- We want column 2 (self+sourced) and the path after colon.
        local abs_ms, self_sourced_ms, path = line:match(
            '^(%d+%.%d+)%s+(%d+%.%d+)%s+%d+%.%d+:%s*(.+)$'
        )
        if abs_ms ~= nil and self_sourced_ms ~= nil and path ~= nil then
            local time_num = tonumber(self_sourced_ms)
            local abs_num = tonumber(abs_ms)
            if time_num ~= nil and abs_num ~= nil and time_num > 0.1 then
                -- Only include entries that took meaningful time.
                entries[#entries + 1] = {
                    time_ms = time_num,
                    path = vim.trim(path),
                    absolute_ms = abs_num,
                }
            end
        end
    end

    -- Sort slowest-first for deterministic output.
    table.sort(entries, function(a, b)
        return a.time_ms > b.time_ms
    end)

    return entries, nil
end

---Shorten a path for display: home -> ~, truncate from left if too long.
---@param path string Full path
---@param max_len integer Maximum display length
---@return string short Shortened path
local function shorten_path(path, max_len)
    assert(type(path) == 'string', 'path must be a string')
    assert(type(max_len) == 'number', 'max_len must be a number')
    local home = vim.env.HOME or ''
    local short = path
    if home ~= '' and short:sub(1, #home) == home then
        short = '~' .. short:sub(#home + 1)
    end
    if #short > max_len then
        short = '…' .. short:sub(-(max_len - 1))
    end
    return short
end

---Build dashboard lines from parsed entries.
---@param entries StartupEntry[] Sorted entries
---@return string[] lines Formatted content
local function build_dashboard_lines(entries)
    assert(type(entries) == 'table', 'entries must be a table')
    local lines = {}

    if #entries == 0 then
        lines[#lines + 1] = 'No startup data found.'
        lines[#lines + 1] = 'Run: nvim --startuptime ' .. DEFAULT_LOG_PATH
        return lines
    end

    -- Header.
    lines[#lines + 1] = string.format('%-10s %s', 'Time', 'Script')
    lines[#lines + 1] = string.rep('-', 70)

    local shown = 0
    local total_ms = 0
    for _, entry in ipairs(entries) do
        if shown >= MAX_ENTRIES_SHOWN then
            break
        end
        total_ms = total_ms + entry.time_ms
        local time_str
        if entry.time_ms >= 1000 then
            time_str = string.format('%.2fs', entry.time_ms / 1000)
        else
            time_str = string.format('%.1fms', entry.time_ms)
        end
        local short_path = shorten_path(entry.path, 58)
        lines[#lines + 1] = string.format('%-10s %s', time_str, short_path)
        shown = shown + 1
    end

    return lines
end

---Close the dashboard and clean up. Idempotent.
local function close_dashboard()
    if dismiss_timer ~= nil then
        pcall(vim.fn.timer_stop, dismiss_timer)
        dismiss_timer = nil
    end
    if dashboard_win ~= nil and vim.api.nvim_win_is_valid(dashboard_win) then
        pcall(vim.api.nvim_win_close, dashboard_win, true)
    end
    dashboard_win = nil
    dashboard_buf = nil
end


function M.open(log_path)
    close_dashboard()

    local path = log_path
    if path == nil or path == '' then
        path = DEFAULT_LOG_PATH
    end
    local entries, err = parse_startup_log(path)
    if entries == nil then
        vim.notify('StartupProfile: ' .. (err or 'parse failed'), vim.log.levels.WARN)
        return
    end
    local lines = build_dashboard_lines(entries)

    dashboard_buf = vim.api.nvim_create_buf(false, true)
    assert(dashboard_buf ~= 0, 'failed to create buffer')

    local content_height = math.max(
        FLOAT_HEIGHT_MIN,
        math.min(FLOAT_HEIGHT_MAX, #lines)
    )
    local ui = vim.api.nvim_list_uis()[1]
    local row = math.floor((ui.height - content_height) / 2)
    local col = math.floor((ui.width - FLOAT_WIDTH_COLS) / 2)

    dashboard_win = vim.api.nvim_open_win(dashboard_buf, true, {
        relative = 'editor',
        width = FLOAT_WIDTH_COLS,
        height = content_height,
        row = row,
        col = col,
        style = 'minimal',
        border = 'rounded',
        title = ' Startup Profile ',
        title_pos = 'center',
    })
    assert(dashboard_win ~= 0, 'failed to open window')

    vim.api.nvim_buf_set_option(dashboard_buf, 'filetype', 'startupprofile')
    vim.api.nvim_buf_set_option(dashboard_buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(dashboard_buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(dashboard_buf, 'modifiable', false)

    vim.api.nvim_buf_set_keymap(
        dashboard_buf,
        'n',
        'q',
        '<cmd>lua require("config.ui.startup_profile").close()<CR>',
        { noremap = true, silent = true }
    )
    vim.api.nvim_buf_set_keymap(
        dashboard_buf,
        'n',
        '<Esc>',
        '<cmd>lua require("config.ui.startup_profile").close()<CR>',
        { noremap = true, silent = true }
    )

    -- Auto-dismiss after 5 seconds (longer than LSP dashboard: more to read).
    dismiss_timer = vim.fn.timer_start(AUTO_DISMISS_MS, function()
        close_dashboard()
    end)
end

---Close the dashboard. Exposed for keymap.
function M.close()
    close_dashboard()
end

---Setup: create user commands. Idempotent.
function M.setup()
    if augroup_id ~= nil then
        return
    end
    augroup_id = vim.api.nvim_create_augroup('DiverStartupProfile', { clear = true })

    vim.api.nvim_create_user_command('StartupProfile', function(opts)
        M.open(opts.args ~= '' and opts.args or nil)
    end, {
        nargs = '?',
        complete = 'file',
        desc = 'Show startup profile from --startuptime log',
    })

    vim.api.nvim_create_user_command('StartupProfileCapture', function()
        M.capture()
    end, { desc = 'Restart nvim and capture a fresh startup profile' })

    -- Auto-open profile after a capture restart.
    vim.api.nvim_create_autocmd('VimEnter', {
        group = augroup_id,
        once = true,
        callback = function()
            if vim.fn.filereadable(PENDING_MARKER) == 1 then
                vim.fn.delete(PENDING_MARKER)
                -- Defer to let startup settle before opening the float.
                vim.defer_fn(function()
                    M.open(nil)
                end, 500)
            end
        end,
    })
end

---Capture is now automatic via the require() wrapper in init.lua.
---This just opens the current profile.
function M.capture()
    M.open(nil)
    return
end

function M._old_capture_unused()
    -- Clear old log.
    pcall(vim.fn.delete, DEFAULT_LOG_PATH)
    -- Set marker so the new instance auto-opens the profile.
    local marker_file = io.open(PENDING_MARKER, 'w')
    if marker_file ~= nil then
        marker_file:write('pending')
        marker_file:close()
    end

    -- Collect currently open file paths to restore after restart.
    ---@type string[]
    local files = {}
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(bufnr) then
            local name = vim.api.nvim_buf_get_name(bufnr)
            if name ~= '' and vim.fn.filereadable(name) == 1 then
                files[#files + 1] = name
            end
        end
    end

    -- Build shell-escaped restart command.
    -- Use nohup + & to ensure the new nvim survives this instance quitting.
    local parts = { 'nohup', 'nvim', '--startuptime', vim.fn.shellescape(DEFAULT_LOG_PATH) }
    for _, f in ipairs(files) do
        if #parts < 20 then
            parts[#parts + 1] = vim.fn.shellescape(f)
        end
    end
    parts[#parts + 1] = '>/dev/null 2>&1 &'
    local shell_cmd = table.concat(parts, ' ')

    local ok = pcall(vim.fn.system, shell_cmd)
    if not ok then
        vim.notify('StartupProfile: failed to restart nvim', vim.log.levels.ERROR)
        pcall(vim.fn.delete, PENDING_MARKER)
        return
    end
    -- Give the new process a moment to spawn before quitting.
    vim.wait(500)
    vim.cmd('qa!')
end

return M
