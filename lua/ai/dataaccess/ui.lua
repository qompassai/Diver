-- /qompassai/Diver/lua/ai/dataaccess/ui.lua
-- Qompass AI Data Access Dashboard (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- Floating window listing the sessions managed by ai.dataaccess and
-- the most recent security-relevant audit events.
--
-- One row per session: label | adapter | refs | queries | writes.
-- Below the sessions, the last audit events (newest last). Nothing
-- secret-bearing is shown: labels are built secret-free and event
-- details are already redacted when logged.
--
-- Keymaps (buffer-local, silent): r refreshes, q closes.
--
-- Load-cycle note: ai.dataaccess is required lazily inside functions.

local M = {}

local LABEL_WIDTH_MAX = 40
local ADAPTER_WIDTH_MAX = 10
local ROWS_DISPLAY_MAX = 200
local EVENTS_DISPLAY_MAX = 30
local WINDOW_WIDTH_MAX = 112
local WINDOW_WIDTH_RATIO = 0.9
local WINDOW_HEIGHT_RATIO = 0.8
local WINDOW_HEIGHT_MIN = 8

local win = nil ---@type integer?
local buf = nil ---@type integer?

---@return table? dataaccess
local function dataaccess_module()
    local ok, mod = pcall(require, 'ai.dataaccess')
    if not ok or type(mod) ~= 'table' then
        return nil
    end
    return mod
end

---@return boolean valid
local function window_valid()
    return win ~= nil and vim.api.nvim_win_is_valid(win) and buf ~= nil and vim.api.nvim_buf_is_valid(buf)
end

local function close_window()
    if win ~= nil and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
    end
    win = nil
    buf = nil
end

---@param text string
---@param width integer
---@return string
local function fit(text, width)
    -- Labels and adapter names come from connection config and may
    -- contain control characters (a newline smuggled into a host
    -- field): a single newline makes nvim_buf_set_lines throw, which
    -- would brick the whole dashboard. Strip them before measuring.
    local clean = text:gsub('[%c]', '')
    if #clean > width then
        return clean:sub(1, width)
    end
    return clean .. string.rep(' ', width - #clean)
end

---@return string[] lines
local function build_lines()
    local lines = {
        'Data access sessions',
        '',
        'LABEL                                    | ADAPTER    | REFS | QUERIES | WRITES',
    }
    local dataaccess = dataaccess_module()
    if dataaccess == nil then
        lines[#lines + 1] = '(dataaccess unavailable)'
        return lines
    end
    local sessions = dataaccess.sessions()
    local shown = 0
    for _, session in ipairs(sessions) do
        shown = shown + 1
        if shown > ROWS_DISPLAY_MAX then
            break
        end
        lines[#lines + 1] = table.concat({
            fit(session.label, LABEL_WIDTH_MAX),
            '| ',
            fit(session.adapter_name, ADAPTER_WIDTH_MAX),
            '| ',
            fit(tostring(session.refcount), 4),
            ' | ',
            fit(tostring(session.query_count), 7),
            ' | ',
            tostring(session.write_count),
        })
    end
    if shown == 0 then
        lines[#lines + 1] = '(no sessions)'
    end
    lines[#lines + 1] = ''
    lines[#lines + 1] = 'Recent security events'
    lines[#lines + 1] = ''
    local ok, logmod = pcall(require, 'ai.dataaccess.log')
    if ok and type(logmod) == 'table' then
        local events = logmod.tail(EVENTS_DISPLAY_MAX)
        if #events == 0 then
            lines[#lines + 1] = '(no events)'
        end
        local secret_ok, secrets = pcall(require, 'ai.dataaccess.secrets')
        local redact = secret_ok and type(secrets) == 'table' and secrets.redact or nil
        for _, event in ipairs(events) do
            local text = event:sub(1, WINDOW_WIDTH_MAX)
            -- Defense in depth: details are redacted when logged, but
            -- redact again at render so a caller that forgot cannot leak
            -- a secret onto the screen. redact() is idempotent.
            if type(redact) == 'function' then
                local redact_ok, redacted = pcall(redact, text)
                if redact_ok and type(redacted) == 'string' then
                    text = redacted
                end
            end
            -- A stray carriage return (or a hand-edited log file) must
            -- not brick the dashboard via set_lines.
            lines[#lines + 1] = text:gsub('[%c]', '')
        end
    end
    return lines
end

local function render()
    if not window_valid() then
        return
    end
    assert(buf ~= nil, 'window valid but buf is nil')
    local lines = build_lines()
    vim.bo[buf].modifiable = true
    -- Restore modifiable even when set_lines throws: otherwise the
    -- dashboard is left editable after a failed render.
    local ok, err = pcall(vim.api.nvim_buf_set_lines, buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    assert(ok, err)
end

---Open (or focus) the data-access dashboard.
function M.open()
    if window_valid() then
        assert(win ~= nil, 'window valid but win is nil')
        vim.api.nvim_set_current_win(win)
        render()
        return
    end
    buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].bufhidden = 'wipe'
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = 'dataaccess'
    local columns = vim.o.columns
    local lines_count = vim.o.lines
    local width = math.min(WINDOW_WIDTH_MAX, math.floor(columns * WINDOW_WIDTH_RATIO))
    local height = math.max(WINDOW_HEIGHT_MIN, math.floor(lines_count * WINDOW_HEIGHT_RATIO))
    win = vim.api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        col = math.floor((columns - width) / 2),
        row = math.floor((lines_count - height) / 2),
        style = 'minimal',
        border = 'rounded',
        title = ' data access ',
        title_pos = 'center',
    })
    local opts = { buffer = buf, silent = true, nowait = true }
    vim.keymap.set('n', 'q', close_window, opts)
    vim.keymap.set('n', 'r', render, opts)
    vim.api.nvim_create_autocmd('WinClosed', {
        buffer = buf,
        once = true,
        callback = function()
            win = nil
            buf = nil
        end,
    })
    render()
end

return M
