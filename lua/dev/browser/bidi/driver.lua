-- Purpose: WebDriver process lifecycle. Resolves the chromedriver or
-- geckodriver binary, SHA256-verifies it against the pinned checksum in
-- config.lua BEFORE first spawn (never auto-downloads; a missing binary
-- errors with the exact download URL + expected SHA256), spawns it on
-- 127.0.0.1 with argv form only (never a shell string), waits for
-- /status, then performs the classic `New Session` HTTP POST and extracts
-- the BiDi webSocketUrl -- refusing any non-loopback URL. Teardown kills
-- the driver process exactly once; there are no zombies.

local http = require('dev.browser.http')
local config = require('dev.browser.bidi.config')

local M = {}

---@class BidiDriverProc
---@field kind string 'chrome' | 'firefox'
---@field handle userdata? uv process handle, nil after kill
---@field pid integer?

---Look up the driver pin for kind. Pure.
---@param kind string
---@return table? pin
---@return string? err
function M._pin(kind)
    local pin = config.drivers[kind]
    if pin == nil then
        return nil, "unknown driver kind: " .. tostring(kind) .. " (expected 'chrome' or 'firefox')"
    end
    return pin, nil
end

---Parse `sha256sum` stdout ('<64 hex>  <path>'). Pure.
---@param out string
---@return string? hex
---@return string? err
function M._parse_sha256sum_output(out)
    if type(out) ~= 'string' then
        return nil, 'sha256sum produced no output'
    end
    local hex = out:match('^(%x+)')
    if hex == nil or #hex ~= 64 then
        return nil, 'sha256sum output unparseable'
    end
    return hex:lower(), nil
end

---Build the spawn argv (argv form -- never a shell string). Pure.
---@param pin table driver pin from config
---@param profile_dir string ephemeral profile directory
---@return string[] argv including the binary path placeholder at [1]
function M._build_spawn_argv(pin, profile_dir)
    local argv = {}
    for i = 1, #pin.spawn_args do
        argv[i] = pin.spawn_args[i]
    end
    argv[#argv + 1] = '--port=' .. tostring(pin.port)
    if pin.binary_names[1] == 'chromedriver' then
        argv[#argv + 1] = '--user-data-dir=' .. profile_dir
    else
        argv[#argv + 1] = '--marionette-port=0'
    end
    return argv
end

---Extract {session_id, websocket_url} from a decoded /session body. Pure.
---@param decoded any
---@return table? session
---@return string? err
function M._extract_session(decoded)
    if type(decoded) ~= 'table' then
        return nil, 'session response is not a JSON object'
    end
    local value = decoded.value
    if type(value) ~= 'table' then
        return nil, 'session response has no value object'
    end
    if type(value.sessionId) ~= 'string' or value.sessionId == '' then
        return nil, 'session response has no sessionId'
    end
    local caps = value.capabilities
    if type(caps) ~= 'table' then
        return nil, 'session response has no capabilities'
    end
    if type(caps.webSocketUrl) ~= 'string' or caps.webSocketUrl == '' then
        return nil, 'capabilities have no webSocketUrl'
    end
    return { session_id = value.sessionId, websocket_url = caps.webSocketUrl }, nil
end

---Refuse a webSocketUrl whose host is not loopback. Pure.
---@param url string
---@return boolean? ok
---@return string? err
function M._check_ws_url(url)
    local host = url:match('^ws://([^:/%[%]]+):')
        or url:match('^ws://%[([^%]]+)%]:')
    if host == nil then
        return nil, 'unparseable webSocketUrl'
    end
    if host ~= '127.0.0.1' and host ~= '::1' and host ~= 'localhost' then
        return nil, 'bidi: non-loopback webSocketUrl refused (policy: localhost-only): ' .. host
    end
    return true, nil
end

---Find the driver binary: config search dirs first, then PATH.
---@param kind string 'chrome' | 'firefox'
---@return string? path
---@return string? err
function M.resolve(kind)
    local pin, perr = M._pin(kind)
    if pin == nil then
        return nil, perr
    end
    local names = pin.binary_names
    for _, dir in ipairs(config.driver_search_dirs) do
        for _, name in ipairs(names) do
            local candidate = dir .. '/' .. name
            if vim.fn.executable(candidate) == 1 then
                return candidate, nil
            end
        end
    end
    for _, name in ipairs(names) do
        if vim.fn.executable(name) == 1 then
            return vim.fn.exepath(name), nil
        end
    end
    return nil,
        'bidi: ' .. names[1] .. ' not found. Download ' .. pin.version .. ' from ' .. pin.url
            .. ' and set config.lua sha256 to '
            .. (pin.sha256 ~= '' and pin.sha256 or '<fill in from the release page>')
end

---SHA256-verify the binary against the pinned checksum. Never spawns on
---mismatch; never downloads.
---@param path string
---@param expected_sha256 string
---@return boolean? ok
---@return string? err
function M.verify(path, expected_sha256)
    assert(type(path) == 'string' and path ~= '', 'path must be non-empty')
    if type(expected_sha256) ~= 'string' or expected_sha256 == '' then
        return nil,
            'bidi: no SHA256 pinned for this driver version -- refusing to spawn. '
                .. 'Fill in config.lua sha256 from the vendor release page.'
    end
    if not expected_sha256:match('^%x%x%x%x%x%x%x%x') or #expected_sha256 ~= 64 then
        return nil, 'bidi: pinned sha256 is not 64 hex chars -- refusing to spawn'
    end
    local res = vim.system({ 'sha256sum', '--', path }, { text = true }):wait()
    if res.code ~= 0 then
        return nil, 'bidi: sha256sum failed (is coreutils installed?): ' .. (res.stderr or '')
    end
    local actual, perr = M._parse_sha256sum_output(res.stdout)
    if actual == nil then
        return nil, 'bidi: ' .. perr
    end
    if actual ~= expected_sha256:lower() then
        return nil,
            'bidi: driver checksum MISMATCH for ' .. path .. ' -- refusing to spawn. '
                .. 'Expected ' .. expected_sha256:lower() .. ', got ' .. actual
    end
    return true, nil
end

---Spawn the verified driver on 127.0.0.1. Returns the owned proc handle.
---@param kind string 'chrome' | 'firefox'
---@param profile_dir string ephemeral profile directory (argv form, no shell)
---@return BidiDriverProc? proc
---@return string? err
function M.spawn(kind, profile_dir)
    local pin, perr = M._pin(kind)
    if pin == nil then
        return nil, perr
    end
    if type(profile_dir) ~= 'string' or profile_dir == '' then
        return nil, 'profile_dir must be a non-empty string'
    end
    local path, rerr = M.resolve(kind)
    if path == nil then
        return nil, rerr
    end
    local ok, verr = M.verify(path, pin.sha256)
    if not ok then
        return nil, verr
    end
    local uv = vim.uv
    local stdout = uv.new_pipe(false)
    local stderr = uv.new_pipe(false)
    if stdout == nil or stderr == nil then
        return nil, 'cannot allocate stdio pipes'
    end
    local argv = M._build_spawn_argv(pin, profile_dir)
    local proc = { kind = kind, handle = nil, pid = nil }
    local handle, pid = uv.spawn(path, {
        args = argv,
        stdio = { nil, stdout, stderr },
    }, function()
        -- on_exit: release pipes; the handle is closed by M.kill.
        if not stdout:is_closing() then
            stdout:close()
        end
        if not stderr:is_closing() then
            stderr:close()
        end
    end)
    if handle == nil then
        if not stdout:is_closing() then
            stdout:close()
        end
        if not stderr:is_closing() then
            stderr:close()
        end
        return nil, 'failed to spawn driver: ' .. tostring(pid)
    end
    -- Discard driver chatter; pipes must be drained or the child blocks.
    stdout:read_start(function() end)
    stderr:read_start(function() end)
    proc.handle = handle
    proc.pid = pid
    return proc, nil
end

---Poll GET /status until the driver reports ready, bounded.
---@param kind string
---@return boolean? ok
---@return string? err
function M.wait_ready(kind)
    local pin, perr = M._pin(kind)
    if pin == nil then
        return nil, perr
    end
    for _ = 1, config.ready_attempts_max do
        local resp, rerr = http.request({
            host = config.host,
            port = pin.port,
            method = 'GET',
            path = '/status',
            timeout_ms = 1000,
        })
        if resp ~= nil and resp.status == 200 then
            local ok, decoded = pcall(vim.json.decode, resp.body)
            if ok and type(decoded) == 'table' and type(decoded.value) == 'table' then
                if decoded.value.ready then
                    return true, nil
                end
            end
        end
        _ = rerr
        vim.wait(config.ready_poll_interval_ms, function()
            return false
        end, 50)
    end
    return nil, 'driver /status never became ready'
end

---POST /session (classic New Session) asking for a BiDi webSocketUrl.
---@param kind string
---@param profile_dir string
---@return table? session {session_id, websocket_url}
---@return string? err
function M.new_session(kind, profile_dir)
    local pin, perr = M._pin(kind)
    if pin == nil then
        return nil, perr
    end
    local chrome_args = { args = { '--user-data-dir=' .. profile_dir } }
    local browser_options
    if kind == 'chrome' then
        browser_options = { ['goog:chromeOptions'] = chrome_args }
    else
        browser_options = { ['moz:firefoxOptions'] = { args = { '-profile', profile_dir } } }
    end
    local capabilities = {
        alwaysMatch = vim.tbl_extend('force', { webSocketUrl = true }, browser_options),
    }
    local resp, rerr = http.request({
        host = config.host,
        port = pin.port,
        method = 'POST',
        path = '/session',
        headers = { ['Content-Type'] = 'application/json' },
        body = vim.json.encode({ capabilities = capabilities }),
        timeout_ms = config.http_timeout_ms,
    })
    if resp == nil then
        return nil, 'POST /session failed: ' .. rerr
    end
    if resp.status ~= 200 then
        return nil, 'POST /session returned status ' .. resp.status .. ': ' .. resp.body:sub(1, 200)
    end
    local ok, decoded = pcall(vim.json.decode, resp.body)
    if not ok then
        return nil, 'POST /session returned invalid JSON'
    end
    local session, serr = M._extract_session(decoded)
    if session == nil then
        return nil, serr
    end
    local wok, werr = M._check_ws_url(session.websocket_url)
    if not wok then
        return nil, werr
    end
    return session, nil
end

---Kill the driver process. Idempotent: safe to call twice, on a dead
---process, or after the handle was already released.
---@param proc BidiDriverProc?
function M.kill(proc)
    if proc == nil then
        return
    end
    local handle = proc.handle
    proc.handle = nil
    proc.pid = nil
    if handle ~= nil and not handle:is_closing() then
        pcall(handle.kill, handle, 'sigterm')
        handle:close()
    end
end

return M
