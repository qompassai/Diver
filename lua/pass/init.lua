-- /qompassai/Diver/lua/pass/init.lua
-- Qompass AI Diver pass(1) Password-Store Picker (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Fuzzy picker over `pass ls` entries: yank password/OTP into the + and *
-- registers behind a single-owner auto-clear timer, insert the password at
-- the cursor without touching the clipboard, plus per-tool validation and
-- update checks. Requiring this module registers nothing and performs no
-- I/O; M.setup() creates the user commands. Every subprocess goes through
-- security.rce.safe_exec in argv form. Entry names are validated against
-- a strict pattern (bounded length) before they ever reach argv — never
-- interpolated. Secrets are never logged, notified, or persisted.
---@module 'pass'

local M = {}

local api = vim.api

local rce = require('security.rce')

local setup_done = false

---Oldest pass this module supports. Verified: 1.7.4 is the newest upstream
---release (2021-06-11); nothing this module needs postdates 1.7.0.
M.PASS_VERSION_MIN = '1.7.0'

local ENTRIES_MAX = 4000 -- cap on entries parsed from `pass ls`.
local SECRET_BYTES_MAX = 65536 -- cap on one retrieved secret.

---`pass ls` tree-drawing literals. Byte lengths matter here: the box
---glyphs are 3 bytes each in UTF-8, so character counts and byte counts
---differ ('├── ' is 4 columns but 10 bytes).
local TREE_CONT = '│   ' -- deeper level, more siblings below (6 bytes).
local TREE_GAP = '    ' -- deeper level, no more siblings (4 bytes).
local TREE_BRANCH = '├── ' -- non-last child (10 bytes).
local TREE_LAST = '└── ' -- last child (10 bytes).

---@class pass.Check
---@field name string Tool or aspect probed.
---@field status 'ok'|'unavailable'|'below minimum'
---@field detail string One-line human summary.

M.default_config = {
    -- ms before a yanked secret is cleared from the + and * registers.
    clear_clipboard_after_ms = 15000,
    -- canonical docs (verified 2026-09-27: passwordstore.org answers 200).
    docs_url = 'https://www.passwordstore.org/',
    -- longest accepted entry name; longer names are rejected.
    entry_length_max = 256,
    -- strict entry-name shape; anything else never reaches argv.
    entry_pattern = '^[A-Za-z0-9_./-]+$',
    -- binary probed for the read-only secret-key check (never decrypts).
    gpg_bin = 'gpg',
    -- newest pass release this module knows (verified: 1.7.4).
    known_upstream_version = '1.7.4',
    -- oath-toolkit binary gating the `pass otp` action; optional.
    oathtool_bin = 'oathtool',
    -- pass binary probed on PATH; overridable for tests.
    pass_bin = 'pass',
    -- oldest supported pass; see M.PASS_VERSION_MIN.
    pass_version_min = '1.7.0',
    -- prompt for the :Pass entry picker.
    picker_prompt = 'pass entry: ',
    -- vim.ui.select replacement; nil uses the real one (test seam).
    select_impl = nil,
    -- password store root.
    store_dir = '~/.password-store',
    -- wall-clock cap per pass subprocess.
    timeout_ms = 30000,
    -- upstream repo for :PassUpdateCheck release lookups (zx2c4/pass 404s;
    -- verified 2026-09-27 that zx2c4/password-store is the canonical mirror).
    update_repo = 'zx2c4/password-store',
}

---Live configuration. Rebuilt from M.default_config on every setup().
---@type table
M.config = vim.deepcopy(M.default_config)

---Placeholder migrations: no upstream pass config-key rename is known, so
---the entry documents the migration shape as a clearly-marked template
---(no-op apply). Replace with a real migration when upstream renames a
---key we depend on.
local MIGRATIONS_NOTE = '[template] no upstream pass config rename known; shape only, no-op'

---@type utils.toolmgr.Migration[]
local MIGRATIONS_PASS = {
    {
        version = '1.7.4',
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
        error(('pass: option %s must be %s, got %s'):format(name, expected, type(value)), 2)
    end
end

---Build the live config: factory defaults deep-copied, overrides merged,
---every key type-checked. Never mutates M.default_config.
---@param config table|nil Overrides; nil restores factory defaults.
---@return table merged Live config table.
function M.setup_config(config)
    check_type('config', config, 'table', true)
    local merged = vim.tbl_deep_extend('force', vim.deepcopy(M.default_config), config or {})
    check_type('clear_clipboard_after_ms', merged.clear_clipboard_after_ms, 'number')
    check_type('docs_url', merged.docs_url, 'string')
    check_type('entry_length_max', merged.entry_length_max, 'number')
    check_type('entry_pattern', merged.entry_pattern, 'string')
    check_type('gpg_bin', merged.gpg_bin, 'string')
    check_type('known_upstream_version', merged.known_upstream_version, 'string')
    check_type('oathtool_bin', merged.oathtool_bin, 'string')
    check_type('pass_bin', merged.pass_bin, 'string')
    check_type('pass_version_min', merged.pass_version_min, 'string')
    check_type('picker_prompt', merged.picker_prompt, 'string')
    check_type('select_impl', merged.select_impl, 'function', true)
    check_type('store_dir', merged.store_dir, 'string')
    check_type('timeout_ms', merged.timeout_ms, 'number')
    check_type('update_repo', merged.update_repo, 'string')
    if merged.clear_clipboard_after_ms < 1 then
        error('pass: option clear_clipboard_after_ms must be positive', 2)
    end
    if merged.entry_length_max < 1 then
        error('pass: option entry_length_max must be positive', 2)
    end
    if not pcall(string.match, '', merged.entry_pattern) then
        error('pass: option entry_pattern is not a valid Lua pattern', 2)
    end
    if vim.trim(merged.pass_bin) == '' then
        error('pass: option pass_bin must not be blank', 2)
    end
    if vim.trim(merged.store_dir) == '' then
        error('pass: option store_dir must not be blank', 2)
    end
    if vim.trim(merged.update_repo) == '' then
        error('pass: option update_repo must not be blank', 2)
    end
    return merged
end

---Map a toolmgr binary report onto the pass.Check status vocabulary.
---@param report utils.toolmgr.BinaryReport
---@return pass.Check
local function to_check(report)
    local status = 'unavailable'
    if report.present and report.meets_minimum then
        status = 'ok'
    elseif report.present then
        status = 'below minimum'
    end
    return { name = report.name, status = status, detail = report.detail }
end

-- Clipboard auto-clear ------------------------------------------------
-- The timer handle has exactly one owner: this module. Re-yanking stops
-- and closes the live timer before starting a new one, so two timers can
-- never be live at once. Teardown is idempotent and nils the handle.

---Live clear timer, or nil when none is armed.
---@type userdata|nil
local clear_timer = nil

---Stop and close the clear timer. Idempotent: safe to call with no live
---timer, and safe to call twice.
function M.stop_clear_timer()
    if clear_timer ~= nil then
        pcall(vim.uv.timer_stop, clear_timer)
        pcall(vim.uv.close, clear_timer)
        clear_timer = nil
    end
end

---Arm the single-owner clear timer, replacing any live one first. On fire:
---both the + and * registers are emptied, one notification goes out, and
---the handle is torn down exactly once.
function M.schedule_clear()
    M.stop_clear_timer()
    local timer = vim.uv.new_timer()
    if timer == nil then
        vim.notify('Pass: could not start the clipboard-clear timer', vim.log.levels.WARN)
        return
    end
    clear_timer = timer
    -- schedule_wrap: uv callbacks run off the main loop, so every vim
    -- API call must be re-entered on it.
    timer:start(
        M.config.clear_clipboard_after_ms,
        0,
        vim.schedule_wrap(function()
            pcall(vim.fn.setreg, '+', {})
            pcall(vim.fn.setreg, '*', {})
            vim.notify('Pass: clipboard cleared', vim.log.levels.INFO)
            M.stop_clear_timer()
        end)
    )
end

-- Entry handling -------------------------------------------------------

---Validate a candidate entry name before it ever reaches argv. Returns
---true for the strict shape ^[A-Za-z0-9_./-]+$ within entry_length_max;
---otherwise false plus a reason. Never throws on non-strings.
---@param name any Candidate entry name.
---@return boolean valid
---@return string|nil reason Rejection reason when invalid.
function M.entry_valid(name)
    if type(name) ~= 'string' then
        return false, 'entry name must be a string'
    end
    if name == '' then
        return false, 'entry name must not be empty'
    end
    if #name > M.config.entry_length_max then
        return false, ('entry name longer than entry_length_max=%d'):format(M.config.entry_length_max)
    end
    if not name:match(M.config.entry_pattern) then
        return false, 'entry name has characters outside ' .. M.config.entry_pattern
    end
    -- A '..' segment would escape the store root when pass resolves the
    -- path; pass itself refuses such "sneaky paths", and so do we.
    for _, segment in ipairs(vim.split(name, '/', { plain = true })) do
        if segment == '..' then
            return false, 'entry name must not contain ".." segments'
        end
    end
    return true, nil
end

---Split one `pass ls` tree line into (depth, basename). Each indent level
---is one TREE_CONT/TREE_GAP literal; the node marker is TREE_BRANCH or
---TREE_LAST. Returns nil for the header and blank lines.
---@param line string Raw output line.
---@return integer|nil depth
---@return string|nil basename
local function split_ls_line(line)
    assert(#TREE_BRANCH == #TREE_LAST, 'tree node markers must share byte length')
    local rest = line
    local depth = 0
    while true do
        if rest:sub(1, #TREE_CONT) == TREE_CONT then
            depth = depth + 1
            rest = rest:sub(#TREE_CONT + 1)
        elseif rest:sub(1, #TREE_GAP) == TREE_GAP then
            depth = depth + 1
            rest = rest:sub(#TREE_GAP + 1)
        else
            break
        end
    end
    if rest:sub(1, #TREE_BRANCH) == TREE_BRANCH or rest:sub(1, #TREE_LAST) == TREE_LAST then
        rest = rest:sub(#TREE_BRANCH + 1)
    end
    local name = vim.trim(rest)
    if name == '' then
        return nil, nil
    end
    return depth, name
end

---List store entries via `pass ls`, reconstructing full slash-paths from
---the tree output (real `pass ls` prints bare basenames per level). Lines
---that fail entry validation — the 'Password Store' header, junk — are
---dropped, never passed onward.
---@return string[]|nil entries
---@return string|nil err
function M.list_entries()
    local toolmgr = require('utils.toolmgr')
    local bin = M.config.pass_bin
    if not toolmgr.binary_present(bin) then
        return nil, bin .. ' is unavailable on PATH'
    end
    local result, exec_err = rce.safe_exec({ bin, 'ls' }, { timeout_ms = M.config.timeout_ms })
    if exec_err ~= nil then
        return nil, exec_err
    end
    assert(result ~= nil, 'safe_exec returned no error but no result')
    if result.code ~= 0 then
        return nil, 'pass ls failed: ' .. vim.trim(result.stderr or '')
    end
    local entries = {}
    local stack = {}
    for _, line in ipairs(vim.split(result.stdout or '', '\n', { plain = true })) do
        local depth, name = split_ls_line(line)
        if depth ~= nil and name ~= nil then
            -- malformed trees must not leave holes in the stack.
            if depth > 0 and stack[depth] == nil then
                depth = 0
            end
            stack[depth + 1] = name
            local full = table.concat(stack, '/', 1, depth + 1)
            if M.entry_valid(full) then
                entries[#entries + 1] = full
            end
            if #entries >= ENTRIES_MAX then
                break
            end
        end
    end
    return entries, nil
end

---First line of a secret: `pass show` prints the password first, then
---optional metadata. Only this line ever reaches a register or buffer.
---@param secret string Full `pass show` output.
---@return string password
function M.password_line(secret)
    local line = secret:match('^([^\n]*)') or ''
    return vim.trim(line)
end

---Retrieve one secret via `pass <sub> <entry>` in argv form. The entry is
---validated before spawning; the secret is bounded and never empty.
---@param entry string Validated entry name.
---@param sub? string Subcommand: 'show' (default) or 'otp'.
---@return string|nil secret
---@return string|nil err
function M.retrieve(entry, sub)
    local valid, why = M.entry_valid(entry)
    if not valid then
        return nil, 'invalid entry name: ' .. (why or 'rejected')
    end
    local toolmgr = require('utils.toolmgr')
    local bin = M.config.pass_bin
    if not toolmgr.binary_present(bin) then
        return nil, bin .. ' is unavailable on PATH'
    end
    local verb = sub or 'show'
    local result, exec_err = rce.safe_exec({ bin, verb, entry }, { timeout_ms = M.config.timeout_ms })
    if exec_err ~= nil then
        return nil, exec_err
    end
    assert(result ~= nil, 'safe_exec returned no error but no result')
    if result.code ~= 0 then
        return nil, ('pass %s failed: %s'):format(verb, vim.trim(result.stderr or ''))
    end
    local secret = result.stdout or ''
    if #secret > SECRET_BYTES_MAX then
        return nil, ('secret exceeds SECRET_BYTES_MAX=%d bytes'):format(SECRET_BYTES_MAX)
    end
    if vim.trim(secret) == '' then
        return nil, 'pass returned an empty secret'
    end
    return secret, nil
end

-- Secret actions ---------------------------------------------------------

---Copy one secret line into the + and * registers and arm the auto-clear
---timer. The secret itself is never notified or logged; the entry name is
---not a secret and identifies which yank the timer belongs to.
---@param secret_line string Single secret line (password or OTP).
---@param kind string 'password' or 'OTP', for the notification.
---@param entry string Entry name, for the notification.
local function yank_registered(secret_line, kind, entry)
    -- setreg is pcall-wrapped: headless boxes may lack a clipboard provider.
    pcall(vim.fn.setreg, '+', secret_line)
    pcall(vim.fn.setreg, '*', secret_line)
    M.schedule_clear()
    local seconds = math.floor(M.config.clear_clipboard_after_ms / 1000)
    vim.notify(('Pass: %s for %s yanked; clipboard clears in %ds'):format(kind, entry, seconds), vim.log.levels.INFO)
end

---Yank the password (first line of `pass show`) into + and *.
---@param entry string Validated entry name.
function M.yank_password(entry)
    local secret, secret_err = M.retrieve(entry, 'show')
    if secret_err ~= nil then
        vim.notify('Pass: ' .. secret_err, vim.log.levels.ERROR)
        return
    end
    assert(secret ~= nil, 'retrieve returned no error but no secret')
    yank_registered(M.password_line(secret), 'password', entry)
end

---Yank a one-time password via `pass otp`. Refuses when oathtool is
---absent (the action is hidden from the menu for the same reason).
---@param entry string Validated entry name.
function M.yank_otp(entry)
    local toolmgr = require('utils.toolmgr')
    if not toolmgr.binary_present(M.config.oathtool_bin) then
        vim.notify('Pass: oathtool is unavailable; cannot produce an OTP', vim.log.levels.ERROR)
        return
    end
    local otp, otp_err = M.retrieve(entry, 'otp')
    if otp_err ~= nil then
        vim.notify('Pass: ' .. otp_err, vim.log.levels.ERROR)
        return
    end
    assert(otp ~= nil, 'retrieve returned no error but no OTP')
    yank_registered(vim.trim(otp), 'OTP', entry)
end

---Insert the password at the cursor without touching any register and
---without arming the clear timer: there is no clipboard exposure to time
---out, so a timer would be pure noise (and would clear the user's own
---unrelated clipboard content if one were armed).
---@param entry string Validated entry name.
function M.insert_snippet(entry)
    local secret, secret_err = M.retrieve(entry, 'show')
    if secret_err ~= nil then
        vim.notify('Pass: ' .. secret_err, vim.log.levels.ERROR)
        return
    end
    assert(secret ~= nil, 'retrieve returned no error but no secret')
    local lines = vim.split(M.password_line(secret), '\n', { plain = true })
    local cursor = api.nvim_win_get_cursor(0)
    api.nvim_buf_set_text(0, cursor[1] - 1, cursor[2], cursor[1] - 1, cursor[2], lines)
    vim.notify('Pass: inserted at cursor (registers and clipboard untouched)', vim.log.levels.INFO)
end

---Actions offered for one entry, in menu order. 'Yank OTP' appears only
---when oathtool is present; otherwise it is absent from the menu.
---@return string[] actions
function M.available_actions()
    local toolmgr = require('utils.toolmgr')
    local actions = { 'Yank password' }
    if toolmgr.binary_present(M.config.oathtool_bin) then
        actions[#actions + 1] = 'Yank OTP'
    end
    actions[#actions + 1] = 'Insert as snippet'
    actions[#actions + 1] = 'Cancel'
    return actions
end

---Second picker: the action menu for one already-chosen entry.
---@param entry string Validated entry name.
function M.choose_action(entry)
    local valid, why = M.entry_valid(entry)
    if not valid then
        vim.notify('Pass: invalid entry name (' .. (why or 'rejected') .. ')', vim.log.levels.ERROR)
        return
    end
    local impl = M.config.select_impl or vim.ui.select
    impl(M.available_actions(), { prompt = 'pass ' .. entry .. ': ' }, function(choice)
        if choice == 'Yank password' then
            M.yank_password(entry)
        elseif choice == 'Yank OTP' then
            M.yank_otp(entry)
        elseif choice == 'Insert as snippet' then
            M.insert_snippet(entry)
        end
    end)
end

---:Pass — entry picker, then the action menu. `:Pass <name>` skips the
---picker and goes straight to the action menu for a validated name.
---@param cmd_opts table nvim_create_user_command callback options.
function M.cmd_pass(cmd_opts)
    local args = type(cmd_opts) == 'table' and cmd_opts.fargs or {}
    local direct = type(args) == 'table' and args[1] or nil
    if direct ~= nil and direct ~= '' then
        M.choose_action(direct)
        return
    end
    local entries, list_err = M.list_entries()
    if list_err ~= nil then
        vim.notify('Pass: ' .. list_err, vim.log.levels.ERROR)
        return
    end
    assert(entries ~= nil, 'list_entries returned no error but no entries')
    if #entries == 0 then
        vim.notify('Pass: the store has no entries', vim.log.levels.INFO)
        return
    end
    local impl = M.config.select_impl or vim.ui.select
    impl(entries, { prompt = M.config.picker_prompt }, function(choice)
        if choice ~= nil then
            M.choose_action(choice)
        end
    end)
end

---:PassClear — cancel the clear timer and empty the + and * registers
---right now. Idempotent.
function M.cmd_clear()
    M.stop_clear_timer()
    pcall(vim.fn.setreg, '+', {})
    pcall(vim.fn.setreg, '*', {})
    vim.notify('Pass: clipboard cleared', vim.log.levels.INFO)
end

-- Validation and update --------------------------------------------------

---Per-tool validation. Never throws: missing pieces are 'unavailable',
---never errors. Only presence and counts are reported — no secret values.
---@return pass.Check[] checks
function M.checks()
    local toolmgr = require('utils.toolmgr')
    local cfg = M.config
    local checks = {}
    checks[#checks + 1] = to_check(toolmgr.check_binary({
        name = cfg.pass_bin,
        version_argv = { cfg.pass_bin, '--version' },
        min_version = cfg.pass_version_min,
    }))
    local store_path = vim.fn.expand(cfg.store_dir)
    local stat = vim.uv.fs_stat(store_path)
    checks[#checks + 1] = {
        name = 'store',
        status = stat ~= nil and 'ok' or 'unavailable',
        detail = stat ~= nil and ('store dir exists: ' .. cfg.store_dir) or ('store dir missing: ' .. cfg.store_dir),
    }
    -- Bounded read-only GPG probe: lists secret keys, never decrypts.
    local gpg_ok = false
    if toolmgr.binary_present(cfg.gpg_bin) then
        local result, exec_err = rce.safe_exec(
            { cfg.gpg_bin, '--list-secret-keys', '--with-colons' },
            { timeout_ms = cfg.timeout_ms }
        )
        gpg_ok = exec_err == nil
            and result ~= nil
            and result.code == 0
            and (result.stdout or ''):find('sec', 1, true) ~= nil
    end
    checks[#checks + 1] = {
        name = 'gpg-agent',
        status = gpg_ok and 'ok' or 'unavailable',
        detail = gpg_ok and 'secret keys listable (read-only probe; nothing decrypted)'
            or 'no secret keys listed via gpg --list-secret-keys',
    }
    local otp = toolmgr.check_binary({ name = cfg.oathtool_bin })
    checks[#checks + 1] = {
        name = cfg.oathtool_bin .. ' (optional)',
        status = otp.present and 'ok' or 'unavailable',
        detail = otp.present and ('OTP available: ' .. otp.detail)
            or 'oathtool absent; the "Yank OTP" action stays hidden',
    }
    return checks
end

---The toolmgr update spec for pass. Pure data; current_version is nil when
---the tool is absent, which check_update treats as "not installed".
---@return utils.toolmgr.UpdateSpec[]
function M.update_specs()
    local toolmgr = require('utils.toolmgr')
    local cfg = M.config
    local current = toolmgr.command_version({ cfg.pass_bin, '--version' })
    return {
        {
            tool_label = 'pass',
            repo = cfg.update_repo,
            package = 'pass',
            current_version = current,
            known_upstream_version = cfg.known_upstream_version,
            migrations = MIGRATIONS_PASS,
            select_impl = cfg.select_impl,
        },
    }
end

---:PassDocs -- open the verified upstream pass documentation.
local function cmd_docs()
    local url = M.config.docs_url
    local opened = vim.ui.open ~= nil and pcall(vim.ui.open, url)
    if not opened then
        vim.notify('pass docs: ' .. url, vim.log.levels.INFO)
    end
end

---:PassValidate -- one vim.notify per check; missing tools say
---"unavailable", never an error. Never prints secret values.
local function cmd_validate()
    for _, check in ipairs(M.checks()) do
        local level = check.status == 'ok' and vim.log.levels.INFO or vim.log.levels.WARN
        vim.notify(('pass %-18s %-13s %s'):format(check.name, check.status, check.detail), level)
    end
end

---:PassUpdateCheck -- toolmgr update dialog for pass.
local function cmd_update_check()
    local toolmgr = require('utils.toolmgr')
    for _, spec in ipairs(M.update_specs()) do
        toolmgr.check_update(spec)
    end
end

---Register the :Pass* commands. Idempotent: commands are created once;
---the config is rebuilt on every call. Performs no subprocess I/O itself.
---@param config? table Overrides merged over M.default_config.
function M.setup(config)
    M.config = M.setup_config(config)
    if setup_done then
        return
    end
    setup_done = true
    api.nvim_create_user_command('Pass', function(cmd_opts)
        M.cmd_pass(cmd_opts)
    end, {
        nargs = '?',
        desc = 'Pick a pass entry, then yank password/OTP or insert as snippet',
    })
    api.nvim_create_user_command(
        'PassClear',
        M.cmd_clear,
        { desc = 'Cancel the clear timer and empty the clipboard registers now' }
    )
    api.nvim_create_user_command('PassDocs', cmd_docs, { desc = 'Open the upstream pass documentation' })
    api.nvim_create_user_command('PassValidate', cmd_validate, { desc = 'Per-tool validation report' })
    api.nvim_create_user_command('PassUpdateCheck', cmd_update_check, { desc = 'Update check for pass' })
end

return M
