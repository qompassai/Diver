-- /qompassai/Diver/lua/email/clients/aerc.lua
-- Qompass AI Diver Aerc Email Client Backend (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Aerc backend. Opens aerc in a float terminal, runs notmuch searches,
-- validates the aerc + neomutt accounts the module reads, and generates
-- aerc config (aerc.conf, accounts.conf, binds.conf) from his real
-- neomuttrc + five account files. Verified against aerc-config(5),
-- aerc-accounts(5), aerc-imap(5) and aerc-sendmail(5) (Debian man pages,
-- 2026-09-27); unmappable settings land as comments, never invented
-- config. No aerc config exists in his dotfiles (verified 2026-09-27),
-- so every generated file is clearly marked as generated.
--
-- Requiring this module registers nothing and performs no I/O; M.setup()
-- creates the user commands. Every subprocess goes through
-- security.rce.safe_exec in argv form. Credential values are masked in
-- every report: they are never printed.
---@module 'comms.clients.aerc'

local M = {}

local api = vim.api

local rce = require('security.rce')
local neomutt = require('comms.clients.neomutt')

local setup_done = false

---Oldest aerc this module supports. Verified: aerc 0.17.0 release
---announced on the aerc-announce list (lists.sr.ht), 2026-09-27.
M.AERC_VERSION_MIN = '0.17.0'

local OUTPUT_LINES_MAX = 2000 -- output lines kept for any float view.
local PARSE_BYTES_MAX = 1048576 -- 1 MiB cap on msmtp config parsing.
local SEARCH_RESULTS_MAX = 200 -- hard cap on notmuch search float lines.

---@class email.aerc.Account
---@field name string Section name, e.g. 'qompassai'.
---@field from string "Real Name <address>".
---@field source string aerc source URI (maildir:// or imaps://).
---@field outgoing string|nil aerc outgoing value (exec:msmtp ... or path).
---@field postpone string|nil Postponed drafts folder.
---@field copy_to string|nil Sent mail folder.
---@field signature_file string|nil Signature path.
---@field notes string[] Unmappable settings recorded as comments.

---@class email.aerc.Check
---@field name string Tool or aspect probed.
---@field status 'ok'|'unavailable'|'below minimum'
---@field detail string One-line human summary (credentials masked).

M.default_config = {
    -- aerc binary probed on PATH; overridable for tests.
    aerc_bin = 'aerc',
    -- Destination directory for :AercGenerate; overridable for tests.
    aerc_dir = vim.fn.expand('~/.config/aerc'),
    -- Directory holding his neomutt account files; overridable for tests.
    account_dir = vim.fn.expand('~/.config/neomutt'),
    -- His five accounts (verified 2026-09-27 in dotfiles).
    account_files = {
        'account.aflabs',
        'account.foamedgmail',
        'account.map26gmail',
        'account.qompassai',
        'account.wsu',
    },
    -- Canonical aerc documentation.
    docs_url = 'https://aerc-mail.org/',
    -- Rows of the search/validate float.
    float_height = 24,
    -- Cols of the search/validate float.
    float_width = 110,
    -- vim.ui.input replacement; nil uses the real one (test seam).
    input_impl = nil,
    -- Newest aerc this module knows about (verified: Debian man pages
    -- reference aerc 0.18.2, 2026-09-27).
    known_upstream_version = '0.18.2',
    -- His msmtp config; used to map sendmail accounts to msmtp accounts.
    msmtp_config = vim.fn.expand('~/.config/msmtp/config'),
    -- neomutt binary probed on PATH; overridable for tests.
    neomutt_bin = 'neomutt',
    -- notmuch binary probed on PATH; overridable for tests.
    notmuch_bin = 'notmuch',
    -- --limit passed to `notmuch search`.
    search_limit = 50,
    -- vim.ui.select replacement; nil uses the real one (test seam).
    select_impl = nil,
    -- Canonical upstream repo (verified: git.sr.ht, 2026-09-27). aerc's
    -- GitHub mirror exposes no releases endpoint, so no live tag lookup
    -- is performed against it.
    sourcehut_url = 'https://git.sr.ht/~rjarry/aerc',
    -- Wall-clock cap per subprocess.
    timeout_ms = 30000,
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
        error(('aerc: option %s must be %s, got %s'):format(name, expected, type(value)), 2)
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
    check_type('aerc_bin', merged.aerc_bin, 'string')
    check_type('aerc_dir', merged.aerc_dir, 'string')
    check_type('docs_url', merged.docs_url, 'string')
    check_type('float_height', merged.float_height, 'number')
    check_type('float_width', merged.float_width, 'number')
    check_type('input_impl', merged.input_impl, 'function', true)
    check_type('known_upstream_version', merged.known_upstream_version, 'string')
    check_type('msmtp_config', merged.msmtp_config, 'string')
    check_type('neomutt_bin', merged.neomutt_bin, 'string')
    check_type('notmuch_bin', merged.notmuch_bin, 'string')
    check_type('search_limit', merged.search_limit, 'number')
    check_type('select_impl', merged.select_impl, 'function', true)
    check_type('sourcehut_url', merged.sourcehut_url, 'string')
    check_type('timeout_ms', merged.timeout_ms, 'number')
    if vim.trim(merged.aerc_bin) == '' then
        error('aerc: option aerc_bin must not be blank', 2)
    end
    if vim.trim(merged.aerc_dir) == '' then
        error('aerc: option aerc_dir must not be blank', 2)
    end
    if merged.search_limit < 1 then
        error('aerc: option search_limit must be >= 1', 2)
    end
    return merged
end

---Percent-encode an IMAP username for an aerc-imap(5) source URI.
---Only unreserved characters pass through; '@' -> '%40', etc.
---@param user string Raw username.
---@return string encoded
function M.urlencode(user)
    return (
        tostring(user):gsub('[^%w%-%.%_~]', function(char)
            return ('%%%02X'):format(string.byte(char))
        end)
    )
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

---@class email.aerc.MsmtpAccount
---@field name string msmtp account name.
---@field from string|nil from address.

---Parse his msmtp config: `account <name>` blocks with `from <addr>`.
---Structure only; credential lines are ignored.
---@param text string msmtp config content.
---@return email.aerc.MsmtpAccount[] accounts
function M.parse_msmtp_config(text)
    if type(text) ~= 'string' then
        return {}
    end
    local accounts = {}
    local current = nil
    for _, line in ipairs(vim.split(text, '\n', { plain = true })) do
        local name = line:match('^account%s+(%S+)%s*$')
        if name ~= nil then
            current = { name = name, from = nil }
            accounts[#accounts + 1] = current
        else
            local from = line:match('^from%s+(%S+)%s*$')
            if from ~= nil and current ~= nil and current.from == nil then
                current.from = from
            end
        end
    end
    return accounts
end

---Find the msmtp account whose `from' matches the given address.
---@param accounts email.aerc.MsmtpAccount[] Parsed msmtp accounts.
---@param address string From address to match.
---@return email.aerc.MsmtpAccount|nil account
function M.msmtp_account_for(accounts, address)
    for _, account in ipairs(accounts) do
        if account.from ~= nil and account.from == address then
            return account
        end
    end
    return nil
end

---Map a neomutt source folder to an aerc source URI.
---Verified forms (aerc-imap(5), aerc-accounts(5), 2026-09-27):
---  imaps://user@host:port   (IMAP; user URL-encoded)
---  maildir:///path          (local Maildir)
---@param folder string neomutt `folder' value.
---@param imap_user string|boolean neomutt `imap_user' value.
---@param notes string[] Notes accumulator for unmappable details.
---@return string source
function M.map_source(folder, imap_user, notes)
    local scheme, rest = tostring(folder):match('^(%w+)://(.+)$')
    if scheme == 'imaps' or scheme == 'imap' then
        if type(imap_user) == 'string' and imap_user ~= '' then
            return scheme .. '://' .. M.urlencode(imap_user) .. '@' .. rest
        end
        notes[#notes + 1] = 'IMAP folder has no imap_user; supply credentials via source-cred-cmd (aerc-imap(5))'
        return tostring(folder)
    end
    local expanded = vim.fn.expand(tostring(folder))
    return 'maildir://' .. expanded
end

---Map a neomutt sendmail/smtp setup to an aerc outgoing value.
---Verified forms (aerc-sendmail(5), aerc-accounts(5), 2026-09-27):
---  /path/to/sendmail-compatible   (aerc passes recipients as argv)
---  exec:command with args         (aerc-sendmail(5) notes `exec:' forms)
---@param sets table<string, string|boolean> Parsed neomutt `set' variables.
---@param msmtp_accounts email.aerc.MsmtpAccount[] Parsed msmtp accounts.
---@param notes string[] Notes accumulator for unmappable details.
---@return string|nil outgoing
function M.map_outgoing(sets, msmtp_accounts, notes)
    local sendmail = sets.sendmail
    if type(sendmail) == 'string' and sendmail ~= '' then
        local account = sendmail:match('%-a%s+([%w_%-]+)')
        if account ~= nil then
            return 'exec:msmtp -a ' .. account
        end
        local path = sendmail:match('^"([^"]+)"')
        if path ~= nil then
            sendmail = path
        end
        notes[#notes + 1] = 'sendmail had no -a account flag; using the binary path verbatim'
        return vim.fn.expand(sendmail)
    end
    local from = sets.from
    if type(from) == 'string' and from ~= '' then
        local account = M.msmtp_account_for(msmtp_accounts, from)
        if account ~= nil then
            notes[#notes + 1] = 'no sendmail in neomutt account; mapped via msmtp account with matching from'
            return 'exec:msmtp -a ' .. account.name
        end
    end
    notes[#notes + 1] = 'no sendmail or matching msmtp account found; set outgoing per aerc-smtp(5)'
    return nil
end

---Map one parsed neomutt account to an aerc accounts.conf section.
---Never throws; unmappable pieces land in notes as comments.
---@param name string Section name.
---@param sets table<string, string|boolean> Parsed `set' variables.
---@param msmtp_accounts email.aerc.MsmtpAccount[] Parsed msmtp accounts.
---@return email.aerc.Account account
function M.map_account(name, sets, msmtp_accounts)
    local notes = {}
    local realname = tostring(sets.realname or '')
    local from_addr = tostring(sets.from or '')
    local from = realname ~= '' and from_addr ~= '' and (realname .. ' <' .. from_addr .. '>') or from_addr
    if from == '' then
        notes[#notes + 1] = 'no from/realname in neomutt account; set `from' .. "' manually"
        from = 'FIXME <fixme@localhost>'
    end
    local folder = sets.folder
    local source
    if type(folder) == 'string' and folder ~= '' then
        source = M.map_source(folder, sets.imap_user, notes)
    else
        notes[#notes + 1] = 'no folder in neomutt account; set source per aerc-accounts(5)'
        source = 'FIXME'
    end
    ---@type email.aerc.Account
    local account = {
        name = name,
        from = from,
        source = source,
        outgoing = M.map_outgoing(sets, msmtp_accounts, notes),
        postpone = nil,
        copy_to = nil,
        signature_file = nil,
        notes = notes,
    }
    local postponed = sets.postponed
    if type(postponed) == 'string' and postponed ~= '' then
        account.postpone = postponed:gsub('^%+', ''):gsub('^"(.+)"$', '%1')
    end
    local record = sets.record
    if type(record) == 'string' and record ~= '' then
        account.copy_to = record:gsub('^%+', ''):gsub('^"(.+)"$', '%1')
    end
    local signature = sets.signature
    if type(signature) == 'string' and signature ~= '' then
        account.signature_file = vim.fn.expand(signature)
    end
    -- Record neomutt-only semantics that have no verified aerc equivalent.
    if sets.sort ~= nil then
        notes[#notes + 1] = 'neomutt sort='
            .. tostring(sets.sort)
            .. ' is per-folder; aerc has only a global sort option'
    end
    if sets.crypt_use_gpgme ~= nil then
        notes[#notes + 1] = 'neomutt crypt_use_gpgme has no verified aerc-accounts equivalent;'
            .. ' see pgp-provider in aerc-config(5)'
    end
    return account
end

---Load his neomutt accounts and map them to aerc sections. Never
---throws; broken files become accounts with FIXME notes so the render
---stays reviewable.
---@return email.aerc.Account[] accounts
---@return string|nil err Set only when no account could be loaded at all.
function M.load_mapped_accounts()
    -- Load accounts with neomutt's own loader; the binary is irrelevant.
    local neomutt_cfg = neomutt.setup_config({
        account_dir = M.config.account_dir,
        account_files = M.config.account_files,
    })
    local accounts = {}
    local msmtp_text = read_file(M.config.msmtp_config)
    local msmtp_accounts = M.parse_msmtp_config(type(msmtp_text) == 'string' and msmtp_text or '')
    local loaded = 0
    for _, name in ipairs(M.config.account_files) do
        local path = vim.fs.joinpath(neomutt_cfg.account_dir, name)
        local text, read_err = read_file(path)
        local section = name:gsub('^account%.', '')
        if read_err ~= nil or type(text) ~= 'string' then
            accounts[#accounts + 1] = {
                name = section,
                from = 'FIXME <fixme@localhost>',
                source = 'FIXME',
                outgoing = nil,
                postpone = nil,
                copy_to = nil,
                signature_file = nil,
                notes = { 'neomutt account file missing or unreadable: ' .. tostring(read_err) },
            }
        else
            local parse, parse_err = neomutt.parse_neomuttrc(text)
            if parse_err ~= nil then
                accounts[#accounts + 1] = {
                    name = section,
                    from = 'FIXME <fixme@localhost>',
                    source = 'FIXME',
                    outgoing = nil,
                    postpone = nil,
                    copy_to = nil,
                    signature_file = nil,
                    notes = { 'neomutt account file failed to parse: ' .. tostring(parse_err) },
                }
            else
                assert(parse ~= nil, 'parse_neomuttrc returned no error but no parse')
                loaded = loaded + 1
                accounts[#accounts + 1] = M.map_account(section, parse.sets, msmtp_accounts)
            end
        end
    end
    if loaded == 0 then
        return accounts, 'no neomutt account files could be loaded'
    end
    return accounts, nil
end

---Render aerc.conf: sidebar mirrors his sidebar_width=30; sorting is
---global-only (commented, per the verified aerc-config(5) shape).
---@return string text
function M.render_aerc_conf()
    return table.concat({
        '# aerc.conf - GENERATED by diver email.clients.aerc from his neomutt config.',
        '# Review before use. Man pages: aerc-config(5), aerc-accounts(5).',
        '# Docs: ' .. M.config.docs_url,
        '',
        '[general]',
        '# neomutt set crypt_use_gpgme: no verified equivalent; pgp-provider is the closest.',
        'pgp-provider = gpg',
        '',
        '[ui]',
        '# neomutt set sidebar_width = 30 (includes the sidebar border in aerc).',
        'sidebar-width = 32',
        '# neomutt index_format / date_format are format strings with no direct aerc',
        '# equivalent; aerc uses index-columns plus column-<name> templates (aerc-templates(7)).',
        '# neomutt set sort=threads: aerc sort is global-only, so it is left at the default;',
        '# see the per-account notes in accounts.conf.',
        '',
    }, '\n')
end

---Render accounts.conf. Section names are the account file basenames
---without the 'account.' prefix. Credentials are never inlined: IMAP
---accounts keep a source-cred-cmd comment (aerc-imap(5)); accounts.conf
---must be mode 0600, which :AercGenerate enforces on write.
---@param accounts email.aerc.Account[] Mapped accounts.
---@return string text
function M.render_accounts_conf(accounts)
    local lines = {
        '# accounts.conf - GENERATED by diver email.clients.aerc from his neomutt account files.',
        '# No aerc config exists in his dotfiles (verified 2026-09-27); this is a starting point.',
        '# Keep this file mode 0600 (aerc-accounts(5) requires it); :AercGenerate does this.',
        '',
    }
    for _, account in ipairs(accounts) do
        lines[#lines + 1] = '[' .. account.name .. ']'
        lines[#lines + 1] = 'from = ' .. account.from
        lines[#lines + 1] = 'source = ' .. account.source
        if account.source:match('^imaps?://') ~= nil and account.source:find('@') == nil then
            lines[#lines + 1] = '# Credentials: supply via source-cred-cmd per aerc-imap(5) (never inlined here).'
        end
        if account.outgoing ~= nil then
            lines[#lines + 1] = 'outgoing = ' .. account.outgoing
        else
            lines[#lines + 1] = '# outgoing: unset; set per aerc-smtp(5) or aerc-sendmail(5).'
        end
        if account.postpone ~= nil then
            lines[#lines + 1] = 'postpone = ' .. account.postpone
        end
        if account.copy_to ~= nil then
            lines[#lines + 1] = 'copy-to = ' .. account.copy_to
        end
        if account.signature_file ~= nil then
            lines[#lines + 1] = 'signature-file = ' .. account.signature_file
        end
        for _, note in ipairs(account.notes) do
            lines[#lines + 1] = '# note: ' .. note
        end
        lines[#lines + 1] = ''
    end
    return table.concat(lines, '\n')
end

---Render binds.conf. His neomutt bindings (tag-prefix on <C-t>, the
---notmuch macro on S) have no verified aerc equivalents found in
---aerc-binds(5), so they land as comments under [global]; aerc's own
---defaults apply until he binds them explicitly.
---@return string text
function M.render_binds_conf()
    return table.concat({
        '# binds.conf - GENERATED by diver email.clients.aerc from his neomutt keybindings.',
        '# Man page: aerc-binds(5). No verified aerc equivalents found for his bindings,',
        '# so none are active below; aerc defaults apply.',
        '',
        '[global]',
        '# neomutt: bind index \\ct tag-prefix -> no verified aerc equivalent; left unbound.',
        '# neomutt: macro index S <search>...notmuch... -> aerc :query (notmuch accounts, 0.18.0+);',
        '# bind it explicitly here when his aerc account type is confirmed.',
        '',
    }, '\n')
end

---Open a centered, minimal float for command output. `q` closes it.
---@param lines string[] Body lines.
---@param title string Float title.
---@param buf_name string Scheme name so tests can find the buffer.
local function open_float(lines, title, buf_name)
    local kept = {}
    for index = 1, math.min(#lines, OUTPUT_LINES_MAX) do
        kept[#kept + 1] = lines[index]
    end
    local buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_lines(buf, 0, -1, false, kept)
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
    local height = math.min(M.config.float_width, vim.o.lines - 4)
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

---Open aerc in a float terminal.
---@return boolean ok
---@return string|nil err
function M.open()
    return open_term_float({ M.config.aerc_bin }, ' aerc ', 'aerc://interactive')
end

---Compose a message. aerc's :new command takes no recipient argument,
---so this opens aerc itself in a float terminal; recipients are entered
---in the compose view.
---@param _address any Unused; kept for the backend contract.
---@return boolean ok
---@return string|nil err
function M.compose(_address)
    return open_term_float({ M.config.aerc_bin }, ' aerc compose ', 'aerc://compose')
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
    local kept = {}
    for _, line in ipairs(vim.split(result.stdout or '', '\n', { plain = true })) do
        if line ~= '' then
            kept[#kept + 1] = line
        end
        if #kept >= SEARCH_RESULTS_MAX then
            break
        end
    end
    if #kept == 0 then
        vim.notify('AercSearch: no matches for "' .. query .. '"', vim.log.levels.INFO)
        return true, nil
    end
    open_float(kept, ' notmuch: ' .. query .. ' ', 'aerc://search')
    return true, nil
end

---Write one file atomically (tmp + rename). accounts.conf gets 0600.
---@param dir string Destination directory.
---@param name string File name.
---@param text string File content.
---@return boolean ok
---@return string|nil err
local function write_one(dir, name, text)
    local path = vim.fs.joinpath(dir, name)
    local tmp = path .. '.tmp'
    local file, file_err = io.open(tmp, 'w')
    if file == nil then
        return false, ('cannot write %s: %s'):format(tmp, tostring(file_err))
    end
    file:write(text)
    file:close()
    if name == 'accounts.conf' then
        vim.fn.setfperm(tmp, 'rw-------')
    end
    local ok, rename_err = os.rename(tmp, path)
    if not ok then
        os.remove(tmp)
        return false, ('cannot rename %s to %s: %s'):format(tmp, path, tostring(rename_err))
    end
    return true, nil
end

---Write the three generated configs under aerc_dir. Never touches the
---real ~/.config/aerc unless the config points there.
---@param files { name: string, text: string }[] Rendered configs.
---@return boolean ok
---@return string|nil err
local function write_configs(files)
    local dir = M.config.aerc_dir
    -- vim.fn.mkdir throws E739 when a path component exists as a file
    -- (e.g. /dev/null/aerc), so the pcall is load-bearing.
    local mkdir_ok = pcall(vim.fn.mkdir, dir, 'p')
    if not mkdir_ok and vim.fn.isdirectory(dir) ~= 1 then
        return false, 'cannot create directory ' .. dir
    end
    for _, file in ipairs(files) do
        local ok, err = write_one(dir, file.name, file.text)
        if not ok then
            return false, err
        end
    end
    return true, nil
end

---Show the would-be configs in a float. Writes nothing.
---@param files { name: string, text: string }[] Rendered configs.
local function show_diff_only(files)
    local lines = {}
    for _, file in ipairs(files) do
        lines[#lines + 1] = ('=== %s ==='):format(file.name)
        for _, line in ipairs(vim.split(file.text, '\n', { plain = true })) do
            lines[#lines + 1] = line
        end
        lines[#lines + 1] = ''
    end
    open_float(lines, ' aerc configs (diff only) ', 'aerc://generate-diff')
end

---:AercGenerate -- vim.ui.select over exactly Write / Show diff / Cancel.
---Write goes only under M.config.aerc_dir (default ~/.config/aerc);
---accounts.conf is written 0600. Cancel writes nothing.
local function cmd_generate()
    local accounts, load_err = M.load_mapped_accounts()
    if load_err ~= nil then
        notify_failed('AercGenerate', load_err)
        return
    end
    local files = {
        { name = 'aerc.conf', text = M.render_aerc_conf() },
        { name = 'accounts.conf', text = M.render_accounts_conf(accounts) },
        { name = 'binds.conf', text = M.render_binds_conf() },
    }
    local impl = M.config.select_impl or vim.ui.select
    impl(
        { 'Write configs', 'Show diff only', 'Cancel' },
        { prompt = ('Write aerc configs to %s?'):format(M.config.aerc_dir) },
        function(choice)
            if choice == 1 then
                local ok, err = write_configs(files)
                if ok then
                    vim.notify(
                        ('AercGenerate: wrote aerc.conf, accounts.conf (0600), binds.conf to %s'):format(
                            M.config.aerc_dir
                        ),
                        vim.log.levels.INFO
                    )
                else
                    notify_failed('AercGenerate', err)
                end
            elseif choice == 2 then
                show_diff_only(files)
            else
                vim.notify('AercGenerate: cancelled (nothing written)', vim.log.levels.INFO)
            end
        end
    )
end

---:AercDocs -- verified upstream locations, the "no aerc config in
---dotfiles" fact, and the mapping policy.
local function cmd_docs()
    local lines = {
        'aerc backend (email.clients.aerc)',
        '',
        'Docs: ' .. M.config.docs_url,
        'Canonical repo: ' .. M.config.sourcehut_url .. ' (verified 2026-09-27)',
        'Man pages consulted (Debian, 2026-09-27):',
        '  aerc-config(5), aerc-accounts(5), aerc-imap(5), aerc-sendmail(5)',
        '',
        'No aerc config exists in his dotfiles (verified 2026-09-27).',
        ':AercGenerate builds aerc.conf, accounts.conf, binds.conf from his',
        'five neomutt account files. Unmappable settings (neomutt-only sidebar',
        'semantics, per-folder sort, keybindings with no verified equivalent)',
        'land as comments, never invented config.',
        '',
        'notmuch flags used here (verified: notmuch-search(1) man page):',
        '  notmuch search --output=files --limit=N <query>',
        '',
        'Credential values are never inlined: IMAP accounts keep a',
        'source-cred-cmd comment (aerc-imap(5)); accounts.conf is 0600.',
    }
    open_float(lines, ' aerc docs ', 'aerc://docs')
end

---Per-tool validation for the aerc backend. Never throws.
---@return email.aerc.Check[] checks
function M.checks()
    local toolmgr = require('utils.toolmgr')
    local cfg = M.config
    local checks = {}
    checks[#checks + 1] = (function()
        local report = toolmgr.check_binary({
            name = cfg.aerc_bin,
            version_argv = { cfg.aerc_bin, '-v' },
            version_pattern = '(%d+%.%d+%.%d+)',
            minimum_version = M.AERC_VERSION_MIN,
        })
        local status = 'unavailable'
        if report.present and report.meets_minimum then
            status = 'ok'
        elseif report.present then
            status = 'below minimum'
        end
        return { name = cfg.aerc_bin, status = status, detail = report.detail }
    end)()
    local accounts, load_err = M.load_mapped_accounts()
    if load_err == nil then
        checks[#checks + 1] = {
            name = 'accounts',
            status = 'ok',
            detail = ('%d neomutt accounts mapped to aerc sections'):format(#accounts),
        }
    else
        checks[#checks + 1] = { name = 'accounts', status = 'unavailable', detail = tostring(load_err) }
    end
    local rendered = M.render_aerc_conf() .. M.render_accounts_conf(accounts) .. M.render_binds_conf()
    checks[#checks + 1] = {
        name = 'render',
        status = #rendered > 0 and 'ok' or 'unavailable',
        detail = ('three-file render is %d bytes'):format(#rendered),
    }
    if vim.fn.filereadable(cfg.msmtp_config) == 1 then
        checks[#checks + 1] = { name = 'msmtp-config', status = 'ok', detail = cfg.msmtp_config .. ' exists' }
    else
        checks[#checks + 1] = {
            name = 'msmtp-config',
            status = 'unavailable',
            detail = cfg.msmtp_config .. ' missing',
        }
    end
    local dir_state = 'missing'
    if vim.fn.isdirectory(cfg.aerc_dir) == 1 then
        dir_state = 'exists'
    end
    checks[#checks + 1] = { name = 'aerc-dir', status = 'ok', detail = cfg.aerc_dir .. ' ' .. dir_state }
    return checks
end

---:AercValidate -- one vim.notify per check; missing tools say
---"unavailable", never an error.
local function cmd_validate()
    for _, check in ipairs(M.checks()) do
        local level = check.status == 'ok' and vim.log.levels.INFO or vim.log.levels.WARN
        vim.notify(('aerc %-13s %-13s %s'):format(check.name, check.status, check.detail), level)
    end
end

---:AercUpdateCheck -- aerc's canonical home is SourceHut
---(https://git.sr.ht/~rjarry/aerc); its GitHub mirror exposes no
---releases endpoint, so no live tag lookup is performed. Reports the
---installed version (if any) against the newest version this module
---knows about, and points at the canonical repo for the release list.
local function cmd_update_check()
    local toolmgr = require('utils.toolmgr')
    local current = toolmgr.command_version({ M.config.aerc_bin, '-v' })
    local current_s = current ~= nil and current or 'not installed'
    vim.notify(
        (
            'aerc: %s; newest known %s; check releases at %s (no releases endpoint '
            .. 'on the GitHub mirror, so this is informational only)'
        ):format(current_s, M.config.known_upstream_version, M.config.sourcehut_url),
        vim.log.levels.INFO
    )
end

---Prompt for a search query when :AercSearch gets no argument.
---@param query string|nil Query from the command line.
local function cmd_search(query)
    if query ~= nil and query ~= '' then
        local ok, err = M.search(query)
        if not ok then
            notify_failed('AercSearch', err)
        end
        return
    end
    local impl = M.config.input_impl or vim.ui.input
    impl({ prompt = 'notmuch query: ' }, function(input)
        if input == nil or input == '' then
            vim.notify('AercSearch: cancelled', vim.log.levels.INFO)
            return
        end
        local ok, err = M.search(input)
        if not ok then
            notify_failed('AercSearch', err)
        end
    end)
end

---Register the :Aerc* commands. Idempotent: commands are created once;
---the config is rebuilt on every call. Performs no subprocess I/O itself.
---@param config? table Overrides merged over M.default_config.
function M.setup(config)
    M.config = M.setup_config(config)
    if setup_done then
        return
    end
    setup_done = true
    api.nvim_create_user_command('Aerc', function()
        local ok, err = M.open()
        if not ok then
            notify_failed('Aerc', err)
        end
    end, { desc = 'Open aerc in a float terminal' })
    api.nvim_create_user_command('AercCompose', function(cmd_opts)
        local ok, err = M.compose(cmd_opts.args ~= '' and cmd_opts.args or nil)
        if not ok then
            notify_failed('AercCompose', err)
        end
    end, { nargs = '?', desc = 'Compose a message in aerc' })
    api.nvim_create_user_command('AercSearch', function(cmd_opts)
        cmd_search(cmd_opts.args ~= '' and cmd_opts.args or nil)
    end, { nargs = '?', desc = 'notmuch search (--output=files) shown in a float' })
    api.nvim_create_user_command(
        'AercDocs',
        cmd_docs,
        { desc = 'aerc backend docs: upstream locations + generation policy' }
    )
    api.nvim_create_user_command(
        'AercValidate',
        cmd_validate,
        { desc = 'Per-tool validation report (binary, accounts, render, msmtp)' }
    )
    api.nvim_create_user_command(
        'AercUpdateCheck',
        cmd_update_check,
        { desc = 'Informational update check (SourceHut has no releases endpoint)' }
    )
    api.nvim_create_user_command(
        'AercGenerate',
        cmd_generate,
        { desc = 'Generate aerc.conf/accounts.conf/binds.conf from neomutt accounts' }
    )
end

return M
