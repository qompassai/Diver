-- /qompassai/Diver/lua/notify/init.lua
-- Qompass AI Diver Long-Task Notifications (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Desktop + in-editor toast notifications when long tasks finish. The model
-- is Matt's fish `done` plugin
-- (~/workspace/repos/dotfiles/.config/fish/conf.d/done.fish): a duration
-- threshold decides whether a finished task notifies at all; labels matching
-- exclude_patterns never notify; over-threshold tasks fire a vim.notify AND
-- a `notify-send` desktop toast, the duration humanized as "1m 5s" and
-- failures escalated to critical urgency.
--
-- Core seam -- wrap a unit of work, call done when it finishes:
--   local done = require('notify').wrap({ label = 'backup' })
--   done(exit_code)
--
-- One-shot path -- run argv through the threshold logic directly:
--   local result, err = require('notify').run({ 'make', 'test' }, { label = 'make test' })
--
-- Cargo composition (the cargo module is untouched; see lua/dev/cargo/init.lua):
--   local wrap = require('notify').wrap({ label = 'cargo test' })
--   cargo.run({ subcommand = 'test', on_exit = wrap })
-- cargo calls on_exit(info) with a JobInfo table carrying exit_code, so
-- done_fn accepts either a plain exit-code integer or a table with an
-- exit_code field.
--
-- Requiring this module registers nothing and performs no I/O;
-- M.setup() creates the user commands. The notify-send backend is
-- best-effort: an absent binary falls back to vim.notify only and is
-- never an error. NOTE: the editor notifier is always the global
-- vim.notify -- never a local named `notify`.
---@module 'notify'

local M = {}

local api = vim.api

---Config shape version this module writes. Bump it when a real config
---migration lands; :NotifyUpdateCheck offers pending migrations when the
---live config's version is older.
M.CONFIG_VERSION = '1.0'

local EXIT_CODE_UNKNOWN = -1 -- used when done_fn got no usable exit code.
local NOTIFY_SEND_EXPIRE_MS = 3000 -- desktop toast linger (done.fish default).
local SECONDS_PER_MINUTE = 60
local SECONDS_PER_HOUR = 3600
local THRESHOLD_MS_MAX = 86400000 -- longest notifiable threshold: one day.
local MS_PER_SECOND = 1000
local DOC_HALF_GAP = 2 -- half the margin kept around the docs float.

M.default_config = {
    -- vim.log level for below-threshold finishes; nil silences them.
    below_threshold_level = vim.log.levels.DEBUG,
    -- Test seam: fun(): integer wall-clock ms; defaults to vim.uv.now().
    clock_impl = function()
        return vim.uv.now()
    end,
    -- Config shape version the live config was built for.
    config_version = '1.0',
    -- Duration rendering style; 'human' is the only style (e.g. '1m 5s').
    duration_format = 'human',
    -- Labels containing any of these literal substrings never notify.
    exclude_patterns = {},
    -- notify-send binary (name or absolute path); a fake on PATH works.
    notify_send_bin = 'notify-send',
    -- Master switch for the desktop backend; false = vim.notify only.
    system_backend_enabled = true,
    -- done.fish's __done_min_cmd_duration: only tasks at least this long
    -- notify.
    threshold_ms = 5000,
    -- Subprocess ceiling for each notify-send spawn.
    timeout_ms = 3000,
    -- vim.log level for the in-editor side of over-threshold notices.
    vim_notify_level = vim.log.levels.INFO,
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
        error(('notify: option %s must be %s, got %s'):format(name, expected, type(value)), 2)
    end
end

---Validate one exclude_patterns entry: a non-empty literal string.
---@param pattern any
---@param index integer
local function check_pattern(pattern, index)
    if type(pattern) ~= 'string' or pattern == '' then
        error(('notify: exclude_patterns[%d] must be a non-empty string'):format(index), 2)
    end
end

---Build the live config: factory defaults deep-copied, overrides merged,
---every key type-checked. Never mutates M.default_config.
---@param config table|nil Overrides; nil restores factory defaults.
---@return table merged Live config table.
function M.setup_config(config)
    check_type('config', config, 'table', true)
    local merged = vim.tbl_deep_extend('force', vim.deepcopy(M.default_config), config or {})
    check_type('below_threshold_level', merged.below_threshold_level, 'number', true)
    check_type('clock_impl', merged.clock_impl, 'function', true)
    check_type('config_version', merged.config_version, 'string')
    check_type('duration_format', merged.duration_format, 'string')
    check_type('exclude_patterns', merged.exclude_patterns, 'table')
    check_type('notify_send_bin', merged.notify_send_bin, 'string')
    check_type('system_backend_enabled', merged.system_backend_enabled, 'boolean')
    check_type('threshold_ms', merged.threshold_ms, 'number')
    check_type('timeout_ms', merged.timeout_ms, 'number')
    check_type('vim_notify_level', merged.vim_notify_level, 'number')
    if merged.duration_format ~= 'human' then
        error('notify: duration_format must be "human"', 2)
    end
    for index, pattern in ipairs(merged.exclude_patterns) do
        check_pattern(pattern, index)
    end
    if merged.notify_send_bin == '' then
        error('notify: notify_send_bin must not be blank', 2)
    end
    local threshold = merged.threshold_ms
    if threshold ~= math.floor(threshold) or threshold < 1 or threshold > THRESHOLD_MS_MAX then
        error(('notify: threshold_ms must be an integer in [1, %d]'):format(THRESHOLD_MS_MAX), 2)
    end
    if merged.timeout_ms < 1 or merged.timeout_ms > 300000 then
        error('notify: timeout_ms must be 1..300000', 2)
    end
    return merged
end

---@type utils.toolmgr.Migration[]
local MIGRATIONS_NOTIFY = {
    {
        version = '1.0',
        description = '[template] placeholder for notify config changes; no-op until a real 1.0+ change is verified',
        apply = function()
            return true, 'template migration: no changes applied'
        end,
    },
}

local setup_done = false

---Wall-clock milliseconds. Honors the clock_impl test seam, which
---defaults to vim.uv.now().
---@return integer
function M.now_ms()
    local impl = M.config.clock_impl
    assert(type(impl) == 'function', 'clock_impl must be a function')
    return impl()
end

---True when label contains any exclude_patterns entry. Matches are
---plain substrings (string.find with plain = true) -- NOT Lua patterns,
---so magic characters like '.' or '%' match literally.
---@param label string Task label from wrap().
---@return boolean
function M.excluded(label)
    assert(type(label) == 'string', 'label must be a string')
    for _, pattern in ipairs(M.config.exclude_patterns) do
        if label:find(pattern, 1, true) ~= nil then
            return true
        end
    end
    return false
end

---Render milliseconds in done.fish's humanized style: '45s', '1m 5s',
---'2h 3m 4s'.
---@param ms number Non-negative milliseconds.
---@return string
function M.format_duration(ms)
    assert(type(ms) == 'number', 'ms must be a number')
    local total_seconds = math.floor(math.max(0, ms) / MS_PER_SECOND)
    local seconds = total_seconds % SECONDS_PER_MINUTE
    local minutes = math.floor(total_seconds / SECONDS_PER_MINUTE) % SECONDS_PER_MINUTE
    local hours = math.floor(total_seconds / SECONDS_PER_HOUR)
    if hours > 0 then
        return ('%dh %dm %ds'):format(hours, minutes, seconds)
    end
    if minutes > 0 then
        return ('%dm %ds'):format(minutes, seconds)
    end
    return ('%ds'):format(seconds)
end

---True when the configured notify-send binary is on PATH.
---@return boolean
function M.notify_send_available()
    local toolmgr = require('utils.toolmgr')
    return toolmgr.binary_present(M.config.notify_send_bin)
end

---Build the notify-send argv for one notification. Argv form only -- no
---shell, no interpolation of the label into a command string.
---@param title string Notification title (done.fish style).
---@param message string Notification body.
---@param exit_code integer Task exit code; non-zero escalates urgency.
---@return string[]
local function notify_send_argv(title, message, exit_code)
    local urgency = exit_code ~= 0 and 'critical' or 'normal'
    return {
        M.config.notify_send_bin,
        '--hint=int:transient:1',
        '--urgency=' .. urgency,
        '--icon=utilities-terminal',
        '--app-name=nvim',
        '--expire-time=' .. NOTIFY_SEND_EXPIRE_MS,
        title,
        message,
    }
end

---Fire the desktop backend. Best-effort: every failure mode returns
---(false, note) instead of raising or erroring -- the in-editor notice
---always goes out regardless.
---@param title string Notification title.
---@param message string Notification body.
---@param exit_code integer Task exit code.
---@return boolean sent
---@return string note
local function fire_system(title, message, exit_code)
    if not M.config.system_backend_enabled then
        return false, 'disabled (system_backend_enabled = false)'
    end
    if not M.notify_send_available() then
        return false, M.config.notify_send_bin .. ' not found on PATH'
    end
    local rce = require('security.rce')
    local result, exec_err = rce.safe_exec(notify_send_argv(title, message, exit_code), {
        timeout_ms = M.config.timeout_ms,
    })
    if exec_err ~= nil then
        return false, 'spawn failed: ' .. exec_err
    end
    assert(result ~= nil, 'safe_exec returned no error but no result')
    if result.code ~= 0 then
        return false, ('%s exited %d'):format(M.config.notify_send_bin, result.code)
    end
    return true, 'sent'
end

---@class notify.WrapOpts
---@field label string Task label shown in the notification body (required).
---@field threshold_ms? integer Override the configured threshold for this task.
---@field on_done? fun(info: notify.DoneInfo) Called with the outcome record.

---@class notify.DoneInfo
---@field label string Task label.
---@field duration_ms integer Wall clock wrap() -> done_fn(), in ms.
---@field exit_code integer Normalized exit code (-1 when unknown).
---@field notified boolean True when the threshold fired.
---@field system_notified boolean True when the desktop toast went out.
---@field system_note string What the desktop backend did or why it did not.

---The core seam: wrap a long task, get back a done_fn to call when it
---finishes. done_fn accepts either an exit-code integer or a table with
---an exit_code field (cargo's on_exit(info) passes a JobInfo). Returns
---(true, 'notified') when the threshold fired, (false, reason) when it
---did not (below threshold or excluded). Programmer errors in opts raise;
---the notification paths themselves never raise.
---@param opts notify.WrapOpts
---@return fun(exit_code: integer|table|nil): boolean, string done_fn
function M.wrap(opts)
    if type(opts) ~= 'table' then
        error('notify: wrap expects an options table, got ' .. type(opts), 2)
    end
    local label = opts.label
    if type(label) ~= 'string' or label == '' then
        error('notify: wrap requires a non-empty string label', 2)
    end
    local threshold_ms = opts.threshold_ms
    if threshold_ms == nil then
        threshold_ms = M.config.threshold_ms
    end
    if type(threshold_ms) ~= 'number' or threshold_ms ~= math.floor(threshold_ms) or threshold_ms < 1 then
        error('notify: threshold_ms must be a positive integer', 2)
    end
    local on_done = opts.on_done
    if on_done ~= nil and type(on_done) ~= 'function' then
        error('notify: on_done must be a function', 2)
    end
    local started_ms = M.now_ms()
    ---@param exit_code integer|table|nil
    ---@return boolean notified
    ---@return string reason
    return function(exit_code)
        local code = exit_code
        if type(code) == 'table' then
            code = code.exit_code
        end
        if type(code) ~= 'number' then
            code = EXIT_CODE_UNKNOWN
        end
        local duration_ms = math.max(0, M.now_ms() - started_ms)
        local info = {
            label = label,
            duration_ms = duration_ms,
            exit_code = code,
            notified = false,
            system_notified = false,
            system_note = '',
        }
        local function finish(notified, reason)
            info.notified = notified
            if on_done ~= nil then
                on_done(info)
            end
            return notified, reason
        end
        if M.excluded(label) then
            info.system_note = 'excluded'
            return finish(false, 'excluded')
        end
        if duration_ms < threshold_ms then
            local level = M.config.below_threshold_level
            if level ~= nil then
                vim.notify(
                    ('notify: %s finished in %s (below %d ms threshold)'):format(
                        label,
                        M.format_duration(duration_ms),
                        threshold_ms
                    ),
                    level,
                    { title = 'notify' }
                )
            end
            info.system_note = 'below threshold'
            return finish(false, 'below threshold')
        end
        local human = M.format_duration(duration_ms)
        local title
        if code == 0 then
            title = 'Done in ' .. human
        else
            title = ('Failed (%d) after %s'):format(code, human)
        end
        vim.notify(title .. '\n' .. label, M.config.vim_notify_level, { title = 'notify' })
        local sent, note = fire_system(title, label, code)
        info.system_notified = sent
        info.system_note = note
        return finish(true, 'notified')
    end
end

---@class notify.RunOpts
---@field label? string Task label; defaults to argv[1].
---@field threshold_ms? integer Override the configured threshold.
---@field on_done? fun(info: notify.DoneInfo) Called with the outcome record.
---@field timeout_ms? integer Subprocess ceiling for the wrapped argv.

---One-shot path: run argv through security.rce.safe_exec with the
---threshold logic wrapped around it. The notification fires (or stays
---silent) exactly as wrap() dictates; the return is the safe_exec
---(result, err) pair, so spawn failures and non-zero exits still report
---normally. Returns (nil, err) on validation failure without spawning.
---@param argv string[] Command argv, e.g. { 'make', 'test' }.
---@param opts? notify.RunOpts
---@return vim.SystemCompleted|nil result
---@return string|nil err
function M.run(argv, opts)
    if type(argv) ~= 'table' or #argv == 0 or type(argv[1]) ~= 'string' then
        return nil, 'run expects a non-empty argv list of strings'
    end
    local run_opts = opts or {}
    if type(run_opts) ~= 'table' then
        return nil, 'run expects an options table, got ' .. type(run_opts)
    end
    local label = run_opts.label
    if label == nil then
        label = argv[1]
    end
    local done = M.wrap({ label = label, threshold_ms = run_opts.threshold_ms, on_done = run_opts.on_done })
    local timeout_ms = run_opts.timeout_ms
    if timeout_ms == nil then
        timeout_ms = M.config.timeout_ms
    end
    local rce = require('security.rce')
    local result, exec_err = rce.safe_exec(argv, { timeout_ms = timeout_ms })
    local code = result ~= nil and result.code or EXIT_CODE_UNKNOWN
    done(code)
    return result, exec_err
end

---Fire a test notification through both backends so the operator can
---verify the desktop toast actually appears. Bypasses the threshold and
---the exclusions on purpose -- this is a manual check, not a wrapped task.
---@return boolean sent Desktop backend outcome.
---@return string note
function M.test_notify()
    local label = 'NotifyTest: manual backend check'
    local title = 'Done in 0s'
    vim.notify(title .. '\n' .. label, M.config.vim_notify_level, { title = 'notify' })
    return fire_system(title, label, 0)
end

---The :NotifyValidate checks. Pure data; statuses are 'ok' or
---'unavailable', never an error. notify-send is an optional backend --
---reported, never required.
---@return { name: string, status: string, detail: string }[]
function M.checks()
    local checks = {}
    local present = M.notify_send_available()
    checks[#checks + 1] = {
        name = 'notify-send',
        status = present and 'ok' or 'unavailable',
        detail = present and (M.config.notify_send_bin .. ' on PATH (optional backend)')
            or (M.config.notify_send_bin .. ' not found; vim.notify only'),
    }
    local threshold = M.config.threshold_ms
    local sane = type(threshold) == 'number'
        and threshold == math.floor(threshold)
        and threshold >= 1
        and threshold <= THRESHOLD_MS_MAX
    checks[#checks + 1] = {
        name = 'threshold',
        status = sane and 'ok' or 'unavailable',
        detail = sane and ('threshold_ms = %d'):format(threshold) or 'threshold_ms is not a sane positive integer',
    }
    checks[#checks + 1] = {
        name = 'dry-run',
        status = M.dry_run() and 'ok' or 'unavailable',
        detail = 'wrap+done under/over threshold with an injected clock',
    }
    return checks
end

---Exercise the threshold seam without side effects: swap in an injected
---clock, capture (do not display) the vim.notify calls, disable the
---desktop backend, then run one under-threshold and one over-threshold
---done_fn. Restores everything before returning. True when the
---under-threshold call stays silent and the over-threshold call fires.
---@return boolean behaved
function M.dry_run()
    local saved_clock = M.config.clock_impl
    local saved_backend = M.config.system_backend_enabled
    local saved_notify = vim.notify
    local now = 0
    local fired = {}
    vim.notify = function(msg)
        fired[#fired + 1] = tostring(msg)
    end
    M.config.clock_impl = function()
        return now
    end
    M.config.system_backend_enabled = false
    local under_notified, over_notified
    local ran = pcall(function()
        local done = M.wrap({ label = 'NotifyValidate dry-run', threshold_ms = 1000 })
        now = 999
        under_notified = done(0)
        now = 1000
        over_notified = done(0)
    end)
    M.config.clock_impl = saved_clock
    M.config.system_backend_enabled = saved_backend
    vim.notify = saved_notify
    return ran and under_notified == false and over_notified == true
end

---:NotifyTest -- fire a real test notification through both backends.
local function cmd_test()
    local _, note = M.test_notify()
    vim.notify(('NotifyTest: in-editor notice sent; desktop backend: %s'):format(note), vim.log.levels.INFO)
end

local DOC_LINES = {
    'notify -- long-task notifications',
    '',
    'Lineage: the fish `done` plugin (~/workspace/repos/dotfiles/.config/',
    'fish/conf.d/done.fish). There is no upstream project for this module --',
    "it is Matt's own diver module, and these docs are a local float.",
    '',
    'Model:',
    '  * require("notify").wrap({ label = "backup" }) returns done_fn.',
    '  * done_fn(exit_code) measures wall-clock wrap() -> done() via',
    '    M.now_ms() (vim.uv.now(), or the clock_impl test seam).',
    '  * duration >= threshold_ms: vim.notify + notify-send desktop toast.',
    '  * duration < threshold_ms: silent (or below_threshold_level, DEBUG).',
    '  * exclude_patterns: literal substrings; matching labels never notify.',
    '  * notify-send is best-effort: absent binary -> vim.notify only.',
    '  * done.fish humanizes durations: 45s, 1m 5s, 2h 3m 4s.',
    '  * Failures (exit ~= 0) escalate the toast to critical urgency.',
    '',
    'Cargo seam (cargo module untouched):',
    '  local wrap = require("notify").wrap({ label = "cargo test" })',
    '  cargo.run({ subcommand = "test", on_exit = wrap })',
    '',
    'Commands: :NotifyTest :NotifyDocs :NotifyValidate :NotifyUpdateCheck',
    'q closes this window.',
}

---:NotifyDocs -- local help float describing the threshold model and the
---done.fish lineage. No upstream project exists for this module; this
---float IS the documentation.
local function cmd_docs()
    local buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_lines(buf, 0, -1, false, DOC_LINES)
    local width = 0
    for _, line in ipairs(DOC_LINES) do
        width = math.max(width, #line)
    end
    width = math.min(width + 4, vim.o.columns - DOC_HALF_GAP * 2)
    local height = math.min(#DOC_LINES, vim.o.lines - DOC_HALF_GAP * 2)
    local win = api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        style = 'minimal',
        border = 'rounded',
        title = ' notify ',
    })
    vim.keymap.set('n', 'q', function()
        if api.nvim_win_is_valid(win) then
            api.nvim_win_close(win, true)
        end
    end, { buffer = buf, noremap = true, silent = true, desc = 'Close the notify docs float' })
end

---:NotifyValidate -- one vim.notify per check; nothing here errors.
local function cmd_validate()
    for _, check in ipairs(M.checks()) do
        local level = check.status == 'ok' and vim.log.levels.INFO or vim.log.levels.WARN
        vim.notify(('notify %-12s %-13s %s'):format(check.name, check.status, check.detail), level)
    end
end

---:NotifyUpdateCheck -- no upstream release feed exists for this module
---(Matt's own), so this compares the live config's config_version against
---M.CONFIG_VERSION and offers pending migrations via toolmgr when stale.
---Never errors.
local function cmd_update_check()
    local toolmgr = require('utils.toolmgr')
    local current = toolmgr.normalize_version(M.CONFIG_VERSION) or '0.0.0'
    local from = toolmgr.normalize_version(M.config.config_version) or '0.0.0'
    if toolmgr.compare_versions(from, current) >= 0 then
        vim.notify(
            ('NotifyUpdateCheck: config v%s is current (no upstream; local module)'):format(M.config.config_version),
            vim.log.levels.INFO
        )
        return
    end
    local applied, notes = toolmgr.apply_migrations(MIGRATIONS_NOTIFY, from)
    if applied > 0 then
        M.config.config_version = M.CONFIG_VERSION
    end
    vim.notify(
        ('NotifyUpdateCheck: %d migration(s) applied\n%s'):format(applied, table.concat(notes, '\n')),
        vim.log.levels.INFO
    )
end

---Register the :Notify* commands. Idempotent: commands are created once;
---the config is rebuilt on every call. Performs no subprocess I/O.
---@param config? table Overrides merged over M.default_config.
function M.setup(config)
    M.config = M.setup_config(config)
    if setup_done then
        return
    end
    setup_done = true
    api.nvim_create_user_command('NotifyTest', cmd_test, { desc = 'Fire a test notification through both backends' })
    api.nvim_create_user_command(
        'NotifyDocs',
        cmd_docs,
        { desc = 'Local notify docs float (threshold model, done.fish lineage)' }
    )
    api.nvim_create_user_command('NotifyValidate', cmd_validate, { desc = 'Per-check notify validation report' })
    api.nvim_create_user_command(
        'NotifyUpdateCheck',
        cmd_update_check,
        { desc = 'Local config-version migration check' }
    )
end

return M
