-- /qompassai/Diver/lua/ai/dataaccess/api.lua
-- Qompass AI Data Access Socket API (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- Agent-native control surface for the data-access layer: a
-- unix-domain socket server speaking newline-delimited JSON, so a
-- coordinator can run security-scanned queries, confirm writes,
-- inspect sessions, and close them -- all through the one managed,
-- session-reused layer instead of ad-hoc database clients.
--
-- ============================================================
-- LOCAL SOCKET ONLY. This module NEVER binds a network port. The
-- listener is a unix-domain socket at <runtime-dir>/ai-dataaccess.sock,
-- reachable only by processes on this same machine. No TCP, no TLS,
-- no remote access: the trust boundary is the local user account.
-- ============================================================
--
-- Plain words: this is the doorman for the data layer. The
-- coordinator knocks on a local file-socket and sends one-line notes
-- ("run this query", "the operator approved that write", "what
-- sessions are open?"). This module checks every field against its
-- limits, hands the clean note to the backend, and writes the answer
-- back on the same line. The backend is wired in by ai.dataaccess at
-- setup time (this module never requires it, so there is no load
-- cycle); querying and session bookkeeping are the backend's job,
-- while this file owns only the socket protocol.
--
-- Security notes: nothing here ever spawns a shell and nothing from
-- the wire is interpolated anywhere (subprocesses are the backend's
-- argv-only business); every JSON encode and decode runs inside
-- pcall; every request field is validated before the backend sees it;
-- and secret-bearing connection fields are rejected at the backend --
-- a coordinator cannot smuggle a password through this socket.
-- Requests run scheduled on the main loop, never in the fast libuv
-- read callback (E5560).

local M = {}

local sched = require('ai.sched')
local bulk = require('ai.bulk')

-- Forward declarations: the pump needs handle_line, and the bulk
-- lane needs the pump, so both are assigned after the handlers are
-- defined below. Every use happens after module load.
local pump ---@type AiSched
local bulk_lane ---@type AiBulkLane

---@alias DataPipe uv.uv_pipe_t

local SOCKET_FILENAME = 'ai-dataaccess.sock'
local SOCKET_DIR_MODE = '0700'
local LISTEN_BACKLOG = 128
local MESSAGE_BYTES_MAX = 65536
-- Simultaneous client connections. Each connection holds a bounded
-- read buffer, but the count itself was unbounded: a hostile local
-- client could exhaust memory by opening thousands of connections.
local CONNECTION_COUNT_MAX = 64
local ADAPTER_LENGTH_MAX = 32
local DSN_TEXT_MAX = 4096
local DSN_TABLE_JSON_MAX = 16384
local TEXT_LENGTH_MAX = 65536
local TOKEN_LENGTH_MAX = 128
local KEY_LENGTH_MAX = 2048
local CMD_LABEL_MAX = 64
local FALLBACK_REPLY = '{"ok":false,"error":"reply encode failed"}'

---@class DataBackend
---@field query fun(params: table<string, any>): boolean, any
---Run a security-scanned query.
---@field confirm fun(params: table<string, any>): boolean, any
---Raise the operator confirmation prompt for a write token.
---@field status fun(params: table<string, any>): boolean, any
---Report session status.
---@field close fun(params: table<string, any>): boolean, any
---Release a session.
---@field list fun(params: table<string, any>): boolean, any
---List sessions.

---@class DataConnState
---@field buffer string Bytes received but not yet framed into lines.
---@field closed boolean True once the client handle is torn down.

---@class DataFieldSpec
---@field name string Request field to validate.
---@field required boolean Whether the field must be present.
---@field limit integer Maximum byte length of the field value.

local backend = nil ---@type DataBackend?
local server = nil ---@type DataPipe?
local bound_path = nil ---@type string?
local active_connections = 0
-- Every accepted client until close_client runs: M.stop() closes them
-- all, so a late close can never decrement the next generation's
-- counter and defeat the connection budget.
local live_clients = {} ---@type table<DataPipe, DataConnState>

---@param value any
---@param limit integer
---@return boolean
local function is_bounded_string(value, limit)
    if type(value) ~= 'string' then
        return false
    end
    if #value < 1 or #value > limit then
        return false
    end
    return value:find('%z') == nil
end

---Validate a dsn field: either a bounded path string or a small
---table (a connection table whose secret-bearing keys the backend
---rejects). Tables are size-bounded through their JSON encoding.
---@param value any
---@return boolean
local function is_valid_dsn(value)
    if is_bounded_string(value, DSN_TEXT_MAX) then
        return true
    end
    if type(value) ~= 'table' then
        return false
    end
    local ok, encoded = pcall(vim.json.encode, value)
    return ok and type(encoded) == 'string' and #encoded <= DSN_TABLE_JSON_MAX
end

---@param req table<string, any>
---@param spec DataFieldSpec[]
---@return table<string, any>? params
---@return string? err
local function validate_fields(req, spec)
    local params = {}
    for _, field in ipairs(spec) do
        local value = req[field.name]
        if value == nil then
            if field.required then
                return nil, field.name .. ' is required'
            end
        elseif field.name == 'dsn' then
            if not is_valid_dsn(value) then
                return nil, 'dsn must be a bounded path string or a small table'
            end
            params[field.name] = value
        elseif not is_bounded_string(value, field.limit) then
            local fmt = '%s must be a 1..%d byte string'
            return nil, fmt:format(field.name, field.limit)
        else
            params[field.name] = value
        end
    end
    return params, nil
end

---@param client DataPipe
---@param state DataConnState
local function close_client(client, state)
    if state.closed then
        return
    end
    state.closed = true
    live_clients[client] = nil
    active_connections = math.max(0, active_connections - 1)
    pcall(function()
        client:shutdown()
    end)
    pcall(function()
        client:close()
    end)
end

---Encode and write one reply line, falling back to a static payload
---when the backend's result is not JSON-encodable.
---@param client DataPipe
---@param state DataConnState
---@param payload table<string, any>
---@param close_after boolean
local function send_reply(client, state, payload, close_after)
    if state.closed then
        return
    end
    local ok, text = pcall(vim.json.encode, payload)
    if not ok or type(text) ~= 'string' then
        text = FALLBACK_REPLY
    end
    local write_ok = pcall(client.write, client, text .. '\n', function()
        if close_after then
            close_client(client, state)
        end
    end)
    if not write_ok and close_after then
        close_client(client, state)
    end
end

---Translate one backend call outcome into a protocol reply.
---@param client DataPipe
---@param state DataConnState
---@param pcall_ok boolean False when the backend function raised.
---@param backend_ok boolean The backend's own ok flag.
---@param result any The backend's result value or error.
---Scrub secrets from backend crash/error text before it crosses
---the socket. The backend redacts its own errors, but a raised panic
---bypasses that path, and tostring() of an error value can carry a
---DSN or connection detail.
---@param text string
---@return string
local function redact_error(text)
    local ok, secrets = pcall(require, 'ai.dataaccess.secrets')
    if ok and type(secrets) == 'table' and type(secrets.redact) == 'function' then
        local rok, scrubbed = pcall(secrets.redact, text)
        if rok and type(scrubbed) == 'string' then
            return scrubbed
        end
    end
    return text
end

local function send_backend_result(client, state, pcall_ok, backend_ok, result)
    if not pcall_ok then
        local detail = redact_error(tostring(backend_ok))
        send_reply(client, state, { ok = false, error = 'backend crashed: ' .. detail }, false)
        return
    end
    if backend_ok then
        send_reply(client, state, { ok = true, result = result }, false)
    else
        send_reply(client, state, { ok = false, error = redact_error(tostring(result)) }, false)
    end
end

local QUERY_FIELDS = {
    { name = 'adapter', required = true, limit = ADAPTER_LENGTH_MAX },
    { name = 'dsn', required = true, limit = DSN_TEXT_MAX },
    { name = 'text', required = true, limit = TEXT_LENGTH_MAX },
    { name = 'confirm_token', required = false, limit = TOKEN_LENGTH_MAX },
}
local CONFIRM_FIELDS = {
    { name = 'token', required = true, limit = TOKEN_LENGTH_MAX },
}
local KEY_REQUIRED_FIELDS = {
    { name = 'key', required = true, limit = KEY_LENGTH_MAX },
}
local KEY_OPTIONAL_FIELDS = {
    { name = 'key', required = false, limit = KEY_LENGTH_MAX },
}
local NO_FIELDS = {}

---@param client DataPipe
---@param state DataConnState
---@param req table<string, any>
---@param spec DataFieldSpec[]
---@param method string Backend method name.
local function handle_backend(client, state, req, spec, method)
    assert(backend ~= nil, 'handle_backend with no backend wired')
    local params, err = validate_fields(req, spec)
    if err ~= nil then
        send_reply(client, state, { ok = false, error = err }, false)
        return
    end
    assert(params ~= nil, 'validate_fields returned no params without error')
    local fn = backend[method]
    local ok, backend_ok, result_or_err = pcall(fn, params)
    send_backend_result(client, state, ok, backend_ok, result_or_err)
end

local function handle_query(client, state, line, req)
    assert(backend ~= nil, 'handle_query with no backend wired')
    local params, err = validate_fields(req, QUERY_FIELDS)
    if err ~= nil then
        send_reply(client, state, { ok = false, error = err }, false)
        return
    end
    assert(params ~= nil, 'validate_fields returned no params without error')
    -- Bulk: the database wait happens in libuv; the reply arrives via
    -- callback, off the main loop.
    bulk_lane:run(client, state, line, params, backend.query)
end

local function handle_confirm(client, state, _line, req)
    handle_backend(client, state, req, CONFIRM_FIELDS, 'confirm')
end

local function handle_status(client, state, _line, req)
    handle_backend(client, state, req, KEY_OPTIONAL_FIELDS, 'status')
end

local function handle_close(client, state, _line, req)
    handle_backend(client, state, req, KEY_REQUIRED_FIELDS, 'close')
end

local function handle_list(client, state, _line, req)
    handle_backend(client, state, req, NO_FIELDS, 'list')
end

local DISPATCH = {
    query = handle_query,
    confirm = handle_confirm,
    status = handle_status,
    close = handle_close,
    list = handle_list,
}

---@param client DataPipe
---@param state DataConnState
---@param line string One newline-delimited JSON request.
local function handle_line(client, state, line)
    local ok, decoded = pcall(vim.json.decode, line)
    if not ok or type(decoded) ~= 'table' or type(decoded.cmd) ~= 'string' then
        send_reply(client, state, { ok = false, error = 'bad request' }, false)
        return
    end
    assert(backend ~= nil, 'serving a request with no backend')
    local req = decoded ---@type table<string, any>
    local handler = DISPATCH[req.cmd]
    if handler == nil then
        local label = req.cmd:sub(1, CMD_LABEL_MAX)
        send_reply(client, state, { ok = false, error = 'unknown command: ' .. label }, false)
        return
    end
    handler(client, state, line, req)
end

---Commands that are tiny and latency-sensitive: they jump ahead of
---bulk commands in the pump. confirm replies immediately (the
---operator's choice lands on the token; the coordinator retries
---'query' with it), so it is control. query alone does the heavy
---subprocess work and waits its turn.
local CONTROL_COMMANDS = {
    status = true,
    list = true,
    close = true,
    confirm = true,
}

---Classify one framed request line for the pump. Best-effort scan
---for the "cmd" field with plain string matching (this runs in fast
---event context, so no vim.* calls); the authoritative JSON decode
---and validation still happen in handle_line. Undecodable lines and
---unknown commands count as control so their error replies come back
---fast instead of waiting behind bulk work.
---@param line string
---@return string 'control' or 'bulk'
local function classify_line(line)
    local cmd = line:match('"cmd"%s*:%s*"([^"]+)"')
    if cmd ~= nil and CONTROL_COMMANDS[cmd] == nil then
        return 'bulk'
    end
    return 'control'
end

pump = sched.new(classify_line, handle_line)

---At most this many bulk queries run at once; the rest requeue
---fairly through the pump instead of stampeding database CLIs.
local BULK_INFLIGHT_MAX = 16
---Watchdog for one bulk query: exceeds the slowest legitimate query
---(adapters cap at QUERY_TIMEOUT_MS = 15s).
local BULK_WATCHDOG_MS = 60000

bulk_lane = bulk.new({
    send_reply = send_reply,
    send_backend_result = send_backend_result,
    max_inflight = BULK_INFLIGHT_MAX,
    watchdog_ms = BULK_WATCHDOG_MS,
})

---Frame bytes into newline-delimited messages, enforcing
---MESSAGE_BYTES_MAX on each single message.
---@param client DataPipe
---@param state DataConnState
---@param err string?
---@param chunk string?
local function on_read(client, state, err, chunk)
    if state.closed then
        return
    end
    if err ~= nil or chunk == nil then
        close_client(client, state)
        return
    end
    state.buffer = state.buffer .. chunk
    while true do
        local newline = state.buffer:find('\n', 1, true)
        if newline == nil then
            break
        end
        local line = state.buffer:sub(1, newline - 1)
        state.buffer = state.buffer:sub(newline + 1)
        if #line > MESSAGE_BYTES_MAX then
            send_reply(client, state, { ok = false, error = 'message too large' }, true)
            return
        end
        if line:find('%S') ~= nil then
            -- Control-first pump: requests run scheduled on the main
            -- loop, never in this fast event context (E5560), and
            -- control requests jump ahead of bulk ones instead of
            -- strict FIFO. Each handler rechecks state.closed via
            -- send_reply. A full pump refuses instead of growing
            -- without bound.
            if not pump:enqueue(client, state, line) then
                local busy = { ok = false, error = 'server busy' }
                send_reply(client, state, busy, false)
            end
        end
    end
    if #state.buffer > MESSAGE_BYTES_MAX then
        -- No newline in sight and the pending bytes already exceed the
        -- bound, so this message can never become valid.
        send_reply(client, state, { ok = false, error = 'message too large' }, true)
    end
end

---@param err string?
local function on_connection(err)
    assert(server ~= nil, 'connection arrived with no server')
    if err ~= nil then
        return
    end
    local client = vim.uv.new_pipe(false)
    if client == nil then
        return
    end
    if not server:accept(client) then
        client:close()
        return
    end
    active_connections = active_connections + 1
    local state = { buffer = '', closed = false } ---@type DataConnState
    live_clients[client] = state
    if active_connections > CONNECTION_COUNT_MAX then
        -- Over the connection budget: refuse with a reason instead of
        -- accumulating unbounded per-connection state.
        send_reply(client, state, { ok = false, error = 'too many connections' }, true)
        return
    end
    client:read_start(function(read_err, read_chunk)
        on_read(client, state, read_err, read_chunk)
    end)
end

---Resolve the socket path, ensuring the runtime dir exists with mode
---0700. Prefers vim.fn.stdpath('run'), then $XDG_RUNTIME_DIR.
---Ensure a directory exists with owner-only permissions, tightening
---pre-existing directories: vim.fn.mkdir() applies the mode only when
---it creates the directory, so a loose pre-existing runtime dir would
---otherwise keep its permissions while the socket claims 0700.
---@param dir string
---@return boolean ok
---@return string? err
local function ensure_private_dir(dir)
    local mkdir_ok, made = pcall(vim.fn.mkdir, dir, 'p', SOCKET_DIR_MODE)
    if not mkdir_ok or made ~= 1 then
        return false, 'cannot create runtime dir: ' .. dir
    end
    local stat = vim.uv.fs_stat(dir)
    if stat == nil or stat.type ~= 'directory' then
        return false, 'not a directory: ' .. dir
    end
    -- stat.mode is st_mode: mask to permission bits, tighten when any
    -- group/other bit is set. 448 is 0o700.
    local perms = (stat.mode or 511) % 512
    if perms % 64 ~= 0 then
        -- pcall only guards Lua errors: fs_chmod returns nil+err on
        -- failure without throwing, so both results must be checked.
        local pcall_ok, chmod_ok, chmod_err = pcall(vim.uv.fs_chmod, dir, 448)
        if not pcall_ok or not chmod_ok then
            return false, 'cannot tighten permissions on ' .. dir .. ': ' .. tostring(chmod_err)
        end
    end
    return true, nil
end

---@return string? path
---@return string? err
function M.socket_path()
    local dir = vim.fn.stdpath('run')
    if dir == nil or dir == '' then
        local env_dir = os.getenv('XDG_RUNTIME_DIR')
        if env_dir == nil or env_dir == '' then
            return nil, 'no runtime dir'
        end
        dir = env_dir
    end
    local dir_ok, dir_err = ensure_private_dir(dir)
    if not dir_ok then
        return nil, dir_err
    end
    return dir .. '/' .. SOCKET_FILENAME, nil
end

---Wire in the backend (provided by ai.dataaccess at setup time). This
---module never requires ai.dataaccess itself, so there is no load cycle.
---@param b DataBackend
function M.set_backend(b)
    assert(type(b) == 'table', 'backend must be a table')
    -- query is bulk: it takes (params, cb). A sync function wired
    -- here would never call cb and its requests would hang.
    bulk.assert_callback_fn(b.query, 'query')
    assert(type(b.confirm) == 'function', 'backend.confirm must be a function')
    assert(type(b.status) == 'function', 'backend.status must be a function')
    assert(type(b.close) == 'function', 'backend.close must be a function')
    assert(type(b.list) == 'function', 'backend.list must be a function')
    backend = b
end

---Start the unix-domain socket listener. Refuses when already running
---or when no backend was wired in.
---@return boolean? ok
---@return string? err
function M.start()
    if server ~= nil then
        return nil, 'already started'
    end
    if backend == nil then
        return nil, 'no backend: call set_backend first'
    end
    local path, path_err = M.socket_path()
    if path == nil then
        return nil, path_err
    end
    assert(path_err == nil, 'socket_path returned nil path without error')
    -- A Neovim that died without stop() leaves its socket file behind,
    -- and bind() refuses a path that already exists. Removing it is
    -- safe: with no live listener attached the file is just litter.
    local stat = vim.uv.fs_stat(path)
    if stat ~= nil then
        if stat.type ~= 'socket' then
            return nil, 'socket path is not a socket: ' .. path
        end
        local removed, remove_err = os.remove(path)
        if not removed then
            return nil, 'cannot remove stale socket: ' .. tostring(remove_err)
        end
    end
    local pipe = vim.uv.new_pipe(false)
    if pipe == nil then
        return nil, 'socket bind failed: pipe allocation failed'
    end
    local bound, bind_err = pipe:bind(path)
    if not bound then
        pipe:close()
        return nil, 'socket bind failed: ' .. tostring(bind_err)
    end
    local listened, listen_err = pipe:listen(LISTEN_BACKLOG, on_connection)
    if not listened then
        pipe:close()
        os.remove(path)
        return nil, 'socket bind failed: ' .. tostring(listen_err)
    end
    server = pipe
    bound_path = path
    assert(server ~= nil, 'server handle lost after listen')
    return true, nil
end

---Idempotent teardown: shut down and close the listener, remove the
---socket file, and forget the handle. Safe to call when never started
---or more than once.
function M.stop()
    if server ~= nil then
        local handle = server
        server = nil
        pcall(function()
            handle:shutdown()
        end)
        handle:close()
    end
    if bound_path ~= nil then
        local path = bound_path
        bound_path = nil
        os.remove(path)
    end
    -- Close every live client first: their handles belong to this
    -- generation, and a late close_client after a counter reset would
    -- otherwise decrement the next generation's count and defeat the
    -- connection budget. Collect before closing: close_client mutates
    -- live_clients.
    local doomed = {}
    for client, state in pairs(live_clients) do
        doomed[#doomed + 1] = { client = client, state = state }
    end
    for _, entry in ipairs(doomed) do
        close_client(entry.client, entry.state)
    end
    active_connections = 0
end

return M
