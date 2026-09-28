-- /qompassai/Diver/lua/email/clients/neomutt.lua
-- Qompass AI Diver Neomutt Email Client Backend (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Neomutt backend for his five-account setup. Opens neomutt in a float
-- terminal, parses his real neomuttrc + account files (never hardcodes his
-- addresses; they are read from the files at runtime with graceful
-- fallback), runs notmuch searches, and reports validation/update checks.
--
-- Requiring this module registers nothing and performs no I/O; M.setup()
-- creates the user commands. Every subprocess goes through
-- security.rce.safe_exec in argv form. Credential values (imap_pass,
-- smtp_pass, passwordeval commands) are parsed for structure but masked
-- in every report: they are never printed.
---@module 'comms.clients.neomutt'

local M = {}

local api = vim.api

local rce = require('security.rce')

local setup_done = false

---Oldest neomutt this module supports. Verified: NeoMutt 20260105 was the
---2026-01-05 release (GitHub releases, tag 20260105).
M.NEOMUTT_VERSION_MIN = '20260105'

local OUTPUT_LINES_MAX = 2000 -- output lines kept for any float view.
local PARSE_BYTES_MAX = 1048576 -- 1 MiB cap on rc/account files parsed.
local PARSE_LINES_MAX = 20000 -- line cap on rc/account files parsed.
local SEARCH_RESULTS_MAX = 200 -- hard cap on notmuch search float lines.

---@class email.neomutt.Bind
---@field menu string Menu the binding applies to, e.g. 'index'.
---@field key string Key sequence, e.g. '\\ct'.
---@field func string Neomutt function, e.g. 'tag-prefix'.

---@class email.neomutt.Macro
---@field menu string Menu the macro applies to.
---@field key string Key sequence.
---@field action string Macro body.

---@class email.neomutt.FolderHook
---@field pattern string Folder pattern; '' means every folder.
---@field command string Hook command.

---@class email.neomutt.RcParse
---@field sets table<string, string|boolean> `set' variables.
---@field sources string[] `source' paths.
---@field binds email.neomutt.Bind[] `bind' entries.
---@field macros email.neomutt.Macro[] `macro' entries.
---@field mailboxes string[] `mailboxes' entries (literal tokens).
---@field virtual_mailboxes string[] Backtick commands feeding mailboxes.
---@field folder_hooks email.neomutt.FolderHook[] `folder-hook' entries.
---@field warnings string[] Lines skipped during parsing.

---@class email.neomutt.Account
---@field name string Account file basename, e.g. 'account.qompassai'.
---@field ok boolean True when the file existed and parsed.
---@field err string|nil Reason when ok is false.
---@field sets table<string, string|boolean> Parsed `set' variables.

---@class email.neomutt.Check
---@field name string Tool or aspect probed.
---@field status 'ok'|'unavailable'|'below minimum'
---@field detail string One-line human summary (credentials masked).

M.default_config = {
    -- Directory holding neomuttrc + account files; overridable for tests.
    account_dir = vim.fn.expand('~/.config/neomutt'),
    -- His five accounts (verified 2026-09-27 in dotfiles).
    account_files = {
        'account.aflabs',
        'account.foamedgmail',
        'account.map26gmail',
        'account.qompassai',
        'account.wsu',
    },
    -- Canonical neomutt documentation.
    docs_url = 'https://neomutt.org/',
    -- Rows of the search/validate float.
    float_height = 24,
    -- Cols of the search/validate float.
    float_width = 110,
    -- vim.ui.input replacement; nil uses the real one (test seam).
    input_impl = nil,
    -- Newest neomutt this module knows about (verified: tag 20260616,
    -- GitHub releases/latest, 2026-09-27).
    known_upstream_version = '20260616',
    -- msmtp binary probed by :NeomuttValidate.
    msmtp_bin = 'msmtp',
    -- His msmtp config (verified in dotfiles).
    msmtp_config = vim.fn.expand('~/.config/msmtp/config'),
    -- Binary probed on PATH; overridable for tests.
    neomutt_bin = 'neomutt',
    -- His main rc file; passed to neomutt via -F.
    neomuttrc = vim.fn.expand('~/.config/neomutt/neomuttrc'),
    -- notmuch binary probed on PATH; overridable for tests.
    notmuch_bin = 'notmuch',
    -- --limit passed to `notmuch search`.
    search_limit = 50,
    -- vim.ui.select replacement; nil uses the real one (test seam).
    select_impl = nil,
    -- Mirrors his `set sidebar_width = 30`.
    sidebar_width = 30,
    -- Wall-clock cap per subprocess.
    timeout_ms = 30000,
    -- GitHub mirror of the canonical msmtp git repo (verified 2026-09-27:
    -- canonical https://git.marlam.de/git/msmtp.git, mirror marlam/msmtp).
    update_repo_msmtp = 'marlam/msmtp',
    -- Upstream repo for :NeomuttUpdateCheck release lookups.
    update_repo_neomutt = 'neomutt/neomutt',
}

---Live configuration. Rebuilt from M.default_config on every setup().
---@type table
M.config = vim.deepcopy(M.default_config)

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
        error(('neomutt: option %s must be %s, got %s'):format(name, expected, type(value)), 2)
    end
end

---Build the live config: factory defaults deep-copied, overrides merged,
---every key type-checked. Never mutates M.default_config.
---@param config table|nil Overrides; nil restores factory defaults.
---@return table merged Live config table.
function M.setup_config(config)
    check_type('config', config, 'table', true)
    local merged = vim.tbl_deep_extend('force', vim.deepcopy(M.default_config), config or {})
    check_type('account_dir', merged.account_dir, 'string')
    check_type('account_files', merged.account_files, 'table')
    check_type('docs_url', merged.docs_url, 'string')
    check_type('float_height', merged.float_height, 'number')
    check_type('float_width', merged.float_width, 'number')
    check_type('input_impl', merged.input_impl, 'function', true)
    check_type('known_upstream_version', merged.known_upstream_version, 'string')
    check_type('msmtp_bin', merged.msmtp_bin, 'string')
    check_type('msmtp_config', merged.msmtp_config, 'string')
    check_type('neomutt_bin', merged.neomutt_bin, 'string')
    check_type('neomuttrc', merged.neomuttrc, 'string')
    check_type('notmuch_bin', merged.notmuch_bin, 'string')
    check_type('search_limit', merged.search_limit, 'number')
    check_type('select_impl', merged.select_impl, 'function', true)
    check_type('sidebar_width', merged.sidebar_width, 'number')
    check_type('timeout_ms', merged.timeout_ms, 'number')
    check_type('update_repo_msmtp', merged.update_repo_msmtp, 'string')
    check_type('update_repo_neomutt', merged.update_repo_neomutt, 'string')
    if vim.trim(merged.neomutt_bin) == '' then
        error('neomutt: option neomutt_bin must not be blank', 2)
    end
    if merged.search_limit < 1 then
        error('neomutt: option search_limit must be >= 1', 2)
    end
    return merged
end

---Whether a `set' key holds a credential. Credential values are parsed
---for structure but masked in every report.
---@param key string Variable name.
---@return boolean credential
function M.is_credential_key(key)
    return type(key) == 'string' and key:lower():find('pass', 1, true) ~= nil
end

---Mask a credential value for display. Non-credentials pass through.
---@param key string Variable name.
---@param value string|boolean Value to display.
---@return string display
function M.mask_value(key, value)
    if M.is_credential_key(key) then
        return '<redacted>'
    end
    return tostring(value)
end

---Join backslash continuations. Pure; bounded by PARSE_LINES_MAX.
---@param lines string[] Raw lines.
---@return string[] joined
local function join_continuations(lines)
    local joined = {}
    local acc = nil
    for _, raw in ipairs(lines) do
        if #joined >= PARSE_LINES_MAX then
            break
        end
        local line = raw
        local cont = line:match('\\%s*$') ~= nil
        if cont then
            line = line:gsub('%s*\\%s*$', '')
        end
        if acc ~= nil then
            acc = acc .. ' ' .. vim.trim(line)
        else
            acc = vim.trim(line)
        end
        if not cont then
            joined[#joined + 1] = acc
            acc = nil
        end
    end
    if acc ~= nil then
        joined[#joined + 1] = acc
    end
    return joined
end

---Unquote a neomutt value: strips one layer of matching quotes.
---@param raw string Raw value text.
---@return string value
local function unquote(raw)
    local trimmed = vim.trim(raw)
    local first = trimmed:sub(1, 1)
    local last = trimmed:sub(-1)
    if #trimmed >= 2 and ((first == '"' and last == '"') or (first == "'" and last == "'")) then
        return trimmed:sub(2, -2)
    end
    return trimmed
end

---Parse one logical line into the accumulator. Unknown or malformed
---lines become warnings, never errors.
---@param parse email.neomutt.RcParse Accumulator.
---@param line string Logical line.
local function parse_line(parse, line)
    if line == '' or line:sub(1, 1) == '#' then
        return
    end
    local set_body = line:match('^set%s+(.+)$')
    if set_body ~= nil then
        local key, value = set_body:match('^([%w_]+)%s*=%s*(.-)%s*$')
        if key ~= nil then
            parse.sets[key] = unquote(value)
        else
            local flag = set_body:match('^([%w_]+)%s*$')
            if flag ~= nil then
                parse.sets[flag] = true
            else
                parse.warnings[#parse.warnings + 1] = 'unparsed set line: ' .. line:sub(1, 80)
            end
        end
        return
    end
    local source = line:match('^source%s+(.+)$')
    if source ~= nil then
        parse.sources[#parse.sources + 1] = unquote(source)
        return
    end
    local menu, key, func = line:match('^bind%s+(%S+)%s+(%S+)%s+(%S+)%s*$')
    if menu ~= nil then
        parse.binds[#parse.binds + 1] = { menu = menu, key = key, func = func }
        return
    end
    local m_menu, m_key, action = line:match('^macro%s+(%S+)%s+(%S+)%s+(.+)$')
    if m_menu ~= nil then
        parse.macros[#parse.macros + 1] = { menu = m_menu, key = m_key, action = action }
        return
    end
    local mailboxes = line:match('^mailboxes%s+(.+)$')
    if mailboxes ~= nil then
        local backtick = mailboxes:match('^`(.*)`%s*$')
        if backtick ~= nil then
            parse.virtual_mailboxes[#parse.virtual_mailboxes + 1] = backtick
        else
            for token in mailboxes:gmatch('%S+') do
                parse.mailboxes[#parse.mailboxes + 1] = token
            end
        end
        return
    end
    local hook_rest = line:match('^folder%-hook%s+(.+)$')
    if hook_rest ~= nil then
        local pattern, command = hook_rest:match('^"([^"]*)"%s*(.-)%s*$')
        if pattern == nil then
            pattern, command = hook_rest:match('^(%S+)%s*(.-)%s*$')
        end
        pattern = pattern or ''
        command = command or ''
        if command == '' then
            -- `folder-hook "set sort=threads"`: his rc applies the command
            -- to every folder (pattern doubles as the command here).
            parse.folder_hooks[#parse.folder_hooks + 1] = { pattern = '', command = pattern }
        else
            parse.folder_hooks[#parse.folder_hooks + 1] = { pattern = pattern, command = command }
        end
        return
    end
    parse.warnings[#parse.warnings + 1] = 'unparsed line: ' .. line:sub(1, 80)
end

---Parse neomuttrc text. Pure: malformed lines become warnings, never
---throw; oversized or non-string input returns nil + err.
---@param text string neomuttrc content.
---@return email.neomutt.RcParse|nil parse
---@return string|nil err
function M.parse_neomuttrc(text)
    if type(text) ~= 'string' then
        return nil, 'text must be a string'
    end
    if #text > PARSE_BYTES_MAX then
        return nil, ('text exceeds PARSE_BYTES_MAX=%d bytes'):format(PARSE_BYTES_MAX)
    end
    ---@type email.neomutt.RcParse
    local parse = {
        sets = {},
        sources = {},
        binds = {},
        macros = {},
        mailboxes = {},
        virtual_mailboxes = {},
        folder_hooks = {},
        warnings = {},
    }
    local lines = vim.split(text, '\n', { plain = true })
    for _, line in ipairs(join_continuations(lines)) do
        parse_line(parse, line)
    end
    return parse, nil
end

---Read a file, bounded. Returns nil + err on missing/unreadable input.
---@param path string File path.
---@return string|nil text
---@return string|nil err
local function read_file(path)
    local file, file_err = io.open(path, 'r')
    if file == nil then
        return nil, ('cannot read %s: %s'):format(path, tostring(file_err))
    end
    local text = file:read('*a') or ''
    file:close()
    if #text > PARSE_BYTES_MAX then
        return nil, ('%s exceeds PARSE_BYTES_MAX=%d bytes'):format(path, PARSE_BYTES_MAX)
    end
    return text, nil
end

---Parse one account file. Never throws; missing files report ok=false.
---@param name string Account file basename.
---@return email.neomutt.Account account
function M.load_account(name)
    local path = vim.fs.joinpath(M.config.account_dir, name)
    local text, read_err = read_file(path)
    if read_err ~= nil then
        return { name = name, ok = false, err = read_err, sets = {} }
    end
    local parse, parse_err = M.parse_neomuttrc(text)
    if parse_err ~= nil then
        return { name = name, ok = false, err = parse_err, sets = {} }
    end
    assert(parse ~= nil, 'parse_neomuttrc returned no error but no parse')
    return { name = name, ok = true, err = nil, sets = parse.sets }
end

---Load every configured account file. Never throws.
---@return email.neomutt.Account[] accounts In config order.
function M.load_accounts()
    local accounts = {}
    for _, name in ipairs(M.config.account_files) do
        accounts[#accounts + 1] = M.load_account(name)
    end
    return accounts
end

---Parse his main neomuttrc. Returns nil + err when the file is missing
---or unparsable; the module still works (graceful fallback).
---@return email.neomutt.RcParse|nil parse
---@return string|nil err
function M.load_neomuttrc()
    local text, read_err = read_file(M.config.neomuttrc)
    if read_err ~= nil then
        return nil, read_err
    end
    return M.parse_neomuttrc(text)
end

---Neomutt version from `neomutt -v` ("NeoMutt 20260616 ..."). Returns
---nil + err when the binary is absent or the output is unparseable.
---@return string|nil version 8-digit YYYYMMDD version.
---@return string|nil err
function M.neomutt_version()
    local bin = M.config.neomutt_bin
    if vim.fn.executable(bin) ~= 1 then
        return nil, bin .. ' is unavailable on PATH'
    end
    local result, exec_err = rce.safe_exec({ bin, '-v' }, { timeout_ms = M.config.timeout_ms })
    if exec_err ~= nil then
        return nil, exec_err
    end
    assert(result ~= nil, 'safe_exec returned no error but no result')
    local version = (result.stdout or ''):match('^NeoMutt (%d%d%d%d%d%d%d%d)')
    if version == nil then
        return nil, 'could not parse neomutt version from -v output'
    end
    return version, nil
end

---Compare 8-digit YYYYMMDD versions. Returns -1/0/1, or nil when either
---side is not a date version (never fabricates an ordering).
---@param left string First version.
---@param right string Second version.
---@return integer|nil cmp
function M.compare_date_versions(left, right)
    if type(left) ~= 'string' or type(right) ~= 'string' then
        return nil
    end
    if #left ~= 8 or #right ~= 8 or not left:match('^%d+$') or not right:match('^%d+$') then
        return nil
    end
    if left < right then
        return -1
    end
    if left > right then
        return 1
    end
    return 0
end

---Map a toolmgr binary report onto the Check status vocabulary.
---@param report table toolmgr BinaryReport.
---@return email.neomutt.Check check
local function to_check(report)
    local status = 'unavailable'
    if report.present and report.meets_minimum then
        status = 'ok'
    elseif report.present then
        status = 'below minimum'
    end
    return { name = report.name, status = status, detail = report.detail }
end

---Per-tool validation. Never throws: missing pieces are 'unavailable',
---never errors. Credential values are masked.
---@return email.neomutt.Check[] checks
function M.checks()
    local toolmgr = require('utils.toolmgr')
    local cfg = M.config
    local checks = {}
    local version, version_err = M.neomutt_version()
    if version ~= nil then
        local cmp = M.compare_date_versions(version, M.NEOMUTT_VERSION_MIN)
        local status = 'ok'
        local detail = ('neomutt: %s'):format(version)
        if cmp == nil then
            status = 'unavailable'
            detail = detail .. ' (unparseable date version)'
        elseif cmp < 0 then
            status = 'below minimum'
            detail = detail .. (' below minimum %s'):format(M.NEOMUTT_VERSION_MIN)
        else
            detail = detail .. (' meets minimum %s'):format(M.NEOMUTT_VERSION_MIN)
        end
        checks[#checks + 1] = { name = cfg.neomutt_bin, status = status, detail = detail }
    else
        checks[#checks + 1] = { name = cfg.neomutt_bin, status = 'unavailable', detail = tostring(version_err) }
    end
    checks[#checks + 1] = to_check(toolmgr.check_binary({
        name = cfg.notmuch_bin,
        version_argv = { cfg.notmuch_bin, '--version' },
    }))
    checks[#checks + 1] = to_check(toolmgr.check_binary({
        name = cfg.msmtp_bin,
        version_argv = { cfg.msmtp_bin, '--version' },
    }))
    local parse, parse_err = M.load_neomuttrc()
    if parse ~= nil then
        local set_count = 0
        for _ in pairs(parse.sets) do
            set_count = set_count + 1
        end
        checks[#checks + 1] = {
            name = 'neomuttrc',
            status = 'ok',
            detail = ('%s parses: %d sets, %d folder-hooks, %d warnings'):format(
                cfg.neomuttrc,
                set_count,
                #parse.folder_hooks,
                #parse.warnings
            ),
        }
    else
        checks[#checks + 1] = { name = 'neomuttrc', status = 'unavailable', detail = tostring(parse_err) }
    end
    local accounts = M.load_accounts()
    local ok_count = 0
    for _, account in ipairs(accounts) do
        if account.ok then
            ok_count = ok_count + 1
        end
    end
    checks[#checks + 1] = {
        name = 'accounts',
        status = ok_count == #accounts and 'ok' or 'unavailable',
        detail = ('%d/%d account files parse'):format(ok_count, #accounts),
    }
    if toolmgr.binary_present(cfg.notmuch_bin) then
        local result, exec_err = rce.safe_exec({ cfg.notmuch_bin, 'count' }, { timeout_ms = cfg.timeout_ms })
        if exec_err == nil and result ~= nil and result.code == 0 then
            checks[#checks + 1] = {
                name = 'notmuch-db',
                status = 'ok',
                detail = ('notmuch database present (%s messages counted)'):format(vim.trim(result.stdout or '')),
            }
        else
            checks[#checks + 1] = {
                name = 'notmuch-db',
                status = 'unavailable',
                detail = 'no readable notmuch database (run `notmuch new`)',
            }
        end
    else
        checks[#checks + 1] = { name = 'notmuch-db', status = 'unavailable', detail = 'notmuch binary absent' }
    end
    if vim.fn.filereadable(cfg.msmtp_config) == 1 then
        checks[#checks + 1] = { name = 'msmtp-config', status = 'ok', detail = cfg.msmtp_config .. ' exists' }
    else
        checks[#checks + 1] = {
            name = 'msmtp-config',
            status = 'unavailable',
            detail = cfg.msmtp_config .. ' missing',
        }
    end
    return checks
end

---Trim command output to the float bound. Pure.
---@param lines string[]|nil
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

---Open a centered, minimal float for command output. `q` closes it.
---@param lines string[] Body lines.
---@param title string Float title.
---@param buf_name string Scheme name so tests can find the buffer.
local function open_float(lines, title, buf_name)
    local buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_lines(buf, 0, -1, false, M.trim_output(lines))
    vim.bo[buf].modifiable = false
    vim.bo[buf].filetype = 'diver-email'
    pcall(api.nvim_buf_set_name, buf, buf_name)
    local width = math.min(M.config.float_width, vim.o.columns - 4)
    local height = math.min(M.config.float_height, vim.o.lines - 4)
    api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        style = 'minimal',
        border = 'rounded',
        title = title,
        title_pos = 'center',
    })
    vim.keymap.set('n', 'q', '<cmd>close<cr>', { buffer = buf, silent = true, desc = 'Close email float' })
end

---Open a float terminal running argv. Returns false + err when the
---binary is missing or the terminal fails to start.
---@param argv string[] argv for termopen.
---@param title string Float title.
---@param buf_name string Scheme name.
---@return boolean ok
---@return string|nil err
local function open_term_float(argv, title, buf_name)
    if vim.fn.executable(argv[1]) ~= 1 then
        return false, argv[1] .. ' is unavailable on PATH'
    end
    local buf = api.nvim_create_buf(false, true)
    local width = math.min(M.config.float_width, vim.o.columns - 4)
    local height = math.min(M.config.float_height, vim.o.lines - 4)
    api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        style = 'minimal',
        border = 'rounded',
        title = title,
        title_pos = 'center',
    })
    pcall(api.nvim_buf_set_name, buf, buf_name)
    local job = vim.fn.termopen(argv)
    if job == 0 or job == -1 then
        return false, 'termopen failed for ' .. table.concat(argv, ' ')
    end
    vim.cmd('startinsert')
    return true, nil
end

---Notify a command failure in one canonical shape.
---@param what string Command name for the message.
---@param err any Failure reason.
local function notify_failed(what, err)
    vim.notify(what .. ' failed: ' .. tostring(err), vim.log.levels.ERROR)
end

---Open neomutt in a float terminal with his neomuttrc (-F).
---@return boolean ok
---@return string|nil err
function M.open()
    return open_term_float({ M.config.neomutt_bin, '-F', M.config.neomuttrc }, ' neomutt ', 'neomutt://interactive')
end

---Compose a message in a float terminal. `neomutt <address>` enters the
---compose view addressed to that recipient (standard mutt CLI behavior).
---@param address? string Optional recipient.
---@return boolean ok
---@return string|nil err
function M.compose(address)
    local argv = { M.config.neomutt_bin, '-F', M.config.neomuttrc }
    if address ~= nil and address ~= '' then
        argv[#argv + 1] = address
    end
    return open_term_float(argv, ' neomutt compose ', 'neomutt://compose')
end

---Run a notmuch search and show matching files in a float. Flags verified
---against the notmuch-search(1) man page: --output=files --limit=N.
---@param query string notmuch query, e.g. 'tag:unread'.
---@return boolean ok
---@return string|nil err
function M.search(query)
    if type(query) ~= 'string' or vim.trim(query) == '' then
        return false, 'query must be a non-empty string'
    end
    local bin = M.config.notmuch_bin
    if vim.fn.executable(bin) ~= 1 then
        return false, bin .. ' is unavailable on PATH'
    end
    local limit = math.min(math.max(M.config.search_limit, 1), SEARCH_RESULTS_MAX)
    local result, exec_err = rce.safe_exec(
        { bin, 'search', '--output=files', '--limit', tostring(limit), query },
        { timeout_ms = M.config.timeout_ms }
    )
    if exec_err ~= nil then
        return false, exec_err
    end
    assert(result ~= nil, 'safe_exec returned no error but no result')
    if result.code ~= 0 then
        return false, vim.trim(result.stderr or 'notmuch search failed')
    end
    local lines = vim.split(result.stdout or '', '\n', { plain = true })
    local kept = {}
    for _, line in ipairs(lines) do
        if line ~= '' then
            kept[#kept + 1] = line
        end
        if #kept >= SEARCH_RESULTS_MAX then
            break
        end
    end
    if #kept == 0 then
        vim.notify('NeomuttSearch: no matches for "' .. query .. '"', vim.log.levels.INFO)
        return true, nil
    end
    open_float(kept, ' notmuch: ' .. query .. ' ', 'neomutt://search')
    return true, nil
end

---:NeomuttDocs -- summary of his setup, the verified upstream locations,
---and the notmuch flags this module uses.
local function cmd_docs()
    local lines = {
        'neomutt backend (email.clients.neomutt)',
        '',
        'Docs: ' .. M.config.docs_url,
        'Source: https://github.com/neomutt/neomutt (verified 2026-09-27)',
        '',
        'His setup (parsed from ~/.config/neomutt/neomuttrc + 5 account files):',
        '  accounts: aflabs, foamedgmail, map26gmail, qompassai, wsu',
        '  folder-hooks switch accounts per folder; sidebar width 30',
        '  bind index <C-t> tag-prefix; macro index S runs a notmuch query',
        '  sending via msmtp (/usr/bin/msmtp; per-account -a flags)',
        '',
        'notmuch flags used here (verified: notmuch-search(1) man page):',
        '  notmuch search --output=files --limit=N <query>',
        '  notmuch count   (database presence probe)',
        '',
        'Credential values (imap_pass, smtp_pass, passwordeval) are parsed',
        'for structure but masked as <redacted> in every report.',
    }
    open_float(lines, ' neomutt docs ', 'neomutt://docs')
end

---:NeomuttValidate -- one vim.notify per check; missing tools say
---"unavailable", never an error.
local function cmd_validate()
    for _, check in ipairs(M.checks()) do
        local level = check.status == 'ok' and vim.log.levels.INFO or vim.log.levels.WARN
        vim.notify(('neomutt %-13s %-13s %s'):format(check.name, check.status, check.detail), level)
    end
end

---Compare installed + known versions against the latest GitHub release
---and offer update / skip. neomutt uses 8-digit date versions, which the
---shared toolmgr dotted-version compare cannot parse, so this dialog is
---date-aware. Never installs without the explicit vim.ui.select choice.
local function cmd_update_check_neomutt()
    local toolmgr = require('utils.toolmgr')
    local current, current_err = M.neomutt_version()
    if current_err ~= nil then
        vim.notify('neomutt: not installed; nothing to update', vim.log.levels.WARN)
        return
    end
    assert(current ~= nil, 'neomutt_version returned no error but no version')
    local tag, tag_err = toolmgr.github_latest_tag(M.config.update_repo_neomutt)
    if tag == nil then
        vim.notify('neomutt: release check failed: ' .. tostring(tag_err), vim.log.levels.WARN)
        return
    end
    local cmp = M.compare_date_versions(tag, current)
    if cmp == nil then
        vim.notify('neomutt: unparseable version in comparison', vim.log.levels.WARN)
        return
    end
    if cmp <= 0 then
        vim.notify(('neomutt: up to date (%s; latest %s)'):format(current, tag), vim.log.levels.INFO)
        return
    end
    local impl = M.config.select_impl or vim.ui.select
    impl(
        { 'Update package via system package manager', 'Skip' },
        { prompt = ('neomutt %s -> %s:'):format(current, tag) },
        function(choice)
            if choice == 1 then
                toolmgr.install_package('neomutt', 'neomutt')
            end
        end
    )
end

---:NeomuttUpdateCheck -- neomutt (date-aware), msmtp (toolmgr), and an
---informational notmuch entry: notmuch's canonical repo is
---https://git.notmuchmail.org/git/notmuch, which has no GitHub releases
---endpoint, so no live tag lookup is performed for it.
local function cmd_update_check()
    cmd_update_check_neomutt()
    local toolmgr = require('utils.toolmgr')
    local current = toolmgr.command_version({ M.config.msmtp_bin, '--version' })
    toolmgr.check_update({
        tool_label = 'msmtp',
        repo = M.config.update_repo_msmtp,
        package = 'msmtp',
        current_version = current,
        -- Verified: msmtp-1.8.34 released 2026-07-31 (marlam.de/msmtp).
        known_upstream_version = '1.8.34',
        migrations = {},
        select_impl = M.config.select_impl,
    })
    local nm_current = toolmgr.command_version({ M.config.notmuch_bin, '--version' })
    vim.notify(
        (
            'notmuch: %s; canonical repo https://git.notmuchmail.org/git/notmuch '
            .. '(no GitHub releases endpoint; check the canonical repo for releases)'
        ):format(nm_current ~= nil and nm_current or 'not installed'),
        vim.log.levels.INFO
    )
end

---Prompt for a search query when :NeomuttSearch gets no argument.
---@param query string|nil Query from the command line.
local function cmd_search(query)
    if query ~= nil and query ~= '' then
        local ok, err = M.search(query)
        if not ok then
            notify_failed('NeomuttSearch', err)
        end
        return
    end
    local impl = M.config.input_impl or vim.ui.input
    impl({ prompt = 'notmuch query: ' }, function(input)
        if input == nil or input == '' then
            vim.notify('NeomuttSearch: cancelled', vim.log.levels.INFO)
            return
        end
        local ok, err = M.search(input)
        if not ok then
            notify_failed('NeomuttSearch', err)
        end
    end)
end

---Register the :Neomutt* commands. Idempotent: commands are created once;
---the config is rebuilt on every call. Performs no subprocess I/O itself.
---@param config? table Overrides merged over M.default_config.
function M.setup(config)
    M.config = M.setup_config(config)
    if setup_done then
        return
    end
    setup_done = true
    api.nvim_create_user_command('Neomutt', function()
        local ok, err = M.open()
        if not ok then
            notify_failed('Neomutt', err)
        end
    end, { desc = 'Open neomutt in a float terminal (his neomuttrc via -F)' })
    api.nvim_create_user_command('NeomuttCompose', function(cmd_opts)
        local ok, err = M.compose(cmd_opts.args ~= '' and cmd_opts.args or nil)
        if not ok then
            notify_failed('NeomuttCompose', err)
        end
    end, { nargs = '?', desc = 'Compose a message in neomutt (optional recipient)' })
    api.nvim_create_user_command('NeomuttSearch', function(cmd_opts)
        cmd_search(cmd_opts.args ~= '' and cmd_opts.args or nil)
    end, { nargs = '?', desc = 'notmuch search (--output=files) shown in a float' })
    api.nvim_create_user_command(
        'NeomuttDocs',
        cmd_docs,
        { desc = 'neomutt backend docs: his setup + verified upstream locations' }
    )
    api.nvim_create_user_command(
        'NeomuttValidate',
        cmd_validate,
        { desc = 'Per-tool validation report (binaries, rc, accounts, notmuch db, msmtp)' }
    )
    api.nvim_create_user_command(
        'NeomuttUpdateCheck',
        cmd_update_check,
        { desc = 'Update check for neomutt, msmtp, and notmuch' }
    )
end

return M
