-- /qompassai/Diver/lua/tmux/init.lua
-- Qompass AI Diver Tmux Integration (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
-- The Neovim side of Matt's tmux setup
-- (~/workspace/repos/dotfiles/.config/tmux/tmux.conf).
--
-- - Seamless C-h/j/k/l navigation: when a Neovim window exists in the
--   direction, move there with :wincmd; otherwise, and only while $TMUX
--   is set, forward to `tmux select-pane`. Never shells out when not
--   inside tmux, and never navigates from a floating window.
-- - :TmuxLayout [name]: rebuild one of the named layouts in `layouts`
--   (windows + even splits, faithful to his conf's split bindings) with
--   `tmux new-window` / `split-window` argv calls, each step validated.
-- - :TmuxDocs, :TmuxValidate, :TmuxUpdateCheck: docs link, per-check
--   report, and the toolmgr release check against tmux/tmux.
--
-- Requiring this module registers nothing and performs no I/O;
-- M.setup() creates the user commands and keymaps. The herd module's
-- own tmux driver (lua/ai/herd/tmux.lua) is untouched: this module
-- never creates or names sessions, it only navigates panes and builds
-- windows inside the current session.
---@module 'tmux'

local M = {}

local api = vim.api

---Canonical tmux docs, verified 2026-09-27 (the tmux authors' wiki).
M.DOCS_URL = 'https://github.com/tmux/tmux/wiki'

---Newest tmux release known to this module, verified 2026-09-27
---(tag 3.7c, released 2026-08-17).
M.KNOWN_UPSTREAM_VERSION = '3.7c'

local WINDOWS_MAX = 16 -- most windows one layout may build.
local SPLITS_MAX = 8 -- most splits one layout window may hold.
local PROBE_BYTES_MAX = 256 -- most server-probe bytes kept in a report.
local DIR_TO_WINCMD = { left = 'h', down = 'j', up = 'k', right = 'l' }
local DIR_TO_TMUX = { left = '-L', down = '-D', up = '-U', right = '-R' }

M.default_config = {
    -- Canonical docs URL (verified 2026-09-27: the tmux authors' wiki).
    docs_url = 'https://github.com/tmux/tmux/wiki',
    -- Register the navigation keymaps; an occupied lhs is skipped with a
    -- notice, never overridden.
    keymaps_enabled = true,
    -- Newest tmux release known to this module (verified 2026-09-27).
    known_upstream_version = '3.7c',
    -- Named layouts; each entry is { window, splits, cwd, cmd }. The
    -- 'dev' layout mirrors his tmux.conf: the conf defines no named
    -- sessions or windows, only even 50% splits from the current path
    -- (bind-key s/v), so dev is one window with one even split.
    layouts = {
        dev = {
            {
                window = 'editor',
                splits = { { direction = 'horizontal', percent = 50 } },
            },
        },
        -- [extra] dev plus a plain shell window.
        ['dev-shell'] = {
            {
                window = 'editor',
                splits = { { direction = 'horizontal', percent = 50 } },
            },
            { window = 'shell' },
        },
    },
    -- Normal-mode key for navigating down.
    nav_down = '<C-j>',
    -- Normal-mode key for navigating left.
    nav_left = '<C-h>',
    -- Normal-mode key for navigating right.
    nav_right = '<C-l>',
    -- Normal-mode key for navigating up.
    nav_up = '<C-k>',
    -- vim.ui.select-compatible picker; override in tests.
    select_impl = vim.ui.select,
    -- Subprocess ceiling for every tmux call this module makes.
    timeout_ms = 5000,
    -- tmux binary name or absolute path.
    tmux_bin = 'tmux',
    -- His tmux.conf gates the C-\ binding on tmux >= 3.0; same floor here.
    tmux_version_min = '3.0',
    -- Canonical upstream repo (verified 2026-09-27).
    update_repo = 'tmux/tmux',
}

---Live configuration. Rebuilt from M.default_config on every setup().
---@type table
M.config = vim.deepcopy(M.default_config)

---Type-check one config option. Programmer errors raise; expected
---absences stay nil.
---@param name string Option name for the error message.
---@param value any Value to check.
---@param expected string Expected type() string.
---@param optional? boolean When true, nil is allowed.
local function check_type(name, value, expected, optional)
    if value == nil and optional then
        return
    end
    if type(value) ~= expected then
        error(('tmux: option %s must be %s, got %s'):format(name, expected, type(value)), 2)
    end
end

---Build the live config: factory defaults deep-copied, overrides merged,
---every key type-checked. Never mutates M.default_config.
---@param config table|nil Overrides; nil restores factory defaults.
---@return table merged Live config table.
function M.setup_config(config)
    check_type('config', config, 'table', true)
    local merged = vim.tbl_deep_extend('force', vim.deepcopy(M.default_config), config or {})
    check_type('docs_url', merged.docs_url, 'string')
    check_type('keymaps_enabled', merged.keymaps_enabled, 'boolean')
    check_type('known_upstream_version', merged.known_upstream_version, 'string')
    check_type('layouts', merged.layouts, 'table')
    check_type('nav_down', merged.nav_down, 'string')
    check_type('nav_left', merged.nav_left, 'string')
    check_type('nav_right', merged.nav_right, 'string')
    check_type('nav_up', merged.nav_up, 'string')
    check_type('select_impl', merged.select_impl, 'function')
    check_type('timeout_ms', merged.timeout_ms, 'number')
    check_type('tmux_bin', merged.tmux_bin, 'string')
    check_type('tmux_version_min', merged.tmux_version_min, 'string')
    check_type('update_repo', merged.update_repo, 'string')
    if merged.timeout_ms < 1 or merged.timeout_ms > 300000 then
        error('tmux: timeout_ms must be 1..300000', 2)
    end
    if merged.tmux_bin == '' then
        error('tmux: tmux_bin must not be blank', 2)
    end
    return merged
end

---@type utils.toolmgr.Migration[]
local MIGRATIONS_TMUX = {
    {
        version = '3.7c',
        description = '[template] placeholder for tmux config changes; no-op until a real 3.7c+ change is verified',
        apply = function()
            return true, 'template migration: no changes applied'
        end,
    },
}

local setup_done = false

---True while Neovim runs inside a tmux client ($TMUX set and non-empty).
---@return boolean
function M.inside_tmux()
    local tmux_env = vim.env.TMUX
    return tmux_env ~= nil and tmux_env ~= ''
end

---True when the configured tmux binary is on PATH.
---@return boolean
function M.tmux_available()
    return vim.fn.executable(M.config.tmux_bin) == 1
end

---Installed tmux version via `tmux -V` (dotted, e.g. '3.7').
---@return string|nil version
---@return string|nil err
function M.tmux_version()
    local toolmgr = require('utils.toolmgr')
    return toolmgr.command_version({ M.config.tmux_bin, '-V' })
end

---Whether a Neovim window exists in direction. Test seam: override in
---tests to steer navigation without moving windows.
---@param direction string 'left'|'right'|'up'|'down'
---@return boolean
function M.win_in_direction(direction)
    local flag = DIR_TO_WINCMD[direction]
    assert(flag ~= nil, 'direction must be one of left/right/up/down')
    local target = vim.fn.winnr(flag)
    local current = vim.fn.winnr()
    return target ~= 0 and target ~= current
end

---True when a floating window is focused; navigation never fires there.
---@return boolean
local function floating_focused()
    local win_config = api.nvim_win_get_config(0)
    local relative = win_config.relative
    return relative ~= nil and relative ~= ''
end

---Move in direction: :wincmd when a Neovim window exists there, else
---`tmux select-pane` when inside tmux. Returns (true, 'nvim'|'tmux')
---when something moved, (false, reason) when nothing did, (nil, err) on
---tmux failure. Never shells out when not inside tmux.
---@param direction string 'left'|'right'|'up'|'down'
---@return boolean|nil moved
---@return string|nil where_or_err
function M.navigate(direction)
    if DIR_TO_WINCMD[direction] == nil then
        return nil, 'unknown direction: ' .. tostring(direction)
    end
    if floating_focused() then
        return false, 'floating window focused; navigation skipped'
    end
    if M.win_in_direction(direction) then
        vim.cmd('wincmd ' .. DIR_TO_WINCMD[direction])
        return true, 'nvim'
    end
    if not M.inside_tmux() then
        return false, 'not inside tmux; no Neovim window in that direction'
    end
    if not M.tmux_available() then
        return false, 'tmux is unavailable'
    end
    local rce = require('security.rce')
    local result, exec_err = rce.safe_exec(
        { M.config.tmux_bin, 'select-pane', DIR_TO_TMUX[direction] },
        { timeout_ms = M.config.timeout_ms }
    )
    if exec_err ~= nil then
        return nil, exec_err
    end
    assert(result ~= nil, 'safe_exec returned no error but no result')
    if result.code ~= 0 then
        return nil, ('tmux select-pane exited %d'):format(result.code)
    end
    return true, 'tmux'
end

---Direction list paired with its configured key, in fixed order.
---@return { direction: string, lhs: string }[]
local function nav_bindings()
    return {
        { direction = 'down', lhs = M.config.nav_down },
        { direction = 'left', lhs = M.config.nav_left },
        { direction = 'right', lhs = M.config.nav_right },
        { direction = 'up', lhs = M.config.nav_up },
    }
end

---Register the navigation keymaps. An occupied lhs is skipped, never
---overridden; one notice names every skipped key.
local function register_keymaps()
    if not M.config.keymaps_enabled then
        return
    end
    local skipped = {}
    for _, binding in ipairs(nav_bindings()) do
        local direction = binding.direction
        local lhs = binding.lhs
        if vim.fn.maparg(lhs, 'n') ~= '' then
            skipped[#skipped + 1] = lhs .. ' (' .. direction .. ')'
        else
            vim.keymap.set('n', lhs, function()
                local moved, note = M.navigate(direction)
                if moved == nil then
                    vim.notify('tmux: navigation failed: ' .. tostring(note), vim.log.levels.ERROR)
                elseif not moved then
                    vim.notify('tmux: ' .. tostring(note), vim.log.levels.INFO)
                end
            end, { silent = true, noremap = true, desc = 'Tmux: navigate ' .. direction })
        end
    end
    if #skipped > 0 then
        vim.notify(
            'tmux: keymaps already mapped, skipping tmux navigation for: ' .. table.concat(skipped, ', '),
            vim.log.levels.WARN
        )
    end
end

---Sorted layout names for pickers and completion.
---@return string[]
function M.layout_names()
    local names = {}
    for name, _ in pairs(M.config.layouts) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

---Validate one split entry { direction, percent }.
---@param split any
---@return string|nil err
local function validate_split(split)
    if type(split) ~= 'table' then
        return 'split must be a table'
    end
    local direction = split.direction
    if direction ~= 'horizontal' and direction ~= 'vertical' then
        return 'split direction must be "horizontal" or "vertical"'
    end
    local percent = split.percent
    if type(percent) ~= 'number' or percent ~= math.floor(percent) or percent < 1 or percent > 99 then
        return 'split percent must be an integer 1..99'
    end
    return nil
end

---Validate one layout entry { window, splits, cwd, cmd }.
---@param entry any
---@return string|nil err
local function validate_entry(entry)
    if type(entry) ~= 'table' then
        return 'layout entry must be a table'
    end
    if type(entry.window) ~= 'string' or entry.window == '' then
        return 'layout entry window must be a non-empty string'
    end
    local splits = entry.splits or {}
    if type(splits) ~= 'table' then
        return 'layout entry splits must be a list'
    end
    if #splits > SPLITS_MAX then
        return ('layout entry holds %d splits; at most %d'):format(#splits, SPLITS_MAX)
    end
    for _, split in ipairs(splits) do
        local split_err = validate_split(split)
        if split_err ~= nil then
            return 'split in window ' .. entry.window .. ': ' .. split_err
        end
    end
    if entry.cwd ~= nil and type(entry.cwd) ~= 'string' then
        return 'layout entry cwd must be a string'
    end
    if entry.cmd ~= nil and type(entry.cmd) ~= 'string' then
        return 'layout entry cmd must be a string'
    end
    return nil
end

---Validate a named layout from M.config.layouts.
---@param name string
---@return boolean ok
---@return string|nil err
function M.validate_layout(name)
    local layout = M.config.layouts[name]
    if layout == nil then
        return false, 'unknown layout: ' .. tostring(name)
    end
    if type(layout) ~= 'table' or #layout == 0 then
        return false, 'layout ' .. name .. ' must be a non-empty list of entries'
    end
    if #layout > WINDOWS_MAX then
        return false, ('layout %s holds %d windows; at most %d'):format(name, #layout, WINDOWS_MAX)
    end
    for _, entry in ipairs(layout) do
        local entry_err = validate_entry(entry)
        if entry_err ~= nil then
            return false, 'layout ' .. name .. ': ' .. entry_err
        end
    end
    return true, nil
end

---Run one tmux argv step; (true) or (nil, err). safe_exec reports
---spawn and timeout failures; a non-zero exit is checked here.
---@param argv string[]
---@param op string Operation label for error messages.
---@return boolean|nil ok
---@return string|nil err
local function run_step(argv, op)
    local rce = require('security.rce')
    local result, exec_err = rce.safe_exec(argv, { timeout_ms = M.config.timeout_ms })
    if exec_err ~= nil then
        return nil, 'tmux ' .. op .. ' failed: ' .. exec_err
    end
    assert(result ~= nil, 'safe_exec returned no error but no result')
    if result.code ~= 0 then
        return nil, ('tmux %s exited %d'):format(op, result.code)
    end
    return true, nil
end

---Build a named layout inside the current tmux session: one new-window
---per entry, then that entry's splits. Refuses when not inside tmux or
---when tmux is absent. Each step is validated; stops at the first
---failure. Never creates sessions (herd owns session naming).
---@param name string Layout name from M.config.layouts.
---@return boolean|nil ok
---@return string|nil err
function M.apply_layout(name)
    local valid, valid_err = M.validate_layout(name)
    if not valid then
        return nil, valid_err
    end
    assert(valid_err == nil, 'validate_layout returned false but no error')
    if not M.inside_tmux() then
        return nil, 'not inside tmux; refusing to build layout ' .. name
    end
    if not M.tmux_available() then
        return nil, 'tmux is unavailable'
    end
    local bin = M.config.tmux_bin
    local layout = M.config.layouts[name]
    assert(type(layout) == 'table', 'validated layout must be a table')
    for _, entry in ipairs(layout) do
        local cwd = entry.cwd
        if cwd ~= nil and vim.fn.isdirectory(cwd) ~= 1 then
            return nil, 'layout ' .. name .. ': cwd is not a directory: ' .. cwd
        end
        local new_argv = { bin, 'new-window', '-n', entry.window }
        if cwd ~= nil then
            new_argv[#new_argv + 1] = '-c'
            new_argv[#new_argv + 1] = cwd
        end
        if entry.cmd ~= nil then
            new_argv[#new_argv + 1] = entry.cmd
        end
        local win_ok, win_err = run_step(new_argv, 'new-window')
        if not win_ok then
            return nil, 'layout ' .. name .. ': ' .. tostring(win_err)
        end
        for _, split in ipairs(entry.splits or {}) do
            local split_argv = {
                bin,
                'split-window',
                '-t',
                entry.window,
                split.direction == 'horizontal' and '-h' or '-v',
                '-p',
                tostring(split.percent),
            }
            if cwd ~= nil then
                split_argv[#split_argv + 1] = '-c'
                split_argv[#split_argv + 1] = cwd
            end
            if entry.cmd ~= nil then
                split_argv[#split_argv + 1] = entry.cmd
            end
            local split_ok, split_err = run_step(split_argv, 'split-window')
            if not split_ok then
                return nil, 'layout ' .. name .. ': ' .. tostring(split_err)
            end
        end
    end
    return true, nil
end

---The :TmuxValidate checks. Pure data; statuses are 'ok' or
---'unavailable', never an error.
---@return { name: string, status: string, detail: string }[]
function M.checks()
    local toolmgr = require('utils.toolmgr')
    local checks = {}
    local bin = M.config.tmux_bin
    local present = toolmgr.binary_present(bin)
    checks[#checks + 1] = {
        name = 'binary',
        status = present and 'ok' or 'unavailable',
        detail = present and (bin .. ' on PATH') or (bin .. ' not found on PATH'),
    }
    local version, version_err = M.tmux_version()
    local version_ok = false
    local version_detail
    if version == nil then
        version_detail = 'version unreadable: ' .. tostring(version_err)
    else
        version_ok = toolmgr.compare_versions(version, M.config.tmux_version_min) >= 0
        version_detail = version .. (version_ok and ' meets minimum ' or ' below minimum ') .. M.config.tmux_version_min
    end
    checks[#checks + 1] = {
        name = 'version',
        status = version_ok and 'ok' or 'unavailable',
        detail = version_detail,
    }
    local inside = M.inside_tmux()
    checks[#checks + 1] = {
        name = 'inside',
        status = inside and 'ok' or 'unavailable',
        detail = inside and '$TMUX is set' or '$TMUX is not set (not inside tmux)',
    }
    local server_ok = false
    local server_detail = 'skipped: not inside tmux'
    if inside and present then
        local rce = require('security.rce')
        local result, probe_err = rce.safe_exec(
            { bin, 'display-message', '-p', '#{session_name}' },
            { timeout_ms = M.config.timeout_ms }
        )
        if probe_err == nil and result ~= nil and result.code == 0 then
            server_ok = true
            server_detail = 'server answered: ' .. vim.trim(result.stdout or ''):sub(1, PROBE_BYTES_MAX)
        else
            server_detail = 'server probe failed: ' .. tostring(probe_err)
        end
    elseif inside then
        server_detail = 'skipped: tmux unavailable'
    end
    checks[#checks + 1] = {
        name = 'server',
        status = server_ok and 'ok' or 'unavailable',
        detail = server_detail,
    }
    local key_detail
    local key_ok = true
    if not M.config.keymaps_enabled then
        key_detail = 'disabled (keymaps_enabled = false)'
    else
        local states = {}
        for _, binding in ipairs(nav_bindings()) do
            local map = vim.fn.maparg(binding.lhs, 'n', false, true)
            local desc = type(map) == 'table' and map.desc or ''
            local state
            if type(desc) == 'string' and desc:find('^Tmux: navigate', 1) == 1 then
                state = 'ours'
            elseif vim.fn.maparg(binding.lhs, 'n') ~= '' then
                state = 'collision'
                key_ok = false
            else
                state = 'missing'
                key_ok = false
            end
            states[#states + 1] = binding.lhs .. '=' .. state
        end
        key_detail = table.concat(states, ' ')
    end
    checks[#checks + 1] = {
        name = 'keymaps',
        status = key_ok and 'ok' or 'unavailable',
        detail = key_detail,
    }
    return checks
end

---The toolmgr update spec for tmux. Pure data; current_version is nil
---when the tool is absent, which check_update treats as "not installed".
---@return utils.toolmgr.UpdateSpec[]
function M.update_specs()
    local toolmgr = require('utils.toolmgr')
    local cfg = M.config
    local current = toolmgr.command_version({ cfg.tmux_bin, '-V' })
    return {
        {
            tool_label = 'tmux',
            repo = cfg.update_repo,
            package = 'tmux',
            current_version = current,
            known_upstream_version = cfg.known_upstream_version,
            migrations = MIGRATIONS_TMUX,
            select_impl = cfg.select_impl,
        },
    }
end

---:TmuxLayout [name] -- build a named layout; picker when omitted.
---@param cmd_opts table nvim_create_user_command callback options.
local function cmd_layout(cmd_opts)
    local name = vim.trim(cmd_opts.args or '')
    local function apply(layout_name)
        local ok, err = M.apply_layout(layout_name)
        if not ok then
            vim.notify('TmuxLayout: ' .. tostring(err), vim.log.levels.ERROR)
            return
        end
        vim.notify('tmux: layout ' .. layout_name .. ' applied', vim.log.levels.INFO)
    end
    if name ~= '' then
        apply(name)
        return
    end
    local names = M.layout_names()
    if #names == 0 then
        vim.notify('TmuxLayout: no layouts configured', vim.log.levels.WARN)
        return
    end
    M.config.select_impl(names, { prompt = 'Tmux layout:' }, function(_, choice_idx)
        if choice_idx == nil or choice_idx < 1 or choice_idx > #names then
            return
        end
        apply(names[choice_idx])
    end)
end

---:TmuxDocs -- open the verified upstream tmux documentation.
local function cmd_docs()
    local url = M.config.docs_url
    local opened = vim.ui.open ~= nil and pcall(vim.ui.open, url)
    if not opened then
        vim.notify('tmux docs: ' .. url, vim.log.levels.INFO)
    end
end

---:TmuxValidate -- one vim.notify per check; missing pieces say
---"unavailable", never an error.
local function cmd_validate()
    for _, check in ipairs(M.checks()) do
        local level = check.status == 'ok' and vim.log.levels.INFO or vim.log.levels.WARN
        vim.notify(('tmux %-8s %-13s %s'):format(check.name, check.status, check.detail), level)
    end
end

---:TmuxUpdateCheck -- toolmgr update dialog for tmux.
local function cmd_update_check()
    local toolmgr = require('utils.toolmgr')
    for _, spec in ipairs(M.update_specs()) do
        toolmgr.check_update(spec)
    end
end

---Register commands and keymaps. Idempotent: commands are created once;
---the config is rebuilt on every call. Performs no subprocess I/O.
---@param config? table Overrides merged over M.default_config.
function M.setup(config)
    M.config = M.setup_config(config)
    register_keymaps()
    if setup_done then
        return
    end
    setup_done = true
    api.nvim_create_user_command('TmuxLayout', cmd_layout, {
        nargs = '?',
        complete = function(arg_lead, _, _)
            local names = {}
            for _, name in ipairs(M.layout_names()) do
                if name:sub(1, #arg_lead) == arg_lead then
                    names[#names + 1] = name
                end
            end
            return names
        end,
        desc = 'Build a named tmux layout inside the current session',
    })
    api.nvim_create_user_command('TmuxDocs', cmd_docs, { desc = 'Open the tmux documentation' })
    api.nvim_create_user_command('TmuxValidate', cmd_validate, { desc = 'Per-check tmux validation report' })
    api.nvim_create_user_command('TmuxUpdateCheck', cmd_update_check, { desc = 'tmux release check via toolmgr' })
end

return M
