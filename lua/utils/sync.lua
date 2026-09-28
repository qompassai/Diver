-- #################################################################
-- /qompassai/diver/lua/sync/init.lua
-- Qompass AI Diver Sync -- Syncthing + Tailscale phone surface
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
--- Phone/sync surface: Syncthing GUI status over the local REST API and a
--- confirmation-gated push of the current buffer into the Sync dir, plus a
--- read-only `tailscale status` view.
---
--- The GUI listen address and API key are read at runtime from the user's
--- live syncthing config.xml (his dotfiles: ~/.config/syncthing/config.xml,
--- <gui><address> + <apikey>); the key is never hardcoded, never logged,
--- and never shown in notifications -- it travels only as a single
--- `X-API-Key: <key>` argv element to a bounded curl via
--- security.rce.safe_exec. Every subprocess is argv form, never a shell
--- string. The only write op is :PushToPhone; everything else is read-only.
---
--- REST shapes verified 2026-09-27: /rest/db/completion, /rest/db/status,
--- /rest/stats/folder (lastScan) at docs.syncthing.net; /rest/config/folders
--- verified in the v2.1.5 source (lib/api/api.go) -- the docs lag the code.
--- Requiring this module performs no I/O and registers nothing. M.setup()
--- registers the :Sync* commands and is idempotent.

---@module 'utils.sync'

local api = vim.api
local fn = vim.fn
local uv = vim.uv

local M = {}

local rce = require('security.rce')
local toolmgr = require('utils.toolmgr')

local API_KEY_ELEMENT_MAX = 256 -- longest <apikey> text accepted from config.xml.
local CONFIG_FILE_BYTES_MAX = 1048576 -- 1 MiB cap on the syncthing config.xml read.
local FOLDERS_MAX = 256 -- cap on folders kept from /rest/config/folders.
local OUTPUT_LINES_MAX = 400 -- cap on float window lines.
local STATUS_BYTES_MAX = 262144 -- 256 KiB cap on `tailscale status` output.

local MIGRATIONS_TEMPLATE_NOTE = '[template] no syncthing/tailscale config rename verified upstream; shape only, no-op'

---@type utils.toolmgr.Migration[]
local MIGRATIONS = {
    {
        version = '2.1.5',
        description = MIGRATIONS_TEMPLATE_NOTE,
        apply = function()
            return true, 'template migration: no changes applied'
        end,
    },
}

--- Factory defaults: explicit, alphabetical, one-line comment per key.
--- Never mutated; M.config is rebuilt from this on every setup().
M.default_config = {
    -- HTTP header carrying the GUI API key on every local REST call
    -- (syncthing REST auth; the key itself is read from config.xml).
    api_key_header = 'X-API-Key',
    -- REST path for per-folder completion (docs.syncthing.net, verified 2026-09-27).
    completion_endpoint = '/rest/db/completion',
    -- PushToPhone confirms via vim.ui.select before writing/copying.
    -- False skips the dialog; default true.
    confirm_push = true,
    -- Cap on one curl response body; --max-filesize enforces it.
    curl_max_bytes = 262144,
    -- Wall-clock seconds for one curl probe.
    curl_timeout_s = 10,
    -- Canonical Syncthing REST API docs (verified 2026-09-27: 200 OK).
    docs_url = 'https://docs.syncthing.net/rest/db-completion-get.html',
    -- Rows of the floating status windows.
    float_height = 20,
    -- Cols of the floating status windows.
    float_width = 100,
    -- REST path listing configured folders (verified in the v2.1.5 source,
    -- lib/api/api.go: registerFolders("/rest/config/folders"); docs lag).
    folders_endpoint = '/rest/config/folders',
    -- Fallback GUI listen address when config.xml has none; the live value
    -- comes from config.xml (his dotfiles use 0.0.0.0:8080). Upstream
    -- default shown here.
    gui_address_default = '127.0.0.1:8384',
    -- Newest syncthing release verified at build time (v2.1.5, 2026-09-08;
    -- GitHub API, syncthing/syncthing).
    known_upstream_version_syncthing = '2.1.5',
    -- Newest tailscale release verified at build time (v1.102.4, 2026-09-10;
    -- GitHub API, tailscale/tailscale).
    known_upstream_version_tailscale = '1.102.4',
    -- REST path for per-folder stats incl. lastScan (docs.syncthing.net,
    -- verified 2026-09-27).
    last_scan_endpoint = '/rest/stats/folder',
    -- Bytes of REST JSON handed to the pure parsers; larger input is refused
    -- with nil+err rather than scanned unbounded.
    parse_line_max = 1048576,
    -- Test seam for vim.ui.select (PushToPhone confirm, update dialogs).
    select_impl = nil,
    -- REST path for folder state / pull errors (docs.syncthing.net,
    -- verified 2026-09-27).
    status_endpoint = '/rest/db/status',
    -- Destination dir for :PushToPhone (his syncthing folder path).
    sync_dir = '~/Sync',
    -- Syncthing binary name on PATH.
    syncthing_bin = 'syncthing',
    -- Syncthing GUI config; the GUI address + API key are read live from it.
    syncthing_config_path = '~/.config/syncthing/config.xml',
    -- Minimum syncthing: /rest/config/folders needs 1.19+; 1.27.0 is the
    -- last v1 line and a sane floor.
    syncthing_version_min = '1.27.0',
    -- Tailscale binary name on PATH.
    tailscale_bin = 'tailscale',
    -- Canonical Tailscale CLI reference incl. `status`
    -- (tailscale.com/kb/1080/cli, verified 2026-09-27).
    tailscale_docs_url = 'https://tailscale.com/kb/1080/cli',
    -- Minimum tailscale: the `status` CLI shape predates this by years;
    -- 1.80.0 is a conservative floor.
    tailscale_version_min = '1.80.0',
    -- Wall-clock cap for one-shot subprocess probes.
    timeout_ms = 30000,
    -- System package name for the syncthing updater.
    update_package_syncthing = 'syncthing',
    -- System package name for the tailscale updater.
    update_package_tailscale = 'tailscale',
    -- Canonical GitHub repo whose releases track syncthing (verified 2026-09-27).
    update_repo_syncthing = 'syncthing/syncthing',
    -- Canonical GitHub repo whose releases track tailscale (verified 2026-09-27).
    update_repo_tailscale = 'tailscale/tailscale',
    -- REST path for the reachability/version probe (docs.syncthing.net,
    -- verified 2026-09-27).
    version_endpoint = '/rest/system/version',
}

--- Live config, rebuilt by every setup() call. Never mutated in place.
---@type table
M.config = vim.deepcopy(M.default_config)

---@class sync.GuiSettings Live GUI connection details from config.xml.
---@field address string Listen address as written, e.g. '0.0.0.0:8080'.
---@field api_key string API key. Local-only: never logged, never notified.

---@class sync.Completion Parsed /rest/db/completion payload.
---@field completion_pct number 0..100.
---@field need_bytes integer Bytes still needed.
---@field state string Endpoint remoteState; 'unknown' when absent.

---@class sync.Folder One entry from /rest/config/folders.
---@field id string Folder id, e.g. 'default'.
---@field label string Display label, '' when absent.
---@field path string Local path, '' when absent.

---@class sync.FolderStatus Parsed /rest/db/status payload.
---@field state string Folder state, e.g. 'idle'.
---@field state_changed string RFC3339 state-change time, '' when absent.
---@field pull_errors integer Failed files in the last sync, 0 when absent.
---@field need_bytes integer Bytes needed, 0 when absent.

---@class sync.Check
---@field name string
---@field status string 'ok' | 'below minimum' | 'unavailable'
---@field detail string One-line human summary; never carries the API key.

--- Type-check one config option. Programmer errors raise; expected
--- absences stay nil.
---@param name string Option name for the error message.
---@param value any Value to check.
---@param expected string Expected type() string.
local function check_type(name, value, expected)
    if type(value) ~= expected then
        error(('sync: option %s must be %s, got %s'):format(name, expected, type(value)), 2)
    end
end

--- Build the live config: factory defaults deep-copied, overrides merged,
--- every key type-checked. Never mutates M.default_config.
---@param config table|nil Overrides; nil restores factory defaults.
---@return table merged Live config table.
function M.setup_config(config)
    if config ~= nil and type(config) ~= 'table' then
        error(('sync: setup expects a table or nil, got %s'):format(type(config)), 2)
    end
    local merged = vim.tbl_deep_extend('force', vim.deepcopy(M.default_config), config or {})
    check_type('api_key_header', merged.api_key_header, 'string')
    check_type('completion_endpoint', merged.completion_endpoint, 'string')
    check_type('confirm_push', merged.confirm_push, 'boolean')
    check_type('curl_max_bytes', merged.curl_max_bytes, 'number')
    check_type('curl_timeout_s', merged.curl_timeout_s, 'number')
    check_type('docs_url', merged.docs_url, 'string')
    check_type('float_height', merged.float_height, 'number')
    check_type('float_width', merged.float_width, 'number')
    check_type('folders_endpoint', merged.folders_endpoint, 'string')
    check_type('gui_address_default', merged.gui_address_default, 'string')
    check_type('known_upstream_version_syncthing', merged.known_upstream_version_syncthing, 'string')
    check_type('known_upstream_version_tailscale', merged.known_upstream_version_tailscale, 'string')
    check_type('last_scan_endpoint', merged.last_scan_endpoint, 'string')
    check_type('parse_line_max', merged.parse_line_max, 'number')
    check_type('status_endpoint', merged.status_endpoint, 'string')
    check_type('sync_dir', merged.sync_dir, 'string')
    check_type('syncthing_bin', merged.syncthing_bin, 'string')
    check_type('syncthing_config_path', merged.syncthing_config_path, 'string')
    check_type('syncthing_version_min', merged.syncthing_version_min, 'string')
    check_type('tailscale_bin', merged.tailscale_bin, 'string')
    check_type('tailscale_docs_url', merged.tailscale_docs_url, 'string')
    check_type('tailscale_version_min', merged.tailscale_version_min, 'string')
    check_type('timeout_ms', merged.timeout_ms, 'number')
    check_type('update_package_syncthing', merged.update_package_syncthing, 'string')
    check_type('update_package_tailscale', merged.update_package_tailscale, 'string')
    check_type('update_repo_syncthing', merged.update_repo_syncthing, 'string')
    check_type('update_repo_tailscale', merged.update_repo_tailscale, 'string')
    check_type('version_endpoint', merged.version_endpoint, 'string')
    if merged.select_impl ~= nil and type(merged.select_impl) ~= 'function' then
        error('sync: option select_impl must be a function or nil', 2)
    end
    if merged.sync_dir:match('^%s*$') then
        error('sync: sync_dir must be a non-empty path', 2)
    end
    return merged
end

--- Read the GUI address + API key from the user's live syncthing
--- config.xml. Never throws; every expected failure returns nil+err, and no
--- error string ever carries the key.
---@return sync.GuiSettings|nil settings
---@return string|nil err
function M.read_gui_settings()
    local path = fn.expand(M.config.syncthing_config_path)
    local stat = uv.fs_stat(path)
    if stat == nil or stat.type ~= 'file' or (stat.size or 0) > CONFIG_FILE_BYTES_MAX then
        return nil, 'syncthing config not readable: ' .. path
    end
    local fh, open_err = io.open(path, 'r')
    if fh == nil then
        return nil, 'syncthing config not readable: ' .. path .. ' (' .. tostring(open_err) .. ')'
    end
    local text = fh:read('*a') or ''
    fh:close()
    local gui_block = text:match('<gui[^>]*>(.-)</gui>')
    if gui_block == nil then
        return nil, 'no <gui> block in ' .. path
    end
    local address = gui_block:match('<address>([^<]*)</address>')
    local api_key = gui_block:match('<apikey>([^<]*)</apikey>')
    if address == nil or address:match('^%s*$') then
        return nil, 'no GUI <address> in ' .. path
    end
    if api_key == nil or #api_key == 0 or #api_key > API_KEY_ELEMENT_MAX then
        return nil, 'no GUI API key in ' .. path .. ' (presence reported, value never shown)'
    end
    return { address = address, api_key = api_key }, nil
end

--- Map a config.xml GUI address to a local probe base URL. A wildcard or
--- empty host becomes 127.0.0.1 (we always probe locally); the port is
--- kept. Pure; unparseable input returns nil.
---@param address string|nil e.g. '0.0.0.0:8080'; nil/'' falls back to gui_address_default.
---@return string|nil url e.g. 'http://127.0.0.1:8080'.
function M.gui_base_url(address)
    local raw = address
    if raw == nil or raw:match('^%s*$') then
        raw = M.config.gui_address_default
    end
    local host, port = raw:match('^%s*([^:]+):(%d+)%s*$')
    if host == nil or port == nil then
        return nil
    end
    if host == '0.0.0.0' or host == '' then
        host = '127.0.0.1'
    end
    return 'http://' .. host .. ':' .. port
end

--- Percent-encode a folder id for a query string. Bounded by the id length.
---@param text string
---@return string encoded
local function url_encode(text)
    return (text:gsub('[^%w%-%._~]', function(char)
        return ('%%%02X'):format(char:byte())
    end))
end

--- Bounded curl GET against the local GUI API, argv form only. The
--- `X-API-Key` header travels as one argv element -- never through a shell,
--- never logged. Returns nil+err when curl is missing, the address is
--- unparseable, or the probe fails; error strings never carry the key.
---@param settings sync.GuiSettings
---@param path string REST path starting with '/', e.g. '/rest/db/completion?folder=default'.
---@return string|nil body
---@return string|nil err
function M.api_get(settings, path)
    if type(path) ~= 'string' or path == '' or path:sub(1, 1) ~= '/' then
        return nil, 'api_get needs a REST path starting with /, got ' .. tostring(path)
    end
    if not toolmgr.binary_present('curl') then
        return nil, 'curl binary not found on PATH'
    end
    local base = M.gui_base_url(settings.address)
    if base == nil then
        return nil, 'cannot parse GUI address ' .. tostring(settings.address)
    end
    local argv = {
        'curl',
        '-sS',
        '--max-time',
        tostring(M.config.curl_timeout_s),
        '--max-filesize',
        tostring(M.config.curl_max_bytes),
        '-H',
        M.config.api_key_header .. ': ' .. settings.api_key,
        base .. path,
    }
    local result, exec_err = rce.safe_exec(argv, { timeout_ms = M.config.curl_timeout_s * 1000 + 5000 })
    if exec_err ~= nil then
        return nil, 'curl probe failed: ' .. exec_err
    end
    assert(result ~= nil, 'safe_exec returned no error but no result')
    if result.code ~= 0 then
        return nil, 'curl exited ' .. result.code .. ': ' .. (result.stderr or ''):sub(1, 200)
    end
    return (result.stdout or ''):sub(1, M.config.curl_max_bytes), nil
end

--- Parse /rest/db/completion JSON into { completion_pct, need_bytes,
--- state }. Pure and bounded: input past parse_line_max is refused, and
--- every failure mode returns nil+err instead of throwing. `state` is the
--- endpoint's remoteState ('unknown' when the endpoint omits it, which it
--- does for local/aggregated queries).
---@param text string Raw endpoint body.
---@return sync.Completion|nil completion
---@return string|nil err
function M.parse_completion(text)
    if type(text) ~= 'string' then
        return nil, 'parse_completion expects a string, got ' .. type(text)
    end
    if #text > M.config.parse_line_max then
        return nil, ('input %d bytes exceeds parse_line_max %d'):format(#text, M.config.parse_line_max)
    end
    local ok, decoded = pcall(vim.json.decode, text)
    if not ok or type(decoded) ~= 'table' then
        return nil, 'parse_completion: not JSON (' .. text:sub(1, 80) .. ')'
    end
    if type(decoded.error) == 'string' then
        return nil, 'parse_completion: syncthing error: ' .. decoded.error:sub(1, 120)
    end
    local completion = decoded.completion
    local need_bytes = decoded.needBytes
    if type(completion) ~= 'number' or type(need_bytes) ~= 'number' then
        return nil, 'parse_completion: missing numeric completion/needBytes'
    end
    local state = decoded.remoteState
    if type(state) ~= 'string' or state == '' then
        state = 'unknown'
    end
    return { completion_pct = completion, need_bytes = math.floor(need_bytes), state = state }, nil
end

--- Parse /rest/config/folders JSON into folder records. Pure and bounded:
--- at most FOLDERS_MAX folders are kept, entries without a string id are
--- skipped, and failures return nil+err.
---@param text string Raw endpoint body.
---@return sync.Folder[]|nil folders
---@return string|nil err
function M.parse_folders(text)
    if type(text) ~= 'string' then
        return nil, 'parse_folders expects a string, got ' .. type(text)
    end
    if #text > M.config.parse_line_max then
        return nil, ('input %d bytes exceeds parse_line_max %d'):format(#text, M.config.parse_line_max)
    end
    local ok, decoded = pcall(vim.json.decode, text)
    if not ok or type(decoded) ~= 'table' then
        return nil, 'parse_folders: not JSON (' .. text:sub(1, 80) .. ')'
    end
    ---@type sync.Folder[]
    local folders = {}
    for _, entry in ipairs(decoded) do
        if #folders >= FOLDERS_MAX then
            break
        end
        if type(entry) == 'table' and type(entry.id) == 'string' and entry.id ~= '' then
            local label = entry.label
            local path = entry.path
            folders[#folders + 1] = {
                id = entry.id,
                label = type(label) == 'string' and label or '',
                path = type(path) == 'string' and path or '',
            }
        end
    end
    return folders, nil
end

--- Parse /rest/db/status JSON into { state, state_changed, pull_errors,
--- need_bytes }. Pure and bounded; absent fields degrade to ''/0, a missing
--- state refuses with nil+err.
---@param text string Raw endpoint body.
---@return sync.FolderStatus|nil status
---@return string|nil err
function M.parse_folder_status(text)
    if type(text) ~= 'string' then
        return nil, 'parse_folder_status expects a string, got ' .. type(text)
    end
    if #text > M.config.parse_line_max then
        return nil, ('input %d bytes exceeds parse_line_max %d'):format(#text, M.config.parse_line_max)
    end
    local ok, decoded = pcall(vim.json.decode, text)
    if not ok or type(decoded) ~= 'table' then
        return nil, 'parse_folder_status: not JSON (' .. text:sub(1, 80) .. ')'
    end
    if type(decoded.state) ~= 'string' or decoded.state == '' then
        return nil, 'parse_folder_status: missing state string'
    end
    local state_changed = decoded.stateChanged
    local pull_errors = decoded.pullErrors
    local need_bytes = decoded.needBytes
    return {
        state = decoded.state,
        state_changed = type(state_changed) == 'string' and state_changed or '',
        pull_errors = type(pull_errors) == 'number' and math.floor(pull_errors) or 0,
        need_bytes = type(need_bytes) == 'number' and math.floor(need_bytes) or 0,
    },
        nil
end

--- Parse /rest/stats/folder JSON into a folder-id -> lastScan map. Pure and
--- bounded; entries without a lastScan string are skipped.
---@param text string Raw endpoint body.
---@return table<string, string>|nil scans
---@return string|nil err
function M.parse_last_scans(text)
    if type(text) ~= 'string' then
        return nil, 'parse_last_scans expects a string, got ' .. type(text)
    end
    if #text > M.config.parse_line_max then
        return nil, ('input %d bytes exceeds parse_line_max %d'):format(#text, M.config.parse_line_max)
    end
    local ok, decoded = pcall(vim.json.decode, text)
    if not ok or type(decoded) ~= 'table' then
        return nil, 'parse_last_scans: not JSON (' .. text:sub(1, 80) .. ')'
    end
    ---@type table<string, string>
    local scans = {}
    for id, entry in pairs(decoded) do
        if type(id) == 'string' and type(entry) == 'table' and type(entry.lastScan) == 'string' then
            scans[id] = entry.lastScan
        end
    end
    return scans, nil
end

--- Human byte count, e.g. 9789241 -> '9.34 MB'. Pure; non-numbers and
--- negatives degrade to '0 B' rather than throwing.
---@param n number
---@return string text
function M.format_bytes(n)
    local units = { 'B', 'KB', 'MB', 'GB', 'TB' }
    if type(n) ~= 'number' or n < 0 then
        return '0 B'
    end
    local value = n
    local unit = 1
    while value >= 1024 and unit < #units do
        value = value / 1024
        unit = unit + 1
    end
    if unit == 1 then
        return ('%d B'):format(math.floor(value))
    end
    return ('%.2f %s'):format(value, units[unit])
end

--- Fetch the folder list from /rest/config/folders. Never throws; failures
--- degrade to nil+err.
---@param settings sync.GuiSettings
---@return sync.Folder[]|nil folders
---@return string|nil err
function M.folders(settings)
    local body, get_err = M.api_get(settings, M.config.folders_endpoint)
    if get_err ~= nil then
        return nil, get_err
    end
    assert(body ~= nil, 'api_get returned no error but no body')
    return M.parse_folders(body)
end

--- Build the :SyncStatus float lines: reachability header, then one line
--- per folder with completion %, need bytes, state, pull errors, and last
--- scan time. Per-folder probe failures degrade to 'unavailable' markers
--- on that folder's line rather than failing the whole report. Never
--- throws; a total failure returns nil+err.
---@param settings sync.GuiSettings
---@return string[]|nil lines
---@return string|nil err
function M.status_lines(settings)
    local lines = {}
    local version_body, version_err = M.api_get(settings, M.config.version_endpoint)
    if version_body ~= nil then
        local ok, decoded = pcall(vim.json.decode, version_body)
        local version = ok and type(decoded) == 'table' and decoded.version or nil
        lines[#lines + 1] = ('syncthing @ %s: reachable (v%s)'):format(
            M.gui_base_url(settings.address) or '?',
            type(version) == 'string' and version or '?'
        )
    else
        return nil, 'GUI not reachable: ' .. tostring(version_err)
    end
    local folders, folders_err = M.folders(settings)
    if folders_err ~= nil then
        return nil, folders_err
    end
    assert(folders ~= nil, 'folders returned no error but no list')
    local scans_body = M.api_get(settings, M.config.last_scan_endpoint)
    local scans = {}
    if scans_body ~= nil then
        scans = M.parse_last_scans(scans_body) or {}
    end
    if #folders == 0 then
        lines[#lines + 1] = 'no folders configured'
        return lines, nil
    end
    for _, folder in ipairs(folders) do
        if #lines >= OUTPUT_LINES_MAX then
            break
        end
        local query = '?folder=' .. url_encode(folder.id)
        local comp_body = M.api_get(settings, M.config.completion_endpoint .. query)
        local comp = comp_body ~= nil and M.parse_completion(comp_body) or nil
        local stat_body = M.api_get(settings, M.config.status_endpoint .. query)
        local st = stat_body ~= nil and M.parse_folder_status(stat_body) or nil
        local head = folder.id
        if folder.label ~= '' then
            head = head .. ' (' .. folder.label .. ')'
        end
        if comp == nil or st == nil then
            lines[#lines + 1] = head .. ': unavailable (probe failed)'
        else
            local last_scan = scans[folder.id] or 'unknown'
            lines[#lines + 1] = ('%s: %.2f%% complete, need %s, state=%s, pull errors=%d, last scan %s'):format(
                head,
                comp.completion_pct,
                M.format_bytes(comp.need_bytes),
                st.state,
                st.pull_errors,
                last_scan
            )
        end
    end
    return lines, nil
end

--- Open a centered, minimal, read-only float. `q` closes it (mirrors the
--- calendar/git float idiom).
---@param title string Float title.
---@param lines string[] Buffer content.
---@return integer buf
---@return integer win
local function open_float(title, lines)
    local buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    api.nvim_buf_set_name(buf, 'syncthing://' .. title)
    local win_width = math.min(M.config.float_width, vim.o.columns - 4)
    local win_height = math.min(M.config.float_height, vim.o.lines - 4)
    local win = api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = win_width,
        height = win_height,
        row = math.floor((vim.o.lines - win_height) / 2),
        col = math.floor((vim.o.columns - win_width) / 2),
        style = 'minimal',
        border = 'rounded',
        title = ' ' .. title .. ' ',
        title_pos = 'center',
    })
    vim.keymap.set('n', 'q', '<cmd>close<cr>', { buffer = buf, silent = true, desc = 'Close sync float' })
    return buf, win
end

--- Show the :SyncStatus float.
---@param lines string[] Prebuilt by M.status_lines.
function M.show_status(lines)
    open_float('sync status', lines)
end

--- Read-only `tailscale status` probe. Never throws: a missing binary or a
--- failing probe degrades to nil + an 'unavailable' message.
---@return string|nil output
---@return string|nil err
function M.tailscale_status()
    if not toolmgr.binary_present(M.config.tailscale_bin) then
        return nil, ("tailscale binary '%s' not found on PATH"):format(M.config.tailscale_bin)
    end
    local result, exec_err = rce.safe_exec({ M.config.tailscale_bin, 'status' }, { timeout_ms = M.config.timeout_ms })
    if exec_err ~= nil then
        return nil, exec_err
    end
    assert(result ~= nil, 'safe_exec returned no error but no result')
    if result.code ~= 0 then
        return nil, 'tailscale status exited ' .. result.code .. ': ' .. (result.stderr or ''):sub(1, 200)
    end
    return (result.stdout or ''):sub(1, STATUS_BYTES_MAX), nil
end

--- Copy the current buffer's file into sync_dir. The only write op in the
--- module. Steps: confirm via vim.ui.select when confirm_push is true
--- (default), :write the buffer if modified, then vim.uv.fs_copyfile (no
--- shell). on_done fires with (info, nil) on success, (nil, nil) when the
--- user cancels, (nil, err) on failure; M.push_current_buffer never throws.
---@param on_done fun(info: { bytes: integer, dest: string }|nil, err: string|nil)
function M.push_current_buffer(on_done)
    if type(on_done) ~= 'function' then
        error('sync: push_current_buffer requires an on_done callback', 2)
    end
    local src = api.nvim_buf_get_name(0)
    if src == '' then
        on_done(nil, 'PushToPhone needs a file-backed buffer')
        return
    end
    local sync_dir = fn.expand(M.config.sync_dir)
    local dir_stat = uv.fs_stat(sync_dir)
    if dir_stat == nil or dir_stat.type ~= 'directory' then
        on_done(nil, 'sync_dir is not a directory: ' .. sync_dir)
        return
    end
    local function run_copy()
        if vim.bo[0].modified then
            --- Save first so the phone never receives a stale copy. `silent!`
            --- keeps the success path quiet (the module reports its own
            --- result) and still raises catchable errors through pcall.
            local write_ok, write_err = pcall(vim.cmd, 'silent! write')
            if not write_ok then
                on_done(nil, 'cannot :write buffer: ' .. tostring(write_err))
                return
            end
        end
        local stat = uv.fs_stat(src)
        if stat == nil or stat.type ~= 'file' or stat.size == nil then
            on_done(nil, 'cannot stat source file: ' .. src)
            return
        end
        local dest = sync_dir .. '/' .. vim.fs.basename(src)
        local copy_ok, copy_err = uv.fs_copyfile(src, dest)
        if not copy_ok then
            on_done(nil, 'copy failed: ' .. tostring(copy_err))
            return
        end
        on_done({ bytes = stat.size, dest = dest }, nil)
    end
    if M.config.confirm_push then
        local select_impl = M.config.select_impl or vim.ui.select
        local prompt = 'Push ' .. vim.fs.basename(src) .. ' to ' .. sync_dir .. '?'
        select_impl({ 'Push to phone', 'Cancel' }, { prompt = prompt }, function(choice)
            if choice ~= 1 then
                on_done(nil, nil)
                return
            end
            run_copy()
        end)
    else
        run_copy()
    end
end

--- Map a toolmgr binary report onto the check status vocabulary.
--- Mirrors cargo/git/calendar: missing tools are 'unavailable', never an error.
---@param report utils.toolmgr.BinaryReport
---@return sync.Check
local function to_check(report)
    local status = 'unavailable'
    if report.present and report.meets_minimum then
        status = 'ok'
    elseif report.present then
        status = 'below minimum'
    end
    return { name = report.name, status = status, detail = report.detail }
end

--- Per-check validation. Never throws and never errors: missing pieces say
--- "unavailable". The API key's presence is reported; its value never
--- appears in any check detail.
---@return sync.Check[] checks
function M.checks()
    local cfg = M.config
    local checks = {}
    checks[#checks + 1] =
        to_check(toolmgr.check_binary({ name = cfg.syncthing_bin, min_version = cfg.syncthing_version_min }))
    local settings, settings_err = M.read_gui_settings()
    if settings ~= nil then
        checks[#checks + 1] = {
            name = 'gui config',
            status = 'ok',
            detail = 'readable, API key present: ' .. fn.expand(cfg.syncthing_config_path),
        }
    else
        checks[#checks + 1] = { name = 'gui config', status = 'unavailable', detail = tostring(settings_err) }
    end
    if settings ~= nil then
        local body, probe_err = M.api_get(settings, cfg.version_endpoint)
        if body ~= nil then
            local ok, decoded = pcall(vim.json.decode, body)
            local version = ok and type(decoded) == 'table' and decoded.version or nil
            checks[#checks + 1] = {
                name = 'gui',
                status = 'ok',
                detail = ('reachable at %s (syncthing %s)'):format(
                    M.gui_base_url(settings.address) or '?',
                    type(version) == 'string' and version or '?'
                ),
            }
        else
            checks[#checks + 1] =
                { name = 'gui', status = 'unavailable', detail = 'not reachable: ' .. tostring(probe_err) }
        end
    else
        checks[#checks + 1] = { name = 'gui', status = 'unavailable', detail = 'skipped: no GUI settings' }
    end
    local sync_dir = fn.expand(cfg.sync_dir)
    local dir_stat = uv.fs_stat(sync_dir)
    if dir_stat ~= nil and dir_stat.type == 'directory' and uv.fs_access(sync_dir, 'W') then
        checks[#checks + 1] = { name = 'sync_dir', status = 'ok', detail = 'writable: ' .. sync_dir }
    else
        checks[#checks + 1] =
            { name = 'sync_dir', status = 'unavailable', detail = 'not a writable directory: ' .. sync_dir }
    end
    checks[#checks + 1] =
        to_check(toolmgr.check_binary({ name = cfg.tailscale_bin, min_version = cfg.tailscale_version_min }))
    return checks
end

--- :SyncStatus -- float window with syncthing reachability, per-folder
--- completion %, last scan time, and errors/folder state. Read-only.
---@param _cmd_opts table nvim_create_user_command callback options.
function M.cmd_status(_cmd_opts)
    local settings, settings_err = M.read_gui_settings()
    if settings == nil then
        vim.notify('SyncStatus: ' .. tostring(settings_err), vim.log.levels.WARN)
        return
    end
    local lines, lines_err = M.status_lines(settings)
    if lines_err ~= nil then
        vim.notify('SyncStatus: ' .. lines_err, vim.log.levels.WARN)
        return
    end
    assert(lines ~= nil, 'status_lines returned no error but no lines')
    M.show_status(lines)
end

--- :PushToPhone -- copy the current buffer's file into sync_dir. Confirms
--- first (unless confirm_push is false), :writes when modified, copies with
--- vim.uv.fs_copyfile, and reports the bytes copied.
---@param _cmd_opts table nvim_create_user_command callback options.
function M.cmd_push(_cmd_opts)
    M.push_current_buffer(function(info, err)
        if err ~= nil then
            vim.notify('PushToPhone: ' .. err, vim.log.levels.ERROR)
        elseif info == nil then
            vim.notify('PushToPhone: cancelled', vim.log.levels.INFO)
        else
            vim.notify(('PushToPhone: %d bytes -> %s'):format(info.bytes, info.dest), vim.log.levels.INFO)
        end
    end)
end

--- :TailscaleStatus -- read-only `tailscale status` rendered in a float;
--- degrades to a warning when tailscale is absent.
---@param _cmd_opts table nvim_create_user_command callback options.
function M.cmd_tailscale(_cmd_opts)
    local output, err = M.tailscale_status()
    if err ~= nil then
        vim.notify('TailscaleStatus unavailable: ' .. err, vim.log.levels.WARN)
        return
    end
    assert(output ~= nil, 'tailscale_status returned no error but no output')
    local lines = {}
    for line in (output .. '\n'):gmatch('([^\n]*)\n') do
        if #lines < OUTPUT_LINES_MAX then
            lines[#lines + 1] = line
        end
    end
    if #lines == 0 then
        lines[1] = '(tailscale status returned no output)'
    end
    open_float('tailscale status', lines)
end

--- :SyncDocs -- open the verified Syncthing REST + Tailscale CLI docs.
---@param _cmd_opts table nvim_create_user_command callback options.
function M.cmd_docs(_cmd_opts)
    if vim.ui.open ~= nil then
        pcall(vim.ui.open, M.config.docs_url)
    end
    vim.notify(
        'syncthing REST docs: ' .. M.config.docs_url .. '\ntailscale CLI docs: ' .. M.config.tailscale_docs_url,
        vim.log.levels.INFO
    )
end

--- :SyncValidate -- one vim.notify per check; missing pieces say
--- "unavailable", never an error. The API key never appears.
---@param _cmd_opts table nvim_create_user_command callback options.
function M.cmd_validate(_cmd_opts)
    for _, check in ipairs(M.checks()) do
        local level = check.status == 'ok' and vim.log.levels.INFO or vim.log.levels.WARN
        vim.notify(('sync %-10s %-13s %s'):format(check.name, check.status, check.detail), level)
    end
end

--- :SyncUpdateCheck -- toolmgr update dialogs for syncthing
--- (syncthing/syncthing) and tailscale (tailscale/tailscale).
---@param _cmd_opts table nvim_create_user_command callback options.
function M.cmd_update_check(_cmd_opts)
    local current_syncthing = toolmgr.command_version({ M.config.syncthing_bin, '--version' })
    toolmgr.check_update({
        tool_label = 'syncthing',
        repo = M.config.update_repo_syncthing,
        package = M.config.update_package_syncthing,
        current_version = current_syncthing,
        known_upstream_version = M.config.known_upstream_version_syncthing,
        migrations = MIGRATIONS,
        select_impl = M.config.select_impl,
    })
    local current_tailscale = toolmgr.command_version({ M.config.tailscale_bin, 'version' })
    toolmgr.check_update({
        tool_label = 'tailscale',
        repo = M.config.update_repo_tailscale,
        package = M.config.update_package_tailscale,
        current_version = current_tailscale,
        known_upstream_version = M.config.known_upstream_version_tailscale,
        migrations = MIGRATIONS,
        select_impl = M.config.select_impl,
    })
end

local setup_done = false

--- Register the :Sync* commands. Idempotent: commands are created once;
--- the config is rebuilt on every call. Performs no subprocess I/O itself.
---@param config? table Overrides merged over M.default_config.
function M.setup(config)
    M.config = M.setup_config(config)
    if setup_done then
        return
    end
    setup_done = true
    api.nvim_create_user_command('SyncStatus', M.cmd_status, {
        desc = 'Floating syncthing status: reachability, per-folder completion, state',
    })
    api.nvim_create_user_command('PushToPhone', M.cmd_push, {
        desc = 'Copy the current buffer file into the Sync dir (confirms first)',
    })
    api.nvim_create_user_command('TailscaleStatus', M.cmd_tailscale, {
        desc = 'Floating read-only `tailscale status` view',
    })
    api.nvim_create_user_command('SyncDocs', M.cmd_docs, {
        desc = 'Open the Syncthing REST + Tailscale CLI documentation',
    })
    api.nvim_create_user_command('SyncValidate', M.cmd_validate, {
        desc = 'Sync per-check validation report',
    })
    api.nvim_create_user_command('SyncUpdateCheck', M.cmd_update_check, {
        desc = 'Syncthing + tailscale update check',
    })
end

return M
