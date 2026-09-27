-- tests/lua/email_clients.lua
-- Balanced suite for the email client modules (email.clients.neomutt,
-- email.clients.aerc, email.clients): exactly half adversarial and half
-- validation (7 checks each, 14 total). Run from the repo root with the
-- FULL config (never -u NONE, never --clean):
--   ~/workspace/tools/neovim-nightly/bin/nvim --headless -i NONE \
--     -u ~/workspace/repos/diver/init.lua -l tests/lua/email_clients.lua
-- Exit 0 when every check behaves, 1 otherwise. Report goes to
-- $EMAIL_REPORT (default /tmp/email_report.txt).
-- No real email tools are touched: fake `fake-neomutt`, `fake-notmuch`,
-- `fake-msmtp`, `fake-aerc` on PATH log every argv they receive to
-- $EMAIL_FAKE_LOG; bogus binary names exercise the unavailable paths;
-- generated aerc configs go to temp dirs only; Cancel must write
-- nothing (asserted); credential values never appear in reports.
local report_path = os.getenv('EMAIL_REPORT') or '/tmp/email_report.txt'
local log_lines = {}
local function emit(line)
    log_lines[#log_lines + 1] = line
end
local adv_passed, adv_failed = 0, 0
local val_passed, val_failed = 0, 0
local function adv_check(cond, msg)
    if cond then
        adv_passed = adv_passed + 1
        emit('ok [A] - ' .. msg)
    else
        adv_failed = adv_failed + 1
        emit('NOT OK [A] - ' .. msg)
    end
end
local function val_check(cond, msg)
    if cond then
        val_passed = val_passed + 1
        emit('ok [V] - ' .. msg)
    else
        val_failed = val_failed + 1
        emit('NOT OK [V] - ' .. msg)
    end
end

local neomutt = require('email.clients.neomutt')
local aerc = require('email.clients.aerc')
local clients = require('email.clients')
local email = require('email')

local fakebin = '/tmp/email_test_bin'
local fake_log = '/tmp/email_fake.log'
local fixture_dir = '/tmp/email_fixtures'
local saved_path = vim.env.PATH or ''

local function write_file(path, text)
    local f = io.open(path, 'w')
    assert(f ~= nil, 'cannot write ' .. path)
    f:write(text)
    f:close()
end

os.execute('mkdir -p ' .. fakebin)
-- Fake `fake-neomutt`: answers `-v` with a date version, logs every other
-- argv to $EMAIL_FAKE_LOG.
write_file(
    fakebin .. '/fake-neomutt',
    [=[
#!/bin/sh
log="${EMAIL_FAKE_LOG:-/tmp/email_fake.log}"
printf '%s\n' "$*" >> "$log"
if [ "$1" = "-v" ]; then
  echo "NeoMutt 20260616"
  exit 0
fi
exit 0
]=]
)
-- Fake `fake-notmuch`: answers count/version, emits two files for
-- search, logs every argv.
write_file(
    fakebin .. '/fake-notmuch',
    [=[
#!/bin/sh
log="${EMAIL_FAKE_LOG:-/tmp/email_fake.log}"
printf '%s\n' "$*" >> "$log"
if [ "$1" = "search" ]; then
  echo "/tmp/mail/a"
  echo "/tmp/mail/b"
  exit 0
fi
if [ "$1" = "count" ]; then
  echo "42"
  exit 0
fi
if [ "$1" = "--version" ]; then
  echo "notmuch 0.40"
  exit 0
fi
exit 1
]=]
)
-- Fake `fake-msmtp`: answers --version.
write_file(
    fakebin .. '/fake-msmtp',
    [=[
#!/bin/sh
if [ "$1" = "--version" ]; then
  echo "msmtp version 1.8.34"
  exit 0
fi
exit 1
]=]
)
-- Fake `fake-aerc`: answers -v with a dotted version.
write_file(
    fakebin .. '/fake-aerc',
    [=[
#!/bin/sh
if [ "$1" = "-v" ]; then
  echo "aerc 0.18.2"
  exit 0
fi
exit 1
]=]
)
os.execute(
    'chmod +x '
        .. fakebin
        .. '/fake-neomutt '
        .. fakebin
        .. '/fake-notmuch '
        .. fakebin
        .. '/fake-msmtp '
        .. fakebin
        .. '/fake-aerc'
)
vim.env.PATH = fakebin .. ':' .. saved_path
vim.env.EMAIL_FAKE_LOG = fake_log

local function clear_log()
    os.remove(fake_log)
end
local function read_log()
    local f = io.open(fake_log, 'r')
    if f == nil then
        return ''
    end
    local text = f:read('*a') or ''
    f:close()
    return text
end

local function close_floats()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local cfg = vim.api.nvim_win_get_config(win)
        if cfg.relative ~= nil and cfg.relative ~= '' then
            vim.api.nvim_win_close(win, true)
        end
    end
end

-- Fixtures modeled on his real neomuttrc + account files (fake secrets).
os.execute('mkdir -p ' .. fixture_dir)
write_file(
    fixture_dir .. '/neomuttrc',
    [[
# fixture neomuttrc
set folder = "~/.mail"
set sort = "threads"
set sort_aux = "reverse-last-date-received"
set sidebar_visible = yes
set sidebar_width = 30
set editor = "nvim"
source ~/.config/neomutt/account.qompassai
bind index \ct tag-prefix
macro index S "<search>notmuch search --output=files<enter>" "notmuch search"
mailboxes =INBOX
folder-hook "set sort=threads"
folder-hook .mail/qompassai "source ~/.config/neomutt/account.qompassai"
folder-hook .mail/gmail/foamedgmail "source ~/.config/neomutt/account.foamedmap"
]]
)
write_file(
    fixture_dir .. '/account.qompassai',
    [[
set folder = "imaps://imap.qompass.ai:993"
set from = "map@qompass.ai"
set realname = "Map Porter"
set imap_user = "map@qompass.ai"
set imap_pass = "fake-secret-123"
set smtp_url = "smtp://map@smtp.qompass.ai:587"
set smtp_pass = "fake-secret-123"
set record = "+[Gmail]/Sent"
]]
)
write_file(
    fixture_dir .. '/account.map26gmail',
    [[
set folder = "~/.mail/gmail/matt.a.porter26"
set from = "matt.a.porter26@gmail.com"
set realname = "Matt Porter"
set postponed = "+[Gmail]/Drafts"
set record = "+[Gmail]/Sent"
set sendmail = "/usr/bin/msmtp -a gmail-map26"
]]
)
write_file(
    fixture_dir .. '/account.aflabs',
    [[
set folder = "~/.mail/aflabs"
set from = "matt@aflabs.io"
set realname = "Matt Porter"
set imap_user = "matt@aflabs.io"
set imap_pass = "fake-secret-456"
set smtp_url = "smtp://matt@aflabs.io@smtp.aflabs.io:587"
set smtp_pass = "fake-secret-456"
set signature = "~/.config/neomutt/signatures/aflabs"
]]
)
write_file(
    fixture_dir .. '/account.foamedgmail',
    [[set folder = "~/.mail/gmail/foamedgmail"
]]
)
write_file(
    fixture_dir .. '/account.wsu',
    [[
set folder = "~/.mail/wsu"
set from = "matt@wsu.edu"
set realname = "Matt Porter"
set sendmail = "/usr/bin/msmtp -a wsu"
set signature = "~/.config/neomutt/signatures/wsu"
]]
)
-- msmtp fixture: two accounts whose from addresses match fixtures above.
write_file(
    fixture_dir .. '/msmtp_config',
    [[
account qompass
from map@qompass.ai
account gmail-map26
from matt.a.porter26@gmail.com
account wsu
from matt@wsu.edu
]]
)

local fixture_cfg = {
    account_dir = fixture_dir,
    neomuttrc = fixture_dir .. '/neomuttrc',
    neomutt_bin = 'fake-neomutt',
    notmuch_bin = 'fake-notmuch',
    msmtp_bin = 'fake-msmtp',
    msmtp_config = fixture_dir .. '/msmtp_config',
}

-- ======================= adversarial (7) =======================

do
    -- A1: oversized neomuttrc text is rejected, never parsed.
    local big = string.rep('#', 1048576 + 1)
    local parse, err = neomutt.parse_neomuttrc(big)
    adv_check(
        parse == nil and err ~= nil and err:find('PARSE_BYTES_MAX', 1, true) ~= nil,
        'A1 oversized rc: parse_neomuttrc rejects >1 MiB with a named-limit error'
    )
end

do
    -- A2: credential values never surface in renders or masked displays.
    neomutt.setup(fixture_cfg)
    local account = neomutt.load_account('account.qompassai')
    local rendered = aerc.render_accounts_conf(aerc.load_mapped_accounts())
    local leaks = account.sets.imap_pass == 'fake-secret-123' -- structure kept...
        and rendered:find('fake-secret-123', 1, true) == nil -- ...value never rendered
        and neomutt.mask_value('imap_pass', 'fake-secret-123') == '<redacted>'
        and neomutt.mask_value('smtp_url', 'smtp://x') == 'smtp://x'
    adv_check(leaks, 'A2 credentials: values parsed but masked/redacted in every report')
end

do
    -- A3: folder-hook pointing at a missing account file reports cleanly.
    local missing = neomutt.load_account('account.foamedmap')
    local parse = neomutt.load_neomuttrc()
    local hook_ok = false
    if parse ~= nil then
        for _, hook in ipairs(parse.folder_hooks) do
            if hook.command:find('account.foamedmap', 1, true) ~= nil then
                hook_ok = true
            end
        end
    end
    adv_check(missing.ok == false and hook_ok, 'A3 missing account.foamedmap: load reports ok=false; hook still parsed')
end

do
    -- A4: bogus binaries give false + err, never a spawn.
    neomutt.setup({
        neomutt_bin = 'no-such-neomutt-xyz',
        notmuch_bin = 'no-such-notmuch-xyz',
        aerc_bin = 'no-such-aerc-xyz',
        account_dir = fixture_dir,
        neomuttrc = fixture_dir .. '/neomuttrc',
        msmtp_config = fixture_dir .. '/msmtp_config',
    })
    aerc.setup({ aerc_bin = 'no-such-aerc-xyz' })
    clear_log()
    local ok_open, err_open = neomutt.open()
    local ok_search, err_search = neomutt.search('tag:unread')
    local version, version_err = neomutt.neomutt_version()
    adv_check(
        ok_open == false
            and err_open ~= nil
            and ok_search == false
            and err_search ~= nil
            and version == nil
            and version_err ~= nil
            and read_log() == '',
        'A4 bogus binaries: open/search/version all fail closed; nothing spawned'
    )
end

do
    -- A5: blank search query spawns nothing.
    neomutt.setup(fixture_cfg)
    clear_log()
    local ok1, err1 = neomutt.search('')
    local ok2, err2 = neomutt.search('   ')
    adv_check(
        ok1 == false and ok2 == false and err1 ~= nil and err2 ~= nil and read_log() == '',
        'A5 blank query: search rejects empty/whitespace; fake log untouched'
    )
end

do
    -- A6: :AercGenerate Cancel writes nothing.
    local dir = '/tmp/email_aerc_cancel'
    os.execute('rm -rf ' .. dir)
    aerc.setup({
        account_dir = fixture_dir,
        msmtp_config = fixture_dir .. '/msmtp_config',
        aerc_dir = dir,
        select_impl = function(_, _, on_choice)
            on_choice(3) -- Cancel
        end,
    })
    vim.cmd('AercGenerate')
    adv_check(vim.fn.isdirectory(dir) ~= 1, 'A6 AercGenerate Cancel: output directory never created')
end

do
    -- A7: invalid output directory fails closed without a throw.
    local dir = '/dev/null/aerc_out'
    aerc.setup({
        account_dir = fixture_dir,
        msmtp_config = fixture_dir .. '/msmtp_config',
        aerc_dir = dir,
        select_impl = function(_, _, on_choice)
            on_choice(1) -- Write configs
        end,
    })
    local ok = pcall(vim.cmd, 'AercGenerate')
    close_floats()
    adv_check(ok, 'A7 AercGenerate into /dev/null: no throw; failure is a notify, not an error')
end

-- ======================= validation (7) =======================

do
    -- V1: valid neomuttrc parses: sets, binds, macros, hooks, sidebar.
    neomutt.setup(fixture_cfg)
    local parse, err = neomutt.load_neomuttrc()
    local bind_ok = false
    local macro_ok = false
    local hook_count = 0
    if parse ~= nil then
        for _, bind in ipairs(parse.binds) do
            if bind.menu == 'index' and bind.key == '\\ct' and bind.func == 'tag-prefix' then
                bind_ok = true
            end
        end
        for _, macro in ipairs(parse.macros) do
            if macro.menu == 'index' and macro.key == 'S' then
                macro_ok = true
            end
        end
        hook_count = #parse.folder_hooks
    end
    val_check(
        err == nil
            and parse ~= nil
            and parse.sets.sort == 'threads'
            and parse.sets.sidebar_width == '30'
            and parse.sets.editor == 'nvim'
            and #parse.sources == 1
            and bind_ok
            and macro_ok
            and hook_count == 3,
        'V1 valid rc: sets/bind/macro/sources/3 folder-hooks all parsed'
    )
end

do
    -- V2: account files parse; credential keys detected structurally.
    local accounts = neomutt.load_accounts()
    local qompass = nil
    local foamed = nil
    for _, account in ipairs(accounts) do
        if account.name == 'account.qompassai' then
            qompass = account
        end
        if account.name == 'account.foamedgmail' then
            foamed = account
        end
    end
    val_check(
        #accounts == 5
            and qompass ~= nil
            and qompass.ok
            and qompass.sets.from == 'map@qompass.ai'
            and qompass.sets.imap_user == 'map@qompass.ai'
            and neomutt.is_credential_key('imap_pass')
            and neomutt.is_credential_key('smtp_pass')
            and not neomutt.is_credential_key('from')
            and foamed ~= nil
            and foamed.ok
            and foamed.sets.folder ~= nil,
        'V2 accounts: 5 files load; identity parsed; pass keys detected as credentials'
    )
end

do
    -- V3: fake binary versions; date-version comparison is local and exact.
    local version, err = neomutt.neomutt_version()
    val_check(
        version == '20260616'
            and err == nil
            and neomutt.compare_date_versions('20260616', neomutt.NEOMUTT_VERSION_MIN) == 1
            and neomutt.compare_date_versions('20260616', '20260616') == 0
            and neomutt.compare_date_versions('bogus', '20260616') == nil,
        'V3 versions: fake neomutt reports 20260616; date compare 1/0/nil exactly'
    )
end

do
    -- V4: notmuch search builds the exact argv; results land in a float.
    clear_log()
    close_floats()
    local ok, err = neomutt.search('tag:unread')
    local logged = read_log()
    local float_ok = false
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_get_name(buf) == 'neomutt://search' then
            local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
            float_ok = lines[1] == '/tmp/mail/a' and lines[2] == '/tmp/mail/b'
        end
    end
    close_floats()
    val_check(
        ok and err == nil and logged == 'search --output=files --limit 50 tag:unread\n' and float_ok,
        'V4 search: exact notmuch argv; two fake files shown in the float'
    )
end

do
    -- V5: :AercGenerate writes the three files; accounts.conf is 0600.
    local dir = '/tmp/email_aerc_out'
    os.execute('rm -rf ' .. dir)
    aerc.setup({
        account_dir = fixture_dir,
        msmtp_config = fixture_dir .. '/msmtp_config',
        aerc_dir = dir,
        select_impl = function(_, _, on_choice)
            on_choice(1) -- Write configs
        end,
    })
    vim.cmd('AercGenerate')
    local function read(path)
        local f = io.open(path, 'r')
        if f == nil then
            return ''
        end
        local text = f:read('*a') or ''
        f:close()
        return text
    end
    local conf = read(dir .. '/aerc.conf')
    local accounts_text = read(dir .. '/accounts.conf')
    local binds = read(dir .. '/binds.conf')
    local perms = vim.fn.getfperm(dir .. '/accounts.conf')
    val_check(
        conf:find('sidebar-width = 32', 1, true) ~= nil
            and accounts_text:find('[qompassai]', 1, true) ~= nil
            and accounts_text:find('source = imaps://map%40qompass.ai@imap.qompass.ai:993', 1, true) ~= nil
            and accounts_text:find('exec:msmtp -a qompass', 1, true) ~= nil
            and accounts_text:find('exec:msmtp -a gmail-map26', 1, true) ~= nil
            and accounts_text:find('fake-secret-123', 1, true) == nil
            and binds:find('[global]', 1, true) ~= nil
            and perms == 'rw-------',
        'V5 generate: 3 files written; imaps+msmtp mapping exact; accounts.conf 0600; no secret leak'
    )
    os.execute('rm -rf ' .. dir)
end

do
    -- V6: Show diff only opens a float and writes nothing.
    local dir = '/tmp/email_aerc_diff'
    os.execute('rm -rf ' .. dir)
    aerc.setup({
        account_dir = fixture_dir,
        msmtp_config = fixture_dir .. '/msmtp_config',
        aerc_dir = dir,
        select_impl = function(_, _, on_choice)
            on_choice(2) -- Show diff only
        end,
    })
    close_floats()
    vim.cmd('AercGenerate')
    local float_ok = false
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_get_name(buf) == 'aerc://generate-diff' then
            float_ok = true
        end
    end
    close_floats()
    val_check(
        float_ok and vim.fn.isdirectory(dir) ~= 1,
        'V6 diff only: would-be configs shown in a float; nothing written'
    )
end

do
    -- V7: setup idempotent + commands registered; chooser persistence round-trips.
    neomutt.setup(fixture_cfg)
    neomutt.setup(fixture_cfg)
    aerc.setup({ aerc_bin = 'fake-aerc' })
    email.setup()
    local commands = vim.api.nvim_get_commands({})
    local expected = {
        'Neomutt',
        'NeomuttCompose',
        'NeomuttSearch',
        'NeomuttDocs',
        'NeomuttValidate',
        'NeomuttUpdateCheck',
        'Aerc',
        'AercCompose',
        'AercSearch',
        'AercDocs',
        'AercValidate',
        'AercUpdateCheck',
        'AercGenerate',
        'EmailClient',
    }
    local found = 0
    for _, name in ipairs(expected) do
        if commands[name] ~= nil then
            found = found + 1
        end
    end
    local keys = {}
    for key, _ in pairs(neomutt.default_config) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    local alpha_ok = keys[1] == 'account_dir' and keys[#keys] == 'update_repo_neomutt'
    local pristine = neomutt.default_config.neomutt_bin == 'neomutt'
        and neomutt.config.neomutt_bin == 'fake-neomutt'
        and neomutt.config ~= neomutt.default_config
    clients.setup({ choice_file_name = 'test_client_choice_tmp' })
    local save_ok, save_err = clients.save_choice('aerc')
    local read_back = clients.read_choice()
    local bad_ok, bad_err = clients.save_choice('bogus')
    local forget_ok = clients.forget_choice()
    local read_gone = clients.read_choice()
    val_check(
        found == 14
            and alpha_ok
            and pristine
            and save_ok
            and save_err == nil
            and read_back == 'aerc'
            and bad_ok == false
            and bad_err ~= nil
            and forget_ok
            and read_gone == nil,
        'V7: 14 commands idempotent; defaults alphabetical + pristine; choice save/read/forget round-trip'
    )
end

-- Restore the world: default configs, original PATH/env, fakes and
-- fixtures gone.
neomutt.setup()
aerc.setup()
clients.setup()
close_floats()
vim.env.PATH = saved_path
vim.env.EMAIL_FAKE_LOG = nil
os.execute('rm -rf ' .. fakebin)
os.execute('rm -rf ' .. fixture_dir)
os.remove(fake_log)

emit(string.format('adversarial: %d passed, %d failed', adv_passed, adv_failed))
emit(string.format('validation: %d passed, %d failed', val_passed, val_failed))
local f = io.open(report_path, 'w')
assert(f ~= nil, 'cannot open report path ' .. report_path)
f:write(table.concat(log_lines, '\n') .. '\n')
f:close()
os.exit((adv_failed == 0 and val_failed == 0) and 0 or 1)
