--- Floating-terminal manager — toggle a centered popup terminal.
---
--- Plain-language version: a floating window is a popup box hovering over your
--- code. This module builds one that runs a terminal inside it. setup() takes
--- your options and returns an instance table with open(), close(), toggle()
--- and is_open(); one terminal buffer is kept per id and re-centered when the
--- editor resizes. The module-level open/close/toggle/is_open functions drive a
--- shared default instance, so any lua/ subdirectory can pop a terminal with one require.
---@module 'config.ui.float'
-- float.lua
-- Qompass AI - [ ]
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {}
local defaults = {
    file = nil,
    cmd = vim.o.shell,
    cwd = vim.fn.getcwd,
    id = function()
        return vim.v.count
    end, -- float identifier
    start_in_insert = true,
    focus = true,
    on_open = nil,
    on_exit = nil,
    window = {
        col = nil, -- supports percentages (<=1) and absolute sizes (>1)
        row = nil, -- supports percentages (<=1) and absolute sizes (>1)
        width = 0.8, -- supports percentages (<=1) and absolute sizes (>1)
        height = 0.8, -- supports percentages (<=1) and absolute sizes (>1)
        h_align = 'center', -- alignment helper if no col, "left", "center", "right"
        v_align = 'center', -- alignment helper if no row, "top", "center", "bottom"
        border = 'rounded',
        zindex = 50,
        title = '',
        title_pos = 'center',
    },
    wo = {
        cursorcolumn = false,
        cursorline = false,
        cursorlineopt = 'both',
        fillchars = 'eob: ,lastline:…',
        list = false,
        listchars = 'extends:…,tab:  ',
        number = false,
        relativenumber = false,
        signcolumn = 'no',
        spell = false,
        winbar = '',
        statuscolumn = '',
        wrap = false,
        sidescrolloff = 0,
    },
}
local function eval_opts(opts)
    if type(opts) == 'function' then
        return opts()
    end
    if type(opts) == 'table' then
        local res = {}
        for k, v in pairs(opts) do
            res[k] = eval_opts(v)
        end
        return res
    end
    return opts
end
local function valid_buf(buf)
    return buf and vim.api.nvim_buf_is_valid(buf)
end
local function valid_win(win)
    return win and vim.api.nvim_win_is_valid(win)
end
local function get_win_opts(config)
    local opts = eval_opts(config.window)
    local width, height = opts.width, opts.height
    local row, col = opts.row, opts.col
    width = width <= 1 and math.floor(vim.o.columns * width) or width
    height = height <= 1 and math.floor(vim.o.lines * height) or height
    if row then
        row = (row > 0 and row <= 1) and math.floor(vim.o.lines * row) or row
    else
        if opts.v_align == 'top' then
            row = 0
        elseif opts.v_align == 'bottom' then
            row = vim.o.lines - height
        else -- 'center'
            row = math.floor((vim.o.lines - height) / 2)
        end
    end
    if col then
        col = (col > 0 and col <= 1) and math.floor(vim.o.columns * col) or col
    else
        if opts.h_align == 'left' then
            col = 0
        elseif opts.h_align == 'right' then
            col = vim.o.columns - width
        else
            col = math.floor((vim.o.columns - width) / 2)
        end
    end
    opts.relative = 'editor'
    opts.width = width
    opts.height = height
    opts.row = row
    opts.col = col
    opts.v_align = nil
    opts.h_align = nil
    return opts
end
local function create_buf(config)
    local buf
    if config.file then
        buf = vim.fn.bufadd(eval_opts(config.file))
        vim.fn.bufload(buf)
    else
        buf = vim.api.nvim_create_buf(false, true)
    end
    return buf
end
local function create_win(config, buf)
    local opts = get_win_opts(config)
    local win = vim.api.nvim_open_win(buf, true, opts)
    for opt, val in pairs(config.wo) do
        vim.wo[win][opt] = val
    end
    return win
end
---@param config table effective float configuration
---@param opts? table may carry `id`
---@return string|number|nil id resolved float id
---@return string|nil err reason the id was rejected
local function resolve_id(config, opts)
    local id = (opts and opts.id) or eval_opts(config.id)
    if type(id) ~= 'string' and type(id) ~= 'number' then
        return nil, 'float id must be a string or number'
    end
    if id == 0 then
        id = config.prev_id or 1
    end
    return id
end

---@param config table effective float configuration
---@param id string|number resolved float id
---@return boolean|nil ok
---@return string|nil err
local function open_float(config, id)
    local term = config.terms[id] or {}
    local cmd = eval_opts(config.cmd) or vim.o.shell
    local cwd = eval_opts(config.cwd) or vim.fn.getcwd()
    local buf_ready = valid_buf(term.buf)
    if not buf_ready then
        term.buf = create_buf(config)
        if config.on_open then
            config.on_open(config, term.buf)
        end
        if config.on_exit then
            vim.api.nvim_create_autocmd('BufDelete', {
                buffer = term.buf,
                once = true,
                callback = function()
                    config.on_exit(config, term.buf)
                end,
            })
        end
    end
    if id ~= config.prev_id then
        local prev_term = config.terms[config.prev_id] or {}
        if valid_win(prev_term.win) then
            vim.api.nvim_win_close(prev_term.win, true)
        end
    end
    local prev_win = vim.api.nvim_get_current_win()
    term.win = create_win(config, term.buf)
    if not config.file then
        if not buf_ready then
            local job_id = vim.fn.jobstart(cmd, { cwd = cwd, term = true })
            if job_id == 0 then
                vim.notify('config.ui.float: invalid arguments for terminal command', vim.log.levels.ERROR)
                return nil, 'invalid terminal command arguments'
            elseif job_id == -1 then
                vim.notify('config.ui.float: terminal command not executable', vim.log.levels.ERROR)
                return nil, 'terminal command not executable'
            end
        end
        if not eval_opts(config.focus) and valid_win(prev_win) then
            vim.api.nvim_set_current_win(prev_win)
        elseif eval_opts(config.start_in_insert) then
            vim.cmd.startinsert()
        end
    end
    config.prev_id = id
    config.terms[id] = term
    return true
end

---@param config table effective float configuration
---@param id string|number|nil float id, or nil for the current float
---@return boolean|nil closed true when a window was closed
---@return string|nil err
local function close_float(config, id)
    if id == nil then
        id = config.prev_id
    end
    if type(id) ~= 'string' and type(id) ~= 'number' then
        return nil, 'float id must be a string or number'
    end
    local term = config.terms[id]
    if term and valid_win(term.win) then
        vim.api.nvim_win_close(term.win, true)
        term.win = nil
        return true
    end
    return false
end

---@param config table effective float configuration
---@param id string|number|nil float id, or nil for the current float
---@return boolean
local function float_is_open(config, id)
    if id == nil then
        id = config.prev_id
    end
    local term = config.terms[id]
    return valid_win(term and term.win) == true
end

---@param config table effective float configuration
---@param opts? table may carry `id`
---@return boolean|nil ok
---@return string|nil err
local function toggle_float(config, opts)
    local id, err = resolve_id(config, opts)
    if not id then
        return nil, err
    end
    if float_is_open(config, id) then
        return close_float(config, id)
    end
    return open_float(config, id)
end

local function setup(config)
    ---Open the float for `opts.id` (or the default id); focusing it when already open.
    ---@param opts? table may carry `id`
    ---@return boolean|nil ok
    ---@return string|nil err
    config.open = function(opts)
        local id, err = resolve_id(config, opts)
        if not id then
            return nil, err
        end
        if float_is_open(config, id) then
            local term = config.terms[id]
            vim.api.nvim_set_current_win(term.win)
            return true
        end
        return open_float(config, id)
    end
    ---Close the float for the given id (or the current one when omitted).
    ---@param id_or_opts? string|number|table id, opts table with `id`, or nil
    ---@return boolean|nil closed true when a window was closed
    ---@return string|nil err
    config.close = function(id_or_opts)
        local id = id_or_opts
        if type(id_or_opts) == 'table' then
            id = id_or_opts.id
        end
        return close_float(config, id)
    end
    ---Whether the float for the given id (or the current one) is open.
    ---@param id_or_opts? string|number|table id, opts table with `id`, or nil
    ---@return boolean
    config.is_open = function(id_or_opts)
        local id = id_or_opts
        if type(id_or_opts) == 'table' then
            id = id_or_opts.id
        end
        return float_is_open(config, id)
    end
    ---Toggle the float for `opts.id` (or the default id).
    ---@param opts? table may carry `id`
    ---@return boolean|nil ok
    ---@return string|nil err
    config.toggle = function(opts)
        return toggle_float(config, opts)
    end
    config.terms = {}
    config.prev_id = nil
    vim.api.nvim_create_autocmd('VimResized', {
        callback = function()
            if not config.prev_id then
                return
            end
            local term = config.terms[config.prev_id]
            if valid_win(term.win) then
                vim.api.nvim_win_set_config(term.win, get_win_opts(config))
            end
        end,
    })
    return config
end
---Apply user options and build an independent floating-window instance.
---@param opts? table option overrides
---@return table instance with open/close/toggle/is_open methods
M.setup = function(opts)
    local config = vim.tbl_deep_extend('force', defaults, opts or {})
    return setup(config)
end

---@type table|nil shared default instance, created on first use
local default_instance = nil

---@return table the shared default float instance
local function default()
    if not default_instance then
        default_instance = M.setup()
    end
    return default_instance
end

---Open (or focus) a float on the shared default instance.
---@param opts? table may carry `id`, `cmd`, `cwd`
---@return boolean|nil ok
---@return string|nil err
function M.open(opts)
    return default().open(opts)
end

---Close a float on the shared default instance.
---@param id_or_opts? string|number|table id, opts table with `id`, or nil for current
---@return boolean|nil closed true when a window was closed
---@return string|nil err
function M.close(id_or_opts)
    return default().close(id_or_opts)
end

---Toggle a float on the shared default instance.
---@param opts? table may carry `id`
---@return boolean|nil ok
---@return string|nil err
function M.toggle(opts)
    return default().toggle(opts)
end

---Whether a float on the shared default instance is open.
---@param id_or_opts? string|number|table id, opts table with `id`, or nil for current
---@return boolean
function M.is_open(id_or_opts)
    return default().is_open(id_or_opts)
end

return M
