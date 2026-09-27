-- /qompassai/Diver/lua/jj/init.lua
-- Qompass AI Diver Jujutsu (jj) Integration (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Native jj (Jujutsu) surface: status/log/diff floats, change creation and
-- squash behind explicit confirmation, a GPG-signing report, and per-tool
-- validation/update checks. Mirrors the sensibilities of his
-- ~/.config/jj/config.toml (GPG signing backend, 72-col commit messages,
-- delta pager): a signing report and a 72-col message linter are built in.
--
-- Requiring this module registers nothing and performs no I/O; M.setup()
-- creates the user commands. Every subprocess goes through
-- security.rce.safe_exec in argv form. A missing binary or a cwd outside
-- a jj repo reports "unavailable" / "not a jj repo", never an error. jj
-- and git repos can coexist; repo detection probes jj itself (`jj root`)
-- and never infers one VCS from the other.
---@module 'jj'

local M = {}

local api = vim.api

local rce = require('security.rce')

local setup_done = false

---Oldest jj this module supports. Verified: v0.44.0 released 2026-08-05.
M.JJ_VERSION_MIN = '0.44.0'

local OUTPUT_LINES_MAX = 4000 -- output lines kept for any float view.
local MESSAGE_BYTES_MAX = 65536 -- cap on a commit message scanned for width.
local MESSAGE_LINE_COLS = 72 -- his config.toml commit.message-line-length.
local LOG_LINES_CAP = 1000 -- hard cap on :Jj log revisions.

---@class jj.Check
---@field name string Tool or aspect probed, e.g. 'signing'.
---@field status 'ok'|'unavailable'|'below minimum'
---@field detail string One-line human summary.

---@class jj.SigningInfo
---@field backend string e.g. 'gpg'.
---@field behavior string|nil e.g. 'own'.

M.default_config = {
    -- Ask for an explicit vim.ui.select confirmation before `jj new` /
    -- `jj squash`; writes never happen without it.
    confirm_writes = true,
    -- Canonical jj docs (verified 2026-09-27).
    docs_url = 'https://docs.jj-vcs.dev/latest',
    -- Rows of the :Jj st/log/diff float.
    float_height = 24,
    -- Cols of the :Jj st/log/diff float.
    float_width = 100,
    -- Binary probed on PATH; overridable for tests.
    jj_bin = 'jj',
    -- Oldest supported jj; see M.JJ_VERSION_MIN.
    jj_version_min = '0.44.0',
    -- Newest jj this module knows about (verified: v0.45.1 on GitHub releases).
    known_upstream_version = '0.45.1',
    -- Revisions fetched by :Jj log (clamped to LOG_LINES_CAP).
    log_limit = 200,
    -- vim.ui.select replacement; nil uses the real one (test seam).
    select_impl = nil,
    -- Wall-clock cap per jj subprocess.
    timeout_ms = 30000,
    -- Upstream repo for :JjUpdateCheck release lookups.
    update_repo = 'jj-vcs/jj',
}

---Live configuration. Rebuilt from M.default_config on every setup().
---@type table
M.config = vim.deepcopy(M.default_config)

---Placeholder migrations: no upstream jj config-key rename is known, so
---the entry documents the migration shape as a clearly-marked template
---(no-op apply). Replace with a real migration when upstream renames a
---key we depend on.
local MIGRATIONS_NOTE = '[template] no upstream jj config rename known; shape only, no-op'

---@type utils.toolmgr.Migration[]
local MIGRATIONS_JJ = {
    {
        version = '0.45.1',
        description = MIGRATIONS_NOTE,
        apply = function()
            return true, 'template migration: no changes applied'
        end,
    },
}

---Type-check one config option. Programmer errors raise; expected
---absences (nil optionals) stay nil.
---@param name string Option name for the error message.
---@param value any Value to check.
---@param expected string Expected type() string.
---@param optional? boolean When true, nil is allowed.
local function check_type(name, value, expected, optional)
    if value == nil and optional then
        return
    end
    if type(value) ~= expected then
        error(('jj: option %s must be %s, got %s'):format(name, expected, type(value)), 2)
    end
end

---Build the live config: factory defaults deep-copied, overrides merged,
---every key type-checked. Never mutates M.default_config.
---@param config table|nil Overrides; nil restores factory defaults.
---@return table merged Live config table.
function M.setup_config(config)
    check_type('config', config, 'table', true)
    local merged = vim.tbl_deep_extend('force', vim.deepcopy(M.default_config), config or {})
    check_type('confirm_writes', merged.confirm_writes, 'boolean')
    check_type('docs_url', merged.docs_url, 'string')
    check_type('float_height', merged.float_height, 'number')
    check_type('float_width', merged.float_width, 'number')
    check_type('jj_bin', merged.jj_bin, 'string')
    check_type('jj_version_min', merged.jj_version_min, 'string')
    check_type('known_upstream_version', merged.known_upstream_version, 'string')
    check_type('log_limit', merged.log_limit, 'number')
    check_type('select_impl', merged.select_impl, 'function', true)
    check_type('timeout_ms', merged.timeout_ms, 'number')
    check_type('update_repo', merged.update_repo, 'string')
    if vim.trim(merged.jj_bin) == '' then
        error('jj: option jj_bin must not be blank', 2)
    end
    if vim.trim(merged.update_repo) == '' then
        error('jj: option update_repo must not be blank', 2)
    end
    return merged
end

---Map a toolmgr binary report onto the jj.Check status vocabulary.
---@param report utils.toolmgr.BinaryReport
---@return jj.Check
local function to_check(report)
    local status = 'unavailable'
    if report.present and report.meets_minimum then
        status = 'ok'
    elseif report.present then
        status = 'below minimum'
    end
    return { name = report.name, status = status, detail = report.detail }
end

---Run jj with an argv tail, prefixing the global non-interactive flags so
---piped output never invokes a pager or emits color escapes. Refuses
---before spawning when the binary is absent.
---@param argv_tail string[] argv words after 'jj'.
---@param opts? { cwd?: string, timeout_ms?: integer }
---@return vim.SystemCompleted|nil result
---@return string|nil err
function M.run_jj(argv_tail, opts)
    local bin = M.config.jj_bin
    local toolmgr = require('utils.toolmgr')
    if not toolmgr.binary_present(bin) then
        return nil, bin .. ' is unavailable on PATH'
    end
    local argv = { bin, '--color=never', '--no-pager' }
    for _, word in ipairs(argv_tail) do
        argv[#argv + 1] = word
    end
    local exec_opts = { timeout_ms = M.config.timeout_ms }
    if opts ~= nil then
        exec_opts.cwd = opts.cwd
        if opts.timeout_ms ~= nil then
            exec_opts.timeout_ms = opts.timeout_ms
        end
    end
    return rce.safe_exec(argv, exec_opts)
end

---jj repo root for cwd, probed with the read-only `jj root` (never with
---git state; the two VCSs can coexist).
---@param cwd? string Directory to probe (default: current).
---@return string|nil root
---@return string|nil err
function M.repo_root(cwd)
    local result, exec_err = M.run_jj({ 'root' }, { cwd = cwd or vim.fn.getcwd() })
    if exec_err ~= nil then
        return nil, exec_err
    end
    assert(result ~= nil, 'safe_exec returned no error but no result')
    if result.code ~= 0 then
        return nil, 'not inside a jj repo'
    end
    local root = vim.trim(result.stdout or '')
    if root == '' then
        return nil, 'jj root returned an empty path'
    end
    return root, nil
end

---Whether cwd sits inside a jj repo.
---@param cwd? string Directory to probe (default: current).
---@return boolean
function M.in_repo(cwd)
    return M.repo_root(cwd) ~= nil
end

---Trim command output to the float bound. Pure: non-table input yields an
---empty list, never an error.
---@param lines any
---@return string[] kept
function M.trim_output(lines)
    if type(lines) ~= 'table' then
        return {}
    end
    local kept = {}
    for index = 1, math.min(#lines, OUTPUT_LINES_MAX) do
        kept[#kept + 1] = lines[index]
    end
    return kept
end

---Lint a commit message against his config.toml message-line-length = 72.
---Pure: returns every line over the limit; non-strings and oversized
---input return nil + err, never throw.
---@param message string Commit message to scan.
---@return { lnum: integer, len: integer }[]|nil exceed
---@return string|nil err
function M.check_message_lines(message)
    if type(message) ~= 'string' then
        return nil, 'message must be a string'
    end
    if #message > MESSAGE_BYTES_MAX then
        return nil, ('message exceeds MESSAGE_BYTES_MAX=%d bytes'):format(MESSAGE_BYTES_MAX)
    end
    local exceed = {}
    local lnum = 0
    for _, line in ipairs(vim.split(message, '\n', { plain = true })) do
        lnum = lnum + 1
        if #line > MESSAGE_LINE_COLS then
            exceed[#exceed + 1] = { lnum = lnum, len = #line }
        end
    end
    return exceed, nil
end

---GPG signing configuration, reported never enforced. Probes the same
---keys his config.toml sets ([signing] behavior="own", backend="gpg").
---Never throws; nil when unset or when jj is absent.
---@return jj.SigningInfo|nil info
function M.signing_info()
    local function config_get(key)
        local result, exec_err = M.run_jj({ 'config', 'get', key }, {})
        if exec_err ~= nil or result == nil or result.code ~= 0 then
            return nil
        end
        local value = vim.trim(result.stdout or '')
        if value == '' then
            return nil
        end
        return value
    end
    local backend = config_get('signing.backend')
    if backend == nil then
        return nil
    end
    return { backend = backend, behavior = config_get('signing.behavior') }
end

---Per-tool validation. Never throws: missing pieces are 'unavailable',
---never errors.
---@return jj.Check[] checks
function M.checks()
    local toolmgr = require('utils.toolmgr')
    local cfg = M.config
    local checks = {}
    checks[#checks + 1] = to_check(toolmgr.check_binary({
        name = cfg.jj_bin,
        version_argv = { cfg.jj_bin, '--version' },
        min_version = cfg.jj_version_min,
    }))
    local root = M.repo_root(vim.fn.getcwd())
    checks[#checks + 1] = {
        name = 'repo',
        status = root ~= nil and 'ok' or 'unavailable',
        detail = root ~= nil and ('jj repo root: ' .. root) or 'cwd is not inside a jj repo',
    }
    local signing = M.signing_info()
    if signing ~= nil then
        local behavior = signing.behavior ~= nil and (', behavior=' .. signing.behavior) or ''
        checks[#checks + 1] = {
            name = 'signing',
            status = 'ok',
            detail = ('signing.backend=%s%s (his config.toml sets backend=gpg)'):format(signing.backend, behavior),
        }
    else
        checks[#checks + 1] = {
            name = 'signing',
            status = 'unavailable',
            detail = 'signing not configured in jj config (his config.toml sets backend=gpg)',
        }
    end
    return checks
end

---Package name as this box's manager knows it. Arch extra/Fedora/nixpkgs
---and Debian 13+/Ubuntu 24.10+ ship `jujutsu`; the Homebrew formula is
---`jj` (verified against the jj install docs 2026-09-27).
---@param manager string|nil From utils.toolmgr.detect_package_manager().
---@return string package
function M.package_for_manager(manager)
    if manager == 'brew' then
        return 'jj'
    end
    return 'jujutsu'
end

---The toolmgr update spec for jj. Pure data; current_version is nil when
---the tool is absent, which check_update treats as "not installed".
---@return utils.toolmgr.UpdateSpec[]
function M.update_specs()
    local toolmgr = require('utils.toolmgr')
    local cfg = M.config
    local current = toolmgr.command_version({ cfg.jj_bin, '--version' })
    return {
        {
            tool_label = 'jj',
            repo = cfg.update_repo,
            package = M.package_for_manager(toolmgr.detect_package_manager()),
            current_version = current,
            known_upstream_version = cfg.known_upstream_version,
            migrations = MIGRATIONS_JJ,
            select_impl = cfg.select_impl,
        },
    }
end

---Open a centered, minimal float for command output. `q` closes it.
---@param lines string[] Body lines.
---@param title string Float title.
---@param buf_name string Scheme name so tests can find the buffer.
---@param width integer Desired width.
---@param height integer Desired height.
local function open_float(lines, title, buf_name, width, height)
    local buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_lines(buf, 0, -1, false, M.trim_output(lines))
    vim.bo[buf].modifiable = false
    vim.bo[buf].filetype = 'diver-jj'
    pcall(api.nvim_buf_set_name, buf, buf_name)
    local win_width = math.min(width, vim.o.columns - 4)
    local win_height = math.min(height, vim.o.lines - 4)
    api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = win_width,
        height = win_height,
        row = math.floor((vim.o.lines - win_height) / 2),
        col = math.floor((vim.o.columns - win_width) / 2),
        style = 'minimal',
        border = 'rounded',
        title = title,
        title_pos = 'center',
    })
    vim.keymap.set('n', 'q', '<cmd>close<cr>', { buffer = buf, silent = true, desc = 'Close jj float' })
end

---Notify a command failure in one canonical shape.
---@param what string Command name for the message.
---@param err any Failure reason.
local function notify_failed(what, err)
    vim.notify(what .. ' failed: ' .. tostring(err), vim.log.levels.ERROR)
end

---Repo root for the current directory, or nil after notifying.
---@return string|nil root
local function require_repo()
    local root, root_err = M.repo_root()
    if root_err ~= nil then
        vim.notify('Jj: ' .. root_err, vim.log.levels.ERROR)
        return nil
    end
    return root
end

---Show a read-only jj view (st/log/diff) in a float.
---@param sub 'st'|'log'|'diff'
local function show_readonly(sub)
    local root = require_repo()
    if root == nil then
        return
    end
    local argv
    if sub == 'st' then
        -- `st` is his config.toml alias for status; canonical verb runs it
        -- even without his aliases loaded.
        argv = { 'status' }
    elseif sub == 'log' then
        local count = math.min(math.max(M.config.log_limit, 1), LOG_LINES_CAP)
        argv = { 'log', '--limit', tostring(count) }
    else
        argv = { 'diff' }
    end
    local result, exec_err = M.run_jj(argv, { cwd = root })
    if exec_err ~= nil then
        notify_failed('Jj ' .. sub, exec_err)
        return
    end
    assert(result ~= nil, 'safe_exec returned no error but no result')
    if result.code ~= 0 then
        notify_failed('Jj ' .. sub, vim.trim(result.stderr or ''))
        return
    end
    local lines = vim.split(result.stdout or '', '\n', { plain = true })
    if #lines == 0 or (#lines == 1 and lines[1] == '') then
        vim.notify('Jj ' .. sub .. ': no output', vim.log.levels.INFO)
        return
    end
    open_float(lines, ' jj ' .. sub .. ' ', 'jj://' .. sub, M.config.float_width, M.config.float_height)
end

---Run a write op (new/squash) behind an explicit vim.ui.select
---confirmation. Refuses outside a repo; a cancelled prompt runs nothing.
---@param sub 'new'|'squash'
---@param extra string[] Extra argv words after the subcommand.
local function request_write(sub, extra)
    local root = require_repo()
    if root == nil then
        return
    end
    local function do_write()
        local argv = { sub }
        for _, word in ipairs(extra) do
            argv[#argv + 1] = word
        end
        local result, exec_err = M.run_jj(argv, { cwd = root })
        if exec_err ~= nil then
            notify_failed('Jj ' .. sub, exec_err)
            return
        end
        assert(result ~= nil, 'safe_exec returned no error but no result')
        if result.code ~= 0 then
            notify_failed('Jj ' .. sub, vim.trim(result.stderr or ''))
            return
        end
        local first = vim.trim((result.stdout or ''):match('^[^\n]*') or '')
        vim.notify('Jj ' .. sub .. ': ' .. (first ~= '' and first or 'done'), vim.log.levels.INFO)
    end
    if not M.config.confirm_writes then
        do_write()
        return
    end
    local impl = M.config.select_impl or vim.ui.select
    impl({ 'Yes, run jj ' .. sub, 'Cancel' }, { prompt = 'jj ' .. sub .. '?' }, function(choice)
        if choice == 1 then
            do_write()
        else
            vim.notify('Jj ' .. sub .. ': cancelled', vim.log.levels.INFO)
        end
    end)
end

---Subcommands offered by :Jj, in completion order.
local SUBCOMMANDS = { 'st', 'log', 'diff', 'new', 'squash' }

---Completion callback for :Jj: filters the five subcommands by prefix.
---@param arg_lead string Text being completed.
---@return string[] matches
function M.complete_subcommand(arg_lead)
    local matches = {}
    local lead = arg_lead or ''
    for _, name in ipairs(SUBCOMMANDS) do
        if name:sub(1, #lead) == lead then
            matches[#matches + 1] = name
        end
    end
    return matches
end

---:Jj dispatcher. Read-only views first; writes confirm first; unknown
---subcommands report plainly, never throw.
---@param cmd_opts table nvim_create_user_command callback options.
function M.cmd_jj(cmd_opts)
    local raw = cmd_opts ~= nil and cmd_opts.fargs or nil
    local args = type(raw) == 'table' and raw or {}
    local sub = args[1]
    if sub == nil or sub == '' then
        vim.notify('Jj: subcommand required: st | log | diff | new | squash', vim.log.levels.ERROR)
        return
    end
    if sub == 'st' or sub == 'log' or sub == 'diff' then
        show_readonly(sub)
        return
    end
    if sub == 'new' or sub == 'squash' then
        local extra = {}
        for index = 2, #args do
            extra[#extra + 1] = args[index]
        end
        request_write(sub, extra)
        return
    end
    vim.notify(
        'Jj: unknown subcommand "' .. tostring(sub) .. '" (st | log | diff | new | squash)',
        vim.log.levels.ERROR
    )
end

---:JjDocs -- open the verified upstream jj documentation.
local function cmd_docs()
    local url = M.config.docs_url
    local opened = vim.ui.open ~= nil and pcall(vim.ui.open, url)
    if not opened then
        vim.notify('jj docs: ' .. url, vim.log.levels.INFO)
    end
end

---:JjValidate -- one vim.notify per check; missing tools say
---"unavailable", never an error.
local function cmd_validate()
    for _, check in ipairs(M.checks()) do
        local level = check.status == 'ok' and vim.log.levels.INFO or vim.log.levels.WARN
        vim.notify(('jj %-8s %-13s %s'):format(check.name, check.status, check.detail), level)
    end
end

---:JjUpdateCheck -- toolmgr update dialog for jj.
local function cmd_update_check()
    local toolmgr = require('utils.toolmgr')
    for _, spec in ipairs(M.update_specs()) do
        toolmgr.check_update(spec)
    end
end

---Register the :Jj dispatcher and the :Jj* checks. Idempotent: commands
---are created once; the config is rebuilt on every call. Performs no
---subprocess I/O itself.
---@param config? table Overrides merged over M.default_config.
function M.setup(config)
    M.config = M.setup_config(config)
    if setup_done then
        return
    end
    setup_done = true
    api.nvim_create_user_command('Jj', function(cmd_opts)
        M.cmd_jj(cmd_opts)
    end, {
        nargs = '*',
        complete = function(arg_lead, _, _)
            return M.complete_subcommand(arg_lead)
        end,
        desc = 'Jujutsu: st | log | diff | new | squash (writes confirm first)',
    })
    api.nvim_create_user_command('JjDocs', cmd_docs, { desc = 'Open the upstream jj documentation' })
    api.nvim_create_user_command('JjValidate', cmd_validate, { desc = 'Per-tool validation report' })
    api.nvim_create_user_command('JjUpdateCheck', cmd_update_check, { desc = 'Update check for jj' })
end

return M
