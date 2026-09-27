-- lua/dev/apps/init.lua
-- Qompass AI Diver Dev Apps Launcher
-- Copyright (C) 2026 Qompass AI, All rights reserved.
-- ----------------------------------------------------------------------------
-- Generic launcher for interactive CLI/TUI applications (btop, neomutt, ...).
-- One module drives every app in catalog.lua: adding an application is data
-- in the catalog, never a new module. Always uses argv form, never a shell
-- string. Commands: :Apps, :AppsInfo, :AppsClose (see commands.lua).
-- ----------------------------------------------------------------------------

local M = {}

local api = vim.api
local fn = vim.fn

local FLOAT_WIDTH_RATIO = 0.85
local FLOAT_HEIGHT_RATIO = 0.8
local FLOAT_ROW_RATIO = 0.1
local FLOAT_COL_RATIO = 0.075
local SPLIT_HEIGHT_LINES = 15
local ROOT_MARKERS = {
    '.git',
    '.jj',
    'Cargo.toml',
    'go.mod',
    'package.json',
    'pyproject.toml',
}

local catalog = require('dev.apps.catalog')
local commands = require('dev.apps.commands')

---@class DevAppInstance
---@field name string catalog key of the running app
---@field job_id integer terminal job/channel id

---@type table<integer, DevAppInstance> terminal bufnr -> instance
local open_instances = {}
local autocmds_registered = false
local commands_registered = false

--- Validate one catalog entry. User-supplied entries return (false, err);
--- the seeded catalog is asserted in setup().
---@param spec any
---@return boolean ok, string? err
local function valid_spec(spec)
    if type(spec) ~= 'table' then
        return false, 'spec must be a table'
    end
    if type(spec.cmd) ~= 'table' or #spec.cmd == 0 then
        return false, 'spec.cmd must be a non-empty array'
    end
    for i, part in ipairs(spec.cmd) do
        if type(part) ~= 'string' or part == '' then
            return false, string.format('spec.cmd[%d] must be a non-empty string', i)
        end
    end
    if type(spec.desc) ~= 'string' or spec.desc == '' then
        return false, 'spec.desc must be a non-empty string'
    end
    local kind = spec.kind or 'float'
    if kind ~= 'float' and kind ~= 'split' and kind ~= 'tab' then
        return false, "spec.kind must be 'float', 'split' or 'tab'"
    end
    local ctx = spec.ctx or 'none'
    if ctx ~= 'none' and ctx ~= 'file' and ctx ~= 'root' then
        return false, "spec.ctx must be 'none', 'file' or 'root'"
    end
    if spec.args ~= nil then
        if type(spec.args) ~= 'table' then
            return false, 'spec.args must be an array of strings'
        end
        for i, part in ipairs(spec.args) do
            if type(part) ~= 'string' then
                return false, string.format('spec.args[%d] must be a string', i)
            end
        end
    end
    if spec.env ~= nil and type(spec.env) ~= 'table' then
        return false, 'spec.env must be a table'
    end
    return true
end

--- Resolve the working directory for a ctx value.
---@param ctx string 'none'|'file'|'root'
---@return string cwd
local function resolve_cwd(ctx)
    if ctx == 'file' then
        local name = api.nvim_buf_get_name(0)
        if name ~= '' then
            return fn.fnamemodify(name, ':p:h')
        end
        return fn.getcwd()
    end
    if ctx == 'root' then
        local found = vim.fs.find(ROOT_MARKERS, { upward = true })
        if #found > 0 then
            return fn.fnamemodify(found[1], ':p:h')
        end
        return fn.getcwd()
    end
    return fn.getcwd()
end

--- Open a centered floating window holding a fresh scratch buffer.
---@return integer winid, integer bufnr
local function open_float()
    local width = math.floor(vim.o.columns * FLOAT_WIDTH_RATIO)
    local height = math.floor(vim.o.lines * FLOAT_HEIGHT_RATIO)
    local row = math.floor(vim.o.lines * FLOAT_ROW_RATIO)
    local col = math.floor(vim.o.columns * FLOAT_COL_RATIO)
    local bufnr = api.nvim_create_buf(false, true)
    local winid = api.nvim_open_win(bufnr, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = row,
        col = col,
        style = 'minimal',
        border = 'rounded',
    })
    return winid, bufnr
end

--- Open a horizontal split holding a fresh scratch buffer.
---@return integer winid, integer bufnr
local function open_split()
    vim.cmd('belowright ' .. SPLIT_HEIGHT_LINES .. 'new')
    return api.nvim_get_current_win(), api.nvim_get_current_buf()
end

--- Open a new tab holding a fresh scratch buffer.
---@return integer winid, integer bufnr
local function open_tab()
    vim.cmd('tabnew')
    return api.nvim_get_current_win(), api.nvim_get_current_buf()
end

--- Launch a catalog app in a terminal. Argv form only, never a shell string.
---@param name string catalog key
---@param overrides { kind: string?, ctx: string?, env: table<string,string>?, args: string[]? }?
---@return integer? bufnr, string? err
function M.open(name, overrides)
    if type(name) ~= 'string' or name == '' then
        return nil, 'app name must be a non-empty string'
    end
    local spec = catalog[name]
    if spec == nil then
        return nil, string.format("unknown app '%s'", name)
    end
    overrides = overrides or {}
    local kind = overrides.kind or spec.kind or 'float'
    if kind ~= 'float' and kind ~= 'split' and kind ~= 'tab' then
        return nil, string.format("invalid kind '%s'", tostring(kind))
    end
    local ctx = overrides.ctx or spec.ctx or 'none'
    if ctx ~= 'none' and ctx ~= 'file' and ctx ~= 'root' then
        return nil, string.format("invalid ctx '%s'", tostring(ctx))
    end
    local argv = {}
    for _, part in ipairs(spec.cmd) do
        argv[#argv + 1] = part
    end
    for _, part in ipairs(overrides.args or spec.args or {}) do
        if type(part) ~= 'string' then
            return nil, 'args must be strings'
        end
        argv[#argv + 1] = part
    end
    if fn.executable(argv[1]) ~= 1 then
        return nil, string.format("'%s' not found on PATH", argv[1])
    end
    local _, bufnr
    if kind == 'tab' then
        _, bufnr = open_tab()
    elseif kind == 'split' then
        _, bufnr = open_split()
    else
        _, bufnr = open_float()
    end
    local job_id = fn.termopen(argv, {
        cwd = resolve_cwd(ctx),
        env = overrides.env or spec.env,
    })
    if job_id <= 0 then
        api.nvim_buf_delete(bufnr, { force = true })
        return nil, string.format("failed to launch '%s'", argv[1])
    end
    open_instances[bufnr] = { name = name, job_id = job_id }
    vim.cmd('startinsert')
    return bufnr
end

--- Close tracked terminals for one app. Returns the count closed.
---@param name string catalog key
---@return integer closed, string? err
function M.close(name)
    if type(name) ~= 'string' or name == '' then
        return 0, 'app name must be a non-empty string'
    end
    local closed = 0
    for bufnr, inst in pairs(open_instances) do
        if inst.name == name and api.nvim_buf_is_valid(bufnr) then
            api.nvim_buf_delete(bufnr, { force = true })
            open_instances[bufnr] = nil
            closed = closed + 1
        end
    end
    return closed
end

--- Is at least one terminal for this app currently tracked?
---@param name string catalog key
---@return boolean
function M.is_open(name)
    for _, inst in pairs(open_instances) do
        if inst.name == name then
            return true
        end
    end
    return false
end

--- Sorted catalog keys. Deterministic: never pairs() order.
---@return string[]
function M.list()
    local names = {}
    for name in pairs(catalog) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

--- Resolved, deep-copied view of one app for :AppsInfo and the picker.
---@param name string catalog key
---@return table?
function M.info(name)
    local spec = catalog[name]
    if spec == nil then
        return nil
    end
    local ctx = spec.ctx or 'none'
    return {
        name = name,
        desc = spec.desc,
        cmd = vim.deepcopy(spec.cmd),
        kind = spec.kind or 'float',
        ctx = ctx,
        cwd = resolve_cwd(ctx),
        env = spec.env and vim.deepcopy(spec.env) or nil,
        open = M.is_open(name),
    }
end

--- Merge user apps, assert the seeded catalog, register commands. Idempotent.
---@param opts { apps: table<string, DevAppSpec>? }?
---@return table self
function M.setup(opts)
    opts = opts or {}
    if opts.apps ~= nil then
        if type(opts.apps) ~= 'table' then
            error('dev.apps setup: opts.apps must be a table', 2)
        end
        for name, spec in pairs(opts.apps) do
            local ok, err = valid_spec(spec)
            if not ok then
                error(string.format('dev.apps setup: bad spec for %s: %s', tostring(name), err), 2)
            end
            catalog[name] = spec
        end
    end
    for name, spec in pairs(catalog) do
        local ok, err = valid_spec(spec)
        assert(ok, string.format('dev.apps: bad catalog spec for %s: %s', name, err or '?'))
    end
    if not autocmds_registered then
        local group = api.nvim_create_augroup('DevApps', { clear = true })
        api.nvim_create_autocmd({ 'TermClose', 'BufWipeout' }, {
            group = group,
            desc = 'Forget closed dev-app terminals',
            callback = function(args)
                open_instances[args.buf] = nil
            end,
        })
        autocmds_registered = true
    end
    if not commands_registered then
        commands.register(M)
        commands_registered = true
    end
    return M
end

return M
