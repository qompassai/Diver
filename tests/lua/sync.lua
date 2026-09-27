-- tests/lua/sync.lua
-- Balanced suite for the sync module: exactly half adversarial and half
-- validation (7 checks each, 14 total). Run from the repo root with the
-- FULL config (never -u NONE, never --clean):
--   ~/workspace/tools/neovim-nightly/bin/nvim --headless -i NONE \
--     -u ~/workspace/repos/diver/init.lua -l tests/lua/sync.lua
-- Exit 0 when every check behaves, 1 otherwise. Report goes to
-- $SYNC_REPORT (default /tmp/sync_report.txt).
-- syncthing/tailscale are almost certainly absent on the test machine: a
-- fake `curl` on PATH answers the syncthing GUI endpoints from canned
-- fixtures, bogus binary names exercise the graceful "unavailable" paths,
-- and :PushToPhone uses a tmp sync_dir -- never the real ~/Sync. The fake
-- API key below is test-only and must never appear in notifications.
local report_path = os.getenv('SYNC_REPORT') or '/tmp/sync_report.txt'
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

local sync = require('sync')

local EXPECTED_COMMANDS = {
    'SyncStatus',
    'PushToPhone',
    'TailscaleStatus',
    'SyncDocs',
    'SyncValidate',
    'SyncUpdateCheck',
}

local FAKE_KEY = 'TESTKEY-NEVER-REAL-999'

local CONFIG_FIXTURE = [[
<configuration version="37">
    <folder id="default" label="Default Folder" path="/home/test/Sync" type="sendreceive">
    </folder>
    <gui enabled="true" tls="false">
        <address>0.0.0.0:18080</address>
        <apikey>]] .. FAKE_KEY .. [[</apikey>
    </gui>
</configuration>
]]

local COMPLETION_FIXTURE = '{"completion":99.9937565835,"globalBytes":156793013575,"needBytes":9789241,'
    .. '"globalItems":7823,"needItems":412,"needDeletes":0,"remoteState":"valid","sequence":12}'

local FOLDERS_FIXTURE = '[{"id":"default","label":"Default Folder","path":"/home/test/Sync"},'
    .. '{"id":"phone","label":"","path":""}]'

local STATUS_FIXTURE = '{"globalBytes":0,"needBytes":9789241,"pullErrors":2,"state":"syncing",'
    .. '"stateChanged":"2026-09-27T09:05:00Z","sequence":12}'

local SCANS_FIXTURE = '{"default":{"lastScan":"2026-09-27T09:00:00Z"}}'

-- Fake curl answering the syncthing GUI endpoints; the URL is the last argv
-- element. Header args are ignored (the key is asserted secret elsewhere).
local fakebin = '/tmp/sync_fakebin'
local saved_path = vim.env.PATH or ''
vim.env.PATH = fakebin .. ':' .. saved_path
local fixture_config = '/tmp/sync_test_config.xml'
local sync_tmpdir = '/tmp/sync_test_dir'
local function write_file(path, text)
    local f = io.open(path, 'w')
    assert(f ~= nil, 'cannot write ' .. path)
    f:write(text)
    f:close()
end
write_file(fixture_config, CONFIG_FIXTURE)
os.execute('mkdir -p ' .. fakebin)
write_file(fakebin .. '/curl', [[#!/bin/sh
url=""
for arg in "$@"; do url="$arg"; done
case "$url" in
  */rest/system/version) printf '%s' '{"version":"2.1.5","os":"linux","arch":"amd64"}' ;;
  */rest/config/folders) printf '%s' '[{"id":"default","label":"Default Folder","path":"/home/test/Sync"}]' ;;
  */rest/stats/folder) printf '%s' '{"default":{"lastScan":"2026-09-27T09:00:00Z"}}' ;;
  */rest/db/completion*) printf '%s' ']] .. COMPLETION_FIXTURE .. [[' ;;
  */rest/db/status*) printf '%s' ']] .. STATUS_FIXTURE .. [[' ;;
  *) printf '%s' '{"error":"unknown endpoint"}'; exit 1 ;;
esac
exit 0
]])
os.execute('chmod +x ' .. fakebin .. '/curl')
os.execute('mkdir -p ' .. sync_tmpdir)

local function chooser(choice)
    return function(_items, _opts, on_choice)
        on_choice(choice)
    end
end

local function base_setup(overrides)
    local base = {
        syncthing_config_path = fixture_config,
        sync_dir = sync_tmpdir,
        tailscale_bin = 'definitely-not-tailscale-xyz',
    }
    if overrides ~= nil then
        for key, value in pairs(overrides) do
            base[key] = value
        end
    end
    sync.setup(base)
end

-- Validation ------------------------------------------------------------
do
    -- setup() already ran at boot (init.lua requires sync eagerly);
    -- it must be idempotent and leave exactly the 6 commands.
    base_setup()
    sync.setup()
    local commands = vim.api.nvim_get_commands({})
    local count = 0
    local all_present = true
    for _, name in ipairs(EXPECTED_COMMANDS) do
        if commands[name] ~= nil then
            count = count + 1
        else
            all_present = false
        end
    end
    val_check(
        all_present and count == 6,
        'setup registers :SyncStatus :PushToPhone :TailscaleStatus :SyncDocs :SyncValidate :SyncUpdateCheck; '
            .. 'idempotent, still exactly 6'
    )
end

do
    local explicit = true
    for key, _ in pairs(sync.default_config) do
        if sync.config[key] == nil then
            explicit = false
        end
    end
    base_setup({ float_width = 80 })
    local override_ok = sync.config.float_width == 80
    base_setup()
    local restored = sync.config.float_width == 100
    local defaults_intact = sync.default_config.float_width == 100 and sync.default_config.confirm_push == true
    local facts_ok = sync.config.docs_url == 'https://docs.syncthing.net/rest/db-completion-get.html'
        and sync.config.tailscale_docs_url == 'https://tailscale.com/kb/1080/cli'
        and sync.config.update_repo_syncthing == 'syncthing/syncthing'
        and sync.config.update_repo_tailscale == 'tailscale/tailscale'
        and sync.config.known_upstream_version_syncthing == '2.1.5'
        and sync.config.known_upstream_version_tailscale == '1.102.4'
        and sync.config.syncthing_version_min == '1.27.0'
        and sync.config.tailscale_version_min == '1.80.0'
        and sync.config.api_key_header == 'X-API-Key'
        and sync.config.completion_endpoint == '/rest/db/completion'
        and sync.default_config.sync_dir == '~/Sync'
    val_check(
        explicit and override_ok and restored and defaults_intact and facts_ok,
        'config fully explicit; overrides apply, nil restores, default_config never mutated; '
            .. 'verified facts: docs URLs, syncthing/syncthing + tailscale/tailscale, '
            .. '2.1.5 / 1.102.4 known upstream, min versions, X-API-Key, completion endpoint'
    )
end

do
    base_setup()
    local settings, settings_err = sync.read_gui_settings()
    local base_url = sync.gui_base_url(settings ~= nil and settings.address or nil)
    val_check(
        settings_err == nil
            and settings ~= nil
            and settings.address == '0.0.0.0:18080'
            and settings.api_key == FAKE_KEY
            and base_url == 'http://127.0.0.1:18080'
            and sync.gui_base_url(nil) == 'http://127.0.0.1:8384'
            and sync.gui_base_url('not-an-address') == nil
            and sync.gui_base_url('127.0.0.1:8384') == 'http://127.0.0.1:8384',
        'read_gui_settings extracts address + API key from the live config.xml shape; '
            .. 'gui_base_url maps 0.0.0.0 -> 127.0.0.1, nil -> upstream default, garbage -> nil'
    )
end

do
    local comp, comp_err = sync.parse_completion(COMPLETION_FIXTURE)
    local folders, folders_err = sync.parse_folders(FOLDERS_FIXTURE)
    local st, st_err = sync.parse_folder_status(STATUS_FIXTURE)
    local scans, scans_err = sync.parse_last_scans(SCANS_FIXTURE)
    val_check(
        comp_err == nil
            and comp ~= nil
            and math.abs(comp.completion_pct - 99.9937565835) < 1e-9
            and comp.need_bytes == 9789241
            and comp.state == 'valid'
            and folders_err == nil
            and folders ~= nil
            and #folders == 2
            and folders[1].id == 'default'
            and folders[1].label == 'Default Folder'
            and folders[1].path == '/home/test/Sync'
            and folders[2].id == 'phone'
            and folders[2].label == ''
            and st_err == nil
            and st ~= nil
            and st.state == 'syncing'
            and st.state_changed == '2026-09-27T09:05:00Z'
            and st.pull_errors == 2
            and st.need_bytes == 9789241
            and scans_err == nil
            and scans ~= nil
            and scans['default'] == '2026-09-27T09:00:00Z'
            and sync.format_bytes(9789241) == '9.34 MB'
            and sync.format_bytes(512) == '512 B'
            and sync.format_bytes(0) == '0 B',
        'pure parsers on verified REST fixtures: completion pct/need/state, folders id/label/path, '
            .. 'db status state/changed/pull-errors/need, stats lastScan map, format_bytes units'
    )
end

do
    -- Fake-curl end-to-end: folder list, per-folder completion/status/last
    -- scan, and the :SyncStatus float itself.
    base_setup()
    local settings = sync.read_gui_settings()
    assert(settings ~= nil, 'fixture GUI settings must parse')
    local folders, folders_err = sync.folders(settings)
    local lines, lines_err = sync.status_lines(settings)
    local text = lines ~= nil and table.concat(lines, '\n') or ''
    sync.cmd_status({})
    local float_ok = false
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_get_name(buf) == 'syncthing://sync status' then
            local buf_text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
            float_ok = buf_text:find('default', 1, true) ~= nil and buf_text:find('99.99% complete', 1, true) ~= nil
        end
    end
    val_check(
        folders_err == nil
            and folders ~= nil
            and #folders == 1
            and folders[1].id == 'default'
            and lines_err == nil
            and text:find('reachable (v2.1.5)', 1, true) ~= nil
            and text:find('99.99% complete', 1, true) ~= nil
            and text:find('need 9.34 MB', 1, true) ~= nil
            and text:find('state=syncing', 1, true) ~= nil
            and text:find('pull errors=2', 1, true) ~= nil
            and text:find('last scan 2026-09-27T09:00:00Z', 1, true) ~= nil
            and float_ok,
        'fake curl end-to-end: folders() lists default; status_lines shows reachable v2.1.5, '
            .. '99.99% complete, need 9.34 MB, state=syncing, pull errors=2, last scan; '
            .. ':SyncStatus opens a float with the folder line'
    )
end

do
    -- PushToPhone happy path: a modified buffer is saved first, then copied
    -- with fs_copyfile; bytes reported, content identical. :write itself is
    -- stubbed with a faithful simulation (persist lines, clear modified)
    -- because a real message-producing :write kills headless nvim under the
    -- full config (pre-existing, unrelated to this module); the stub asserts
    -- the module issues exactly `silent! write`. The buffer is built via the
    -- API because :edit also kills headless nvim here.
    local src_path = '/tmp/sync_push_src.txt'
    write_file(src_path, 'stale content\n')
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_buf_set_name(buf, src_path)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'hello phone', 'modified line' })
    assert(vim.bo[buf].modified, 'test buffer should start modified')
    base_setup({ select_impl = chooser(1) })
    local write_cmd_seen = nil
    local real_cmd = vim.cmd
    vim.cmd = function(cmd)
        write_cmd_seen = cmd
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local f = assert(io.open(src_path, 'w'))
        f:write(table.concat(lines, '\n') .. '\n')
        f:close()
        vim.bo[buf].modified = false
    end
    local info, err = 'pending', 'pending'
    local push_ok = pcall(sync.push_current_buffer, function(cb_info, cb_err)
        info, err = cb_info, cb_err
    end)
    vim.cmd = real_cmd
    local dest_path = sync_tmpdir .. '/sync_push_src.txt'
    local function read_all(path)
        local f = io.open(path, 'r')
        if f == nil then
            return nil
        end
        local text = f:read('*a')
        f:close()
        return text
    end
    local dest_text = read_all(dest_path)
    local src_text = read_all(src_path)
    val_check(
        push_ok
            and write_cmd_seen == 'silent! write'
            and err == nil
            and info ~= nil
            and info.bytes == #(dest_text or '')
            and dest_text ~= nil
            and dest_text == src_text
            and dest_text:find('modified line', 1, true) ~= nil
            and info.dest == dest_path
            and vim.bo[buf].modified == false,
        'PushToPhone: confirm accepted -> buffer saved via `silent! write`, file copied into tmp sync_dir, '
            .. 'bytes reported match, contents identical (modified line present), buffer no longer modified'
    )
end

do
    -- syncthing + tailscale absent: graceful unavailable paths, never errors.
    base_setup({ syncthing_bin = 'definitely-not-syncthing-xyz' })
    local output, ts_err = sync.tailscale_status()
    local checks = sync.checks()
    local by_name = {}
    local vocab_ok = true
    for _, check in ipairs(checks) do
        by_name[check.name] = check.status
        if check.status ~= 'ok' and check.status ~= 'below minimum' and check.status ~= 'unavailable' then
            vocab_ok = false
        end
    end
    val_check(
        output == nil
            and type(ts_err) == 'string'
            and ts_err:find('not found on PATH', 1, true) ~= nil
            and by_name['definitely-not-syncthing-xyz'] == 'unavailable'
            and by_name['definitely-not-tailscale-xyz'] == 'unavailable'
            and by_name['gui config'] == 'ok'
            and vocab_ok,
        'missing binaries: tailscale_status returns nil + not-found message; '
            .. 'checks() reports both binaries unavailable while gui config stays ok; '
            .. 'statuses in the check vocabulary'
    )
end

-- Adversarial -----------------------------------------------------------
do
    local cases = { nil, 123, true, {} }
    local all_ok = true
    for _, bad in ipairs(cases) do
        local ok, comp, err = pcall(sync.parse_completion, bad)
        if not (ok and comp == nil and type(err) == 'string') then
            all_ok = false
        end
    end
    adv_check(all_ok, 'parse_completion(nil/123/true/{}) returns nil+err, never throws')
end

do
    local comp1, err1 = sync.parse_completion('{"completion":99.9,"needBytes":')
    local comp2, err2 = sync.parse_completion('{"error":"folder not found"}')
    adv_check(
        comp1 == nil
            and type(err1) == 'string'
            and comp2 == nil
            and type(err2) == 'string'
            and err2:find('syncthing error', 1, true) ~= nil
            and err2:find('folder not found', 1, true) ~= nil,
        'truncated JSON refused with nil+err; syncthing {"error":...} shapes surface as nil+err naming the error'
    )
end

do
    local big = string.rep('x', sync.default_config.parse_line_max + 1)
    local ok, comp, err = pcall(sync.parse_completion, big)
    adv_check(
        ok and comp == nil and type(err) == 'string' and err:find('parse_line_max', 1, true) ~= nil,
        'oversized input refused with nil+err naming parse_line_max, never scanned unbounded'
    )
end

do
    base_setup()
    local missing, missing_err = (function()
        sync.setup({ syncthing_config_path = '/tmp/sync_no_such_config_xyz.xml' })
        local s, e = sync.read_gui_settings()
        base_setup()
        return s, e
    end)()
    write_file('/tmp/sync_nogui.xml', '<configuration version="37"></configuration>')
    write_file('/tmp/sync_nokey.xml', '<configuration><gui><address>127.0.0.1:8384</address></gui></configuration>')
    sync.setup({ syncthing_config_path = '/tmp/sync_nogui.xml' })
    local nogui, nogui_err = sync.read_gui_settings()
    sync.setup({ syncthing_config_path = '/tmp/sync_nokey.xml' })
    local nokey, nokey_err = sync.read_gui_settings()
    base_setup()
    adv_check(
        missing == nil
            and type(missing_err) == 'string'
            and nogui == nil
            and type(nogui_err) == 'string'
            and nogui_err:find('no <gui>', 1, true) ~= nil
            and nokey == nil
            and type(nokey_err) == 'string'
            and nokey_err:find('API key', 1, true) ~= nil
            and nokey_err:find(FAKE_KEY, 1, true) == nil
            and sync.gui_base_url('no-port-here') == nil,
        'missing config file / no <gui> block / no <apikey> all return nil+err, never throw; '
            .. 'key-absence message reports presence only, never a value; bad address -> nil'
    )
end

adv_check(
    not pcall(sync.setup, 'nope')
        and not pcall(sync.setup, { float_width = 'wide' })
        and not pcall(sync.setup, { confirm_push = 42 })
        and not pcall(sync.setup, { select_impl = 'x' })
        and not pcall(sync.setup, { sync_dir = '   ' })
        and not pcall(sync.push_current_buffer, 'nope'),
    'setup() rejects a non-table config, a mistyped float_width, a non-boolean confirm_push, '
        .. 'a non-function select_impl, and a blank sync_dir; push_current_buffer rejects a non-function callback'
)

do
    -- PushToPhone adversarial: unnamed buffer, missing sync_dir, Cancel, and
    -- a failed :write. Buffers are built via the API (:enew/:edit kill
    -- headless nvim under the full config, pre-existing). The :write failure
    -- is injected by stubbing vim.cmd because a real failing :write also
    -- kills headless nvim; the stub exercises exactly the module's
    -- pcall-abort branch and is restored immediately.
    base_setup()
    local scratch = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_set_current_buf(scratch)
    local info1, err1 = 'pending', 'pending'
    sync.push_current_buffer(function(cb_info, cb_err)
        info1, err1 = cb_info, cb_err
    end)
    local src2 = '/tmp/sync_push_src2.txt'
    local buf2 = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_set_current_buf(buf2)
    vim.api.nvim_buf_set_name(buf2, src2)
    vim.api.nvim_buf_set_lines(buf2, 0, -1, false, { 'second file' })
    base_setup({ sync_dir = '/tmp/sync_no_such_dir_xyz', select_impl = chooser(1) })
    local info2, err2 = 'pending', 'pending'
    sync.push_current_buffer(function(cb_info, cb_err)
        info2, err2 = cb_info, cb_err
    end)
    base_setup({ select_impl = chooser(2) })
    local dest3 = sync_tmpdir .. '/sync_push_src2.txt'
    os.remove(dest3)
    local info3, err3 = 'pending', 'pending'
    sync.push_current_buffer(function(cb_info, cb_err)
        info3, err3 = cb_info, cb_err
    end)
    local dest3_missing = vim.uv.fs_stat(dest3) == nil
    local buf4 = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_set_current_buf(buf4)
    vim.api.nvim_buf_set_name(buf4, '/tmp/sync_push_src4.txt')
    vim.api.nvim_buf_set_lines(buf4, 0, -1, false, { 'unsavable' })
    base_setup({ select_impl = chooser(1) })
    local real_cmd = vim.cmd
    vim.cmd = function()
        error('injected write failure')
    end
    local info4, err4 = 'pending', 'pending'
    local push_ok = pcall(sync.push_current_buffer, function(cb_info, cb_err)
        info4, err4 = cb_info, cb_err
    end)
    vim.cmd = real_cmd
    adv_check(
        info1 == nil
            and type(err1) == 'string'
            and err1:find('file-backed', 1, true) ~= nil
            and info2 == nil
            and type(err2) == 'string'
            and err2:find('not a directory', 1, true) ~= nil
            and info3 == nil
            and err3 == nil
            and dest3_missing
            and push_ok
            and info4 == nil
            and type(err4) == 'string'
            and err4:find(':write', 1, true) ~= nil
            and vim.uv.fs_stat(sync_tmpdir .. '/sync_push_src4.txt') == nil,
        'unnamed buffer refused; missing sync_dir refused before any write; '
            .. 'cancel at confirm copies nothing and reports no error; '
            .. 'a failed :write aborts the push without throwing and copies nothing'
    )
end

do
    -- The API key must never appear in notifications or error strings.
    base_setup()
    local captured = {}
    local orig_notify = vim.notify
    vim.notify = function(msg, ...)
        captured[#captured + 1] = tostring(msg)
        return orig_notify(msg, ...)
    end
    local checks = sync.checks()
    sync.cmd_validate({})
    local settings, settings_err = sync.read_gui_settings()
    assert(settings ~= nil, 'fixture GUI settings must parse')
    local lines, lines_err = sync.status_lines(settings)
    assert(lines_err == nil and lines ~= nil, 'status_lines must succeed against fake curl')
    vim.notify = orig_notify
    local blob = table.concat(captured, '\n')
    local key_leaked = blob:find(FAKE_KEY, 1, true) ~= nil
    adv_check(
        not key_leaked and #checks == 5 and tostring(settings_err) == 'nil',
        'API key appears in no vim.notify and no check detail across checks(), '
            .. ':SyncValidate, and status_lines; checks() returns 5 checks'
    )
end

-- Restore the world: default config, original PATH, tmp files gone.
base_setup()
sync.setup()
vim.env.PATH = saved_path
os.remove(fixture_config)
os.remove('/tmp/sync_nogui.xml')
os.remove('/tmp/sync_nokey.xml')
os.remove(fakebin .. '/curl')
os.remove('/tmp/sync_push_src.txt')
os.remove('/tmp/sync_push_src2.txt')
os.remove(sync_tmpdir .. '/sync_push_src.txt')
os.execute('rmdir ' .. sync_tmpdir .. ' 2>/dev/null')
os.execute('rmdir ' .. fakebin .. ' 2>/dev/null')

emit(string.format('adversarial: %d passed, %d failed', adv_passed, adv_failed))
emit(string.format('validation: %d passed, %d failed', val_passed, val_failed))
local f = io.open(report_path, 'w')
assert(f ~= nil, 'cannot open report path ' .. report_path)
f:write(table.concat(log_lines, '\n') .. '\n')
f:close()
os.exit((adv_failed == 0 and val_failed == 0) and 0 or 1)
