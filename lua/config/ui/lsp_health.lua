-- /qompassai/Diver/lua/config/ui/lsp_health.lua
-- Qompass AI Diver LSP Health Dashboard
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- Native LSP health dashboard: shows active language servers, their root
-- directories, attached buffers, uptime, and restart counts. Inspired by
-- Brendan Gregg's Systems Performance USE method (Utilization, Saturation,
-- Errors) applied to Neovim's LSP subsystem.
--
-- Plain-language version: a popup that lists every language server running
-- in your editor, where it's working (root directory), which files it's
-- attached to, how long it's been running, and how many times it's
-- restarted. If a server crashes or attaches to the wrong directory, you'll
-- see it here.
---@module 'config.ui.lsp_health'

local M = {}

-- Bounded constants.
local AUTO_DISMISS_MS = 2000
local FLOAT_WIDTH_COLS = 52
local FLOAT_HEIGHT_MAX = 25
local FLOAT_HEIGHT_MIN = 5
local MAX_CLIENTS_SHOWN = 50
local MAX_BUFFERS_PER_CLIENT = 5

---@class LspHealthClientInfo
---@field client_id integer LSP client ID
---@field name string Server name (e.g. 'lua_ls')
---@field root_dir string|nil Workspace root directory
---@field attached_buffers integer[] Buffer numbers attached to this client
---@field attach_time number vim.uv.hrtime() at attach (nanoseconds)
---@field restart_count integer Times this server name has re-attached

-- Tracks client lifecycle: name -> info.
-- Keyed by client ID for active clients; restart counts persist by name.
---@type table<integer, LspHealthClientInfo>
local active_clients = {}
---@type table<string, integer>
local restart_counts = {}
---@type table<string, number>
local first_attach_times = {}

local dashboard_win = nil
local dashboard_buf = nil
local dismiss_timer = nil
local augroup_id = nil

---Format nanosecond duration as human-readable uptime.
---@param start_ns number Start time from vim.uv.hrtime()
---@return string uptime e.g. '5m 23s', '1h 2m', '45s'
local function format_uptime(start_ns)
    assert(type(start_ns) == 'number', 'start_ns must be a number')
    local elapsed_s = math.floor((vim.uv.hrtime() - start_ns) / 1e9)
    if elapsed_s < 0 then
        elapsed_s = 0
    end
    local hours = math.floor(elapsed_s / 3600)
    local minutes = math.floor((elapsed_s % 3600) / 60)
    local seconds = elapsed_s % 60
    if hours > 0 then
        return string.format('%dh %dm', hours, minutes)
    elseif minutes > 0 then
        return string.format('%dm %ds', minutes, seconds)
    else
        return string.format('%ds', seconds)
    end
end

---Get short display name for a buffer.
---@param bufnr integer Buffer number
---@return string name Shortened file name or '[No Name]'
local function buffer_display_name(bufnr)
    assert(type(bufnr) == 'number', 'bufnr must be a number')
    local name = vim.api.nvim_buf_get_name(bufnr)
    if name == '' then
        return '[No Name]'
    end
    return vim.fn.fnamemodify(name, ':t')
end

---Build dashboard lines from current LSP state.
---@return string[] lines Formatted dashboard content
local function build_dashboard_lines()
    local lines = {}

    local clients = vim.lsp.get_clients()
    if #clients == 0 then
        lines[#lines + 1] = 'No LSP clients.'
        return lines
    end

    -- Compact header: Server | Root | Buf (attached buffers) | Uptime.
    lines[#lines + 1] = string.format('%-14s %-18s %s %s', 'Server', 'Root', 'Buf', 'Uptime')

    -- Sort by name for deterministic output.
    table.sort(clients, function(a, b)
        return a.name < b.name
    end)

    local shown_count = 0
    for _, client in ipairs(clients) do
        if shown_count >= MAX_CLIENTS_SHOWN then
            break
        end
        local info = active_clients[client.id]
        local uptime_str = '?'
        if info ~= nil then
            uptime_str = format_uptime(info.attach_time)
        end
        local restart_count = restart_counts[client.name] or 0
        local root_short = client.root_dir or '(none)'
        local home = vim.env.HOME or ''
        if home ~= '' and root_short:sub(1, #home) == home then
            root_short = '~' .. root_short:sub(#home + 1)
        end
        -- Compact: name, short root, buf count, uptime, restarts.
        local buf_count = 0
        if client.attached_buffers ~= nil then
            buf_count = vim.tbl_count(client.attached_buffers)
        end
        -- Truncate root to fit: 52 - name(14) - buf(4) - uptime(7) - restart(4) - spaces(5) = 18.
        if #root_short > 18 then
            root_short = '…' .. root_short:sub(-17)
        end
        local restart_str = ''
        if restart_count > 0 then
            restart_str = string.format(' R%d', restart_count)
        end
        lines[#lines + 1] = string.format(
            '%-14s %-18s %d   %s%s',
            client.name:sub(1, 14),
            root_short,
            buf_count,
            uptime_str,
            restart_str
        )
        -- Show attached buffer names as indented sub-lines.
        if client.attached_buffers ~= nil then
            -- Sort buffer numbers for deterministic output.
            local buf_list = {}
            for bufnr, _ in pairs(client.attached_buffers) do
                buf_list[#buf_list + 1] = bufnr
            end
            table.sort(buf_list)
            local shown_bufs = 0
            for _, bufnr in ipairs(buf_list) do
                if shown_bufs >= MAX_BUFFERS_PER_CLIENT then
                    break
                end
                if vim.api.nvim_buf_is_valid(bufnr) then
                    local buf_name = buffer_display_name(bufnr)
                    lines[#lines + 1] = string.format('  → %s', buf_name)
                    shown_bufs = shown_bufs + 1
                end
            end
        end
        shown_count = shown_count + 1
    end

    return lines
end

---Refresh dashboard buffer content.
local function refresh_dashboard()
    if dashboard_buf == nil or not vim.api.nvim_buf_is_valid(dashboard_buf) then
        return
    end
    local lines = build_dashboard_lines()
    vim.api.nvim_buf_set_option(dashboard_buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(dashboard_buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(dashboard_buf, 'modifiable', false)
end

---Close the dashboard and clean up resources. Idempotent.
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

---Open the LSP health dashboard in a centered floating window.
function M.open()
    -- Close existing dashboard if open.
    close_dashboard()

    dashboard_buf = vim.api.nvim_create_buf(false, true)
    assert(dashboard_buf ~= 0, 'failed to create dashboard buffer')

    -- Size to content: header + clients + buffer sub-lines.
    -- Estimate: each client has 1 line + up to MAX_BUFFERS_PER_CLIENT sub-lines.
    local client_count = #vim.lsp.get_clients()
    local shown_clients = math.min(client_count, MAX_CLIENTS_SHOWN)
    local content_lines = 1 + shown_clients * (1 + MAX_BUFFERS_PER_CLIENT)
    if client_count == 0 then
        content_lines = 1
    end
    local height = math.max(
        FLOAT_HEIGHT_MIN,
        math.min(FLOAT_HEIGHT_MAX, content_lines)
    )
    local width = FLOAT_WIDTH_COLS

    local ui = vim.api.nvim_list_uis()[1]
    local row = math.floor((ui.height - height) / 2)
    local col = math.floor((ui.width - width) / 2)

    dashboard_win = vim.api.nvim_open_win(dashboard_buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = row,
        col = col,
        style = 'minimal',
        border = 'rounded',
        title = ' LSP Health ',
        title_pos = 'center',
    })
    assert(dashboard_win ~= 0, 'failed to open dashboard window')

    -- Buffer options.
    vim.api.nvim_buf_set_option(dashboard_buf, 'filetype', 'lsphealth')
    vim.api.nvim_buf_set_option(dashboard_buf, 'modifiable', false)

    -- Keymaps: q or Escape to close.
    vim.api.nvim_buf_set_keymap(
        dashboard_buf,
        'n',
        'q',
        '<cmd>lua require("config.ui.lsp_health").close()<CR>',
        { noremap = true, silent = true }
    )
    vim.api.nvim_buf_set_keymap(
        dashboard_buf,
        'n',
        '<Esc>',
        '<cmd>lua require("config.ui.lsp_health").close()<CR>',
        { noremap = true, silent = true }
    )

    refresh_dashboard()

    -- Auto-dismiss after 2 seconds.
    dismiss_timer = vim.fn.timer_start(AUTO_DISMISS_MS, function()
        close_dashboard()
    end)
end

---Close the dashboard. Exposed for keymap.
function M.close()
    close_dashboard()
end

---Manually refresh the dashboard. Exposed for keymap.
function M.refresh()
    refresh_dashboard()
end

---Handle LSP client attach: record timestamp and restart count.
---@param client vim.lsp.Client LSP client object
local function on_lsp_attach(client)
    assert(client ~= nil, 'client must not be nil')
    assert(client.id ~= nil, 'client.id must not be nil')
    assert(client.name ~= nil, 'client.name must not be nil')

    local now_ns = vim.uv.hrtime()
    -- Track restart: if we've seen this name before, increment count.
    if first_attach_times[client.name] ~= nil then
        restart_counts[client.name] = (restart_counts[client.name] or 0) + 1
    else
        first_attach_times[client.name] = now_ns
        restart_counts[client.name] = 0
    end
    active_clients[client.id] = {
        client_id = client.id,
        name = client.name,
        root_dir = client.root_dir,
        attached_buffers = {},
        attach_time = now_ns,
        restart_count = restart_counts[client.name] or 0,
    }
end

---Handle LSP client detach: remove from active tracking.
---@param client_id integer LSP client ID
local function on_lsp_detach(client_id)
    assert(type(client_id) == 'number', 'client_id must be a number')
    active_clients[client_id] = nil
end

---Setup the LSP health dashboard: autocmds and user command.
---Idempotent: safe to call multiple times.
function M.setup()
    if augroup_id ~= nil then
        return
    end
    augroup_id = vim.api.nvim_create_augroup('DiverLspHealth', { clear = true })

    vim.api.nvim_create_autocmd('LspAttach', {
        group = augroup_id,
        callback = function(args)
            local client = vim.lsp.get_client_by_id(args.data.client_id)
            if client ~= nil then
                on_lsp_attach(client)
            end
        end,
    })

    vim.api.nvim_create_autocmd('LspDetach', {
        group = augroup_id,
        callback = function(args)
            on_lsp_detach(args.data.client_id)
        end,
    })

    -- Seed with already-attached clients (setup may run after attach).
    for _, client in ipairs(vim.lsp.get_clients()) do
        if active_clients[client.id] == nil then
            on_lsp_attach(client)
        end
    end

    vim.api.nvim_create_user_command('LspHealth', function()
        M.open()
    end, { desc = 'Open LSP health dashboard' })
end

return M
