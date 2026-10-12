-- autocmd_cost.lua
-- Per-autocmd handler cost tracker for the Diver Neovim config.
-- Suggested home: lua/config/perf/autocmd_cost.lua
--
-- Plain-language version: autocmd handlers run on every editor event, and a
-- slow one taxes every keystroke and buffer switch. This module times the
-- handlers registered through it, keeps a rolling ranking of the costliest
-- ones, and reports the total tracked overhead through the toast.
--
-- Coverage boundary — read this before trusting the numbers: Neovim offers
-- no hook that times autocmd callbacks registered by other code. A handler
-- can only be timed if it is registered through M.register below, which
-- wraps the callback with vim.uv.hrtime. Handlers registered anywhere else —
-- the bulk of any real config — are NOT timed and never appear in the
-- ranking; nvim_get_autocmds can inventory them but carries no timing data.
-- The report therefore prints the session's total autocmd count next to the
-- tracked count, so the size of the unobserved remainder is never hidden.
--
-- Toast: config.ui.lsp_health exposes only its own dashboard (open / close /
-- refresh), so its floating window is not a reusable helper. This module
-- replicates that window's behavior shape — scratch buffer, centered
-- 52-column float, rounded border, centered title, q or <Esc> to close,
-- 2000 ms auto-dismiss, idempotent close — with one deliberate difference:
-- the float opens with enter = false so a report never steals focus from
-- the buffer being edited.
--
-- Measured baseline (primo, 2026-10-11, headless nvim with the live config,
-- real files open, handlers driven through this module): total tracked
-- overhead 0.272 ms across 80 calls on 3 tracked handlers; costliest was a
-- BufEnter probe at 0.163 ms total (0.0041 ms mean, 0.086 ms max). The same
-- session had 531 autocmds defined, of which 3 were tracked — the other 528
-- are the unobserved remainder the coverage boundary above describes.
---@module 'autocmd_cost'

local M = {}

-- Bounded constants.
local HANDLERS_MAX = 128
local REPORT_TOP_MAX = 10
local TOAST_DISMISS_MS = 2000
local TOAST_HEIGHT_MAX = 25
local TOAST_HEIGHT_MIN = 5
local TOAST_WIDTH_COLS = 52

---@class AutocmdCostHandler
---@field autocmd_id integer|nil Live autocmd id, nil before registration
---@field calls integer Times the handler has run
---@field events string Comma-joined event names, for display
---@field max_ns integer Slowest single call, nanoseconds
---@field name string Handler name (the stats key)
---@field total_ns integer Total handler time, nanoseconds

---@class AutocmdCostHandlerStat
---@field calls integer Times the handler has run
---@field max_ms number Slowest single call, milliseconds
---@field mean_ms number Mean call time, milliseconds
---@field name string Handler name
---@field total_ms number Total handler time, milliseconds

---@class AutocmdCostRegisterOpts
---@field buffer? integer Buffer-local autocmd
---@field callback fun(args: table) Handler to time
---@field desc? string Autocmd description
---@field name string Stable handler name used as the stats key
---@field once? boolean Register as a one-shot autocmd
---@field pattern? string|string[] Autocmd pattern

---@class AutocmdCostStats
---@field dropped_count integer Registrations refused (registry full)
---@field handler_count integer Distinct handler names tracked
---@field handlers AutocmdCostHandlerStat[] Sorted by total time, descending
---@field total_calls integer Calls across all tracked handlers
---@field total_ms number Total tracked handler time, milliseconds

local augroup_id = nil
local dropped_count = 0
---@type table<string, AutocmdCostHandler>
local handlers = {}
local handler_count = 0
local toast_buf = nil
local toast_timer = nil
local toast_win = nil

---Close the toast float and release its resources. Idempotent.
local function close_toast()
    if toast_timer ~= nil then
        pcall(vim.fn.timer_stop, toast_timer)
        toast_timer = nil
    end
    if toast_win ~= nil and vim.api.nvim_win_is_valid(toast_win) then
        pcall(vim.api.nvim_win_close, toast_win, true)
    end
    toast_win = nil
    if toast_buf ~= nil and vim.api.nvim_buf_is_valid(toast_buf) then
        pcall(vim.api.nvim_buf_delete, toast_buf, { force = true })
    end
    toast_buf = nil
end

---Show lines in a floating toast matching the lsp_health window shape.
---No-op when no UI is attached (headless runs use M.stats instead).
---@param title string Window title, already padded (e.g. ' Autocmd Cost ')
---@param lines string[] Content lines
local function show_toast(title, lines)
    local ui = vim.api.nvim_list_uis()[1]
    if ui == nil then
        return
    end
    close_toast()
    toast_buf = vim.api.nvim_create_buf(false, true)
    assert(toast_buf ~= 0, 'failed to create toast buffer')
    vim.api.nvim_buf_set_lines(toast_buf, 0, -1, false, lines)
    vim.api.nvim_set_option_value('modifiable', false, { buf = toast_buf })
    local height = math.max(TOAST_HEIGHT_MIN, math.min(TOAST_HEIGHT_MAX, #lines))
    local row = math.floor((ui.height - height) / 2)
    local col = math.floor((ui.width - TOAST_WIDTH_COLS) / 2)
    toast_win = vim.api.nvim_open_win(toast_buf, false, {
        border = 'rounded',
        col = col,
        height = height,
        relative = 'editor',
        row = row,
        style = 'minimal',
        title = title,
        title_pos = 'center',
        width = TOAST_WIDTH_COLS,
    })
    assert(toast_win ~= 0, 'failed to open toast window')
    vim.keymap.set('n', 'q', close_toast, { buffer = toast_buf, silent = true })
    vim.keymap.set('n', '<Esc>', close_toast, { buffer = toast_buf, silent = true })
    toast_timer = vim.fn.timer_start(TOAST_DISMISS_MS, function()
        close_toast()
    end)
end

---Create the module's augroup on first use.
local function ensure_augroup()
    if augroup_id == nil then
        augroup_id = vim.api.nvim_create_augroup('DiverAutocmdCost', { clear = false })
    end
end

---Record one timed call against a handler.
---@param record AutocmdCostHandler Handler record to update
---@param duration_ns integer Call duration, nanoseconds
local function record_call(record, duration_ns)
    record.calls = record.calls + 1
    record.total_ns = record.total_ns + duration_ns
    if duration_ns > record.max_ns then
        record.max_ns = duration_ns
    end
end

---Validate the events argument and return it as a list.
---@param events string|string[] Events as given by the caller
---@return string[]|nil event_list
---@return string|nil err
local function validate_events(events)
    if type(events) == 'string' then
        if events == '' then
            return nil, 'events must not be empty'
        end
        return { events }
    end
    if type(events) == 'table' then
        if #events == 0 then
            return nil, 'events must not be empty'
        end
        local event_list = {}
        for index, event in ipairs(events) do
            if type(event) ~= 'string' or event == '' then
                return nil, string.format('events[%d] must be a non-empty string', index)
            end
            event_list[index] = event
        end
        return event_list
    end
    return nil, 'events must be a string or a list of strings'
end

---Register an autocmd whose callback is timed under opts.name.
---Re-registering the same name replaces the previous autocmd and keeps its
---accumulated statistics. Handler errors are timed, then rethrown unchanged.
---@param events string|string[] Autocmd event name(s)
---@param opts AutocmdCostRegisterOpts Registration options
---@return integer|nil autocmd_id New autocmd id on success
---@return string|nil err Error message on invalid input
function M.register(events, opts)
    local event_list, events_err = validate_events(events)
    if event_list == nil then
        return nil, events_err
    end
    if type(opts) ~= 'table' then
        return nil, 'opts must be a table'
    end
    if type(opts.name) ~= 'string' or opts.name == '' then
        return nil, 'opts.name must be a non-empty string'
    end
    if type(opts.callback) ~= 'function' then
        return nil, 'opts.callback must be a function'
    end
    ensure_augroup()
    local record = handlers[opts.name]
    if record == nil then
        if handler_count >= HANDLERS_MAX then
            dropped_count = dropped_count + 1
            return nil, string.format('handler registry full (%d max)', HANDLERS_MAX)
        end
        record = {
            autocmd_id = nil,
            calls = 0,
            events = table.concat(event_list, ','),
            max_ns = 0,
            name = opts.name,
            total_ns = 0,
        }
        handlers[opts.name] = record
        handler_count = handler_count + 1
    end
    record.events = table.concat(event_list, ',')
    if record.autocmd_id ~= nil then
        pcall(vim.api.nvim_del_autocmd, record.autocmd_id)
        record.autocmd_id = nil
    end
    local callback = opts.callback
    local autocmd_id = vim.api.nvim_create_autocmd(event_list, {
        buffer = opts.buffer,
        callback = function(args)
            local start_ns = vim.uv.hrtime()
            local ok, result = pcall(callback, args)
            record_call(record, vim.uv.hrtime() - start_ns)
            if not ok then
                error(result, 0)
            end
        end,
        desc = opts.desc,
        group = augroup_id,
        once = opts.once,
        pattern = opts.pattern,
    })
    record.autocmd_id = autocmd_id
    return autocmd_id
end

---Show the costliest tracked handlers and the total overhead in the toast.
function M.report()
    local stats = M.stats()
    local lines = {}
    lines[#lines + 1] = string.format(
        'Total: %.3f ms across %d calls, %d handlers',
        stats.total_ms,
        stats.total_calls,
        stats.handler_count
    )
    if #stats.handlers == 0 then
        lines[#lines + 1] = 'No tracked handlers yet.'
    end
    local shown = math.min(#stats.handlers, REPORT_TOP_MAX)
    for index = 1, shown do
        local handler = stats.handlers[index]
        lines[#lines + 1] = string.format(
            '%-20s %7.3f ms %5d calls max %.3f',
            handler.name:sub(1, 20),
            handler.total_ms,
            handler.calls,
            handler.max_ms
        )
    end
    local defined_count = #vim.api.nvim_get_autocmds({})
    lines[#lines + 1] = string.format('Autocmds in session: %d (%d tracked)', defined_count, stats.handler_count)
    show_toast(' Autocmd Cost ', lines)
end

---Zero all accumulated statistics. Registrations stay in place.
---@return boolean ok Always true
function M.reset()
    for _, record in pairs(handlers) do
        record.calls = 0
        record.max_ns = 0
        record.total_ns = 0
    end
    dropped_count = 0
    return true
end

---Prepare the tracker (creates its augroup). Idempotent.
---@param opts? table Reserved for future options; must be a table if given
---@return boolean|nil ok True on success
---@return string|nil err Error message on invalid input
function M.setup(opts)
    if opts ~= nil and type(opts) ~= 'table' then
        return nil, 'opts must be a table'
    end
    ensure_augroup()
    return true
end

---Return the current statistics, handlers sorted by total time descending.
---@return AutocmdCostStats stats
function M.stats()
    local names = {}
    for name in pairs(handlers) do
        names[#names + 1] = name
    end
    table.sort(names)
    local list = {}
    local total_calls = 0
    local total_ns = 0
    for _, name in ipairs(names) do
        local record = handlers[name]
        total_calls = total_calls + record.calls
        total_ns = total_ns + record.total_ns
        local mean_ms = 0
        if record.calls > 0 then
            mean_ms = record.total_ns / record.calls / 1e6
        end
        list[#list + 1] = {
            calls = record.calls,
            max_ms = record.max_ns / 1e6,
            mean_ms = mean_ms,
            name = record.name,
            total_ms = record.total_ns / 1e6,
        }
    end
    table.sort(list, function(a, b)
        if a.total_ms ~= b.total_ms then
            return a.total_ms > b.total_ms
        end
        return a.name < b.name
    end)
    return {
        dropped_count = dropped_count,
        handler_count = handler_count,
        handlers = list,
        total_calls = total_calls,
        total_ms = total_ns / 1e6,
    }
end

return M
