-- /qompassai/Diver/lua/ai/herd/api.lua
-- Qompass AI Herd Agent API (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Agent-native control surface for the herd project (a Herdr-like
-- persistent agent runtime): a unix-domain socket server speaking
-- newline-delimited JSON, so a coordinator can spawn, prompt, poll,
-- wait on, and kill agents living in this Neovim instance.
--
-- ============================================================
-- LOCAL SOCKET ONLY. This module NEVER binds a network port. The
-- listener is a unix-domain socket at <runtime-dir>/herd.sock,
-- reachable only by processes on this same machine. No TCP, no TLS,
-- no remote access: the trust boundary is the local user account.
-- ============================================================
--
-- Plain words: this is the doorman for your agents. The coordinator
-- knocks on a local file-socket and sends one-line notes ("start an
-- agent", "ask it something", "is it done yet?"). This module reads
-- each note, hands it to the backend, and writes the answer back on
-- the same line. The backend is wired in by ai.herd at setup time
-- (this module never requires it, so there is no load cycle);
-- spawning, prompting, and killing are the backend's job, while this
-- file owns only the socket protocol.
--
-- v1 LIMITATION: wait_blocked runs the backend's blocking wait on the
-- server side, so while one connection waits, every other connection
-- stalls until that wait finishes or times out. The coordinator must
-- not share one connection for waiting and control traffic.
--
-- Security notes: nothing here ever spawns a shell and nothing from
-- the wire is interpolated anywhere; every JSON encode and decode
-- runs inside pcall, and every request field is validated before the
-- backend sees it.

local M = {}

local SOCKET_FILENAME = 'herd.sock'
local SOCKET_DIR_MODE = '0700'
local LISTEN_BACKLOG = 128
local MESSAGE_BYTES_MAX = 65536
-- Simultaneous client connections. Each connection holds a bounded
-- read buffer, but the count itself was unbounded: a hostile local
-- client could exhaust memory by opening thousands of connections.
local CONNECTION_COUNT_MAX = 64
local NAME_LENGTH_MAX = 128
local CLI_LENGTH_MAX = 8192
local TEXT_LENGTH_MAX = 16384
local CMD_LABEL_MAX = 64
local TIMEOUT_MS_MIN = 1000
local TIMEOUT_MS_MAX = 300000
local FALLBACK_REPLY = '{"ok":false,"error":"reply encode failed"}'

---@class HerdBackend
---@field spawn fun(params: table<string, any>): boolean, any
---Spawn an agent.
---@field prompt fun(params: table<string, any>): boolean, any
---Send text to an agent.
---@field status fun(params: table<string, any>): boolean, any
---Report agent status.
---@field wait_blocked fun(params: table<string, any>): boolean, any
---Block until an agent idles.
---@field kill fun(params: table<string, any>): boolean, any
---Stop an agent.
---@field list fun(params: table<string, any>): boolean, any
---List known agents.

---@class HerdConnState
---@field buffer string Bytes received but not yet framed into lines.
---@field closed boolean True once the client handle is torn down.

---@class HerdFieldSpec
---@field name string Request field to validate.
---@field required boolean Whether the field must be present.
---@field limit integer Maximum byte length of the field value.

local backend = nil ---@type HerdBackend?
local server = nil ---@type uv_pipe_t?
local bound_path = nil ---@type string?
local active_connections = 0
-- Every accepted client until close_client runs: M.stop() closes them
-- all, so a late close can never decrement the next generation's
-- counter and defeat the connection budget.
local live_clients = {} ---@type table<uv.uv_pipe_t, HerdConnState>

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

---Validate request fields against a spec, building the clean params
---table the backend receives. Unknown fields are dropped.
---@param req table<string, any>
---@param spec HerdFieldSpec[]
---@return table<string, any>? params
---@return string? err
local function validate_fields(req, spec)
    local params = {}
    for _, field in ipairs(spec) do
        local value = req[field.name]
        if value == nil then
            if field.required then
                local err = field.name .. ' is required and must be a string'
                return nil, err
            end
        elseif not is_bounded_string(value, field.limit) then
            local fmt = '%s must be a 1..%d byte string'
            local err = fmt:format(field.name, field.limit)
            return nil, err
        else
            params[field.name] = value
        end
    end
    return params, nil
end

---Read timeout_ms, clamped to the allowed window. Absent means the
---backend applies its own default.
---@param req table<string, any>
---@return integer? timeout_ms
---@return string? err
local function timeout_param(req)
    local value = req.timeout_ms
    if value == nil then
        return nil, nil
    end
    if type(value) ~= 'number' then
        return nil, 'timeout_ms must be a number'
    end
    if value ~= value or value == math.huge or value == -math.huge then
        return nil, 'timeout_ms must be a finite number'
    end
    local ms = math.floor(value)
    if ms < TIMEOUT_MS_MIN then
        ms = TIMEOUT_MS_MIN
    elseif ms > TIMEOUT_MS_MAX then
        ms = TIMEOUT_MS_MAX
    end
    return ms, nil
end

---@param client uv_pipe_t
---@param state HerdConnState
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

---Encode and write one reply line. Falls back to a static payload if
---the backend's result is not JSON-encodable.
---@param client uv_pipe_t
---@param state HerdConnState
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
---@param client uv_pipe_t
---@param state HerdConnState
---@param pcall_ok boolean False when the backend function raised.
---@param backend_ok boolean The backend's own ok flag.
---@param result any The backend's result value or error.
local function send_backend_result(client, state, pcall_ok, backend_ok, result)
    if not pcall_ok then
        local err = 'backend crashed: ' .. tostring(backend_ok)
        send_reply(client, state, { ok = false, error = err }, false)
        return
    end
    if backend_ok then
        send_reply(client, state, { ok = true, result = result }, false)
    else
        local err = tostring(result)
        send_reply(client, state, { ok = false, error = err }, false)
    end
end

local SPAWN_FIELDS = {
    { name = 'name', required = false, limit = NAME_LENGTH_MAX },
    { name = 'cli', required = true, limit = CLI_LENGTH_MAX },
    { name = 'task', required = false, limit = TEXT_LENGTH_MAX },
    { name = 'cwd', required = false, limit = CLI_LENGTH_MAX },
}
local PROMPT_FIELDS = {
    { name = 'agent', required = true, limit = NAME_LENGTH_MAX },
    { name = 'text', required = true, limit = TEXT_LENGTH_MAX },
}
local AGENT_REQUIRED_FIELDS = {
    { name = 'agent', required = true, limit = NAME_LENGTH_MAX },
}
local AGENT_OPTIONAL_FIELDS = {
    { name = 'agent', required = false, limit = NAME_LENGTH_MAX },
}
local NO_FIELDS = {}

---@param client uv_pipe_t
---@param state HerdConnState
---@param req table<string, any>
local function handle_spawn(client, state, req)
    local params, err = validate_fields(req, SPAWN_FIELDS)
    if err ~= nil then
        send_reply(client, state, { ok = false, error = err }, false)
        return
    end
    assert(params ~= nil, 'validate_fields returned no params without error')
    local ok, backend_ok, result_or_err = pcall(backend.spawn, params)
    send_backend_result(client, state, ok, backend_ok, result_or_err)
end

---@param client uv_pipe_t
---@param state HerdConnState
---@param req table<string, any>
local function handle_prompt(client, state, req)
    local params, err = validate_fields(req, PROMPT_FIELDS)
    if err ~= nil then
        send_reply(client, state, { ok = false, error = err }, false)
        return
    end
    assert(params ~= nil, 'validate_fields returned no params without error')
    local ok, backend_ok, result_or_err = pcall(backend.prompt, params)
    send_backend_result(client, state, ok, backend_ok, result_or_err)
end

---@param client uv_pipe_t
---@param state HerdConnState
---@param req table<string, any>
local function handle_status(client, state, req)
    local params, err = validate_fields(req, AGENT_OPTIONAL_FIELDS)
    if err ~= nil then
        send_reply(client, state, { ok = false, error = err }, false)
        return
    end
    assert(params ~= nil, 'validate_fields returned no params without error')
    local ok, backend_ok, result_or_err = pcall(backend.status, params)
    send_backend_result(client, state, ok, backend_ok, result_or_err)
end

---v1 LIMITATION: the backend call below blocks the server's event
---loop, so every other connection stalls until this wait finishes or
---times out. See the header; the coordinator must keep waiting and
---control traffic on separate connections.
---@param client uv_pipe_t
---@param state HerdConnState
---@param req table<string, any>
local function handle_wait_blocked(client, state, req)
    local params, err = validate_fields(req, AGENT_REQUIRED_FIELDS)
    if err ~= nil then
        send_reply(client, state, { ok = false, error = err }, false)
        return
    end
    local timeout_ms, timeout_err = timeout_param(req)
    if timeout_err ~= nil then
        send_reply(client, state, { ok = false, error = timeout_err }, false)
        return
    end
    assert(params ~= nil, 'validate_fields returned no params without error')
    params.timeout_ms = timeout_ms
    local ok, backend_ok, result_or_err = pcall(backend.wait_blocked, params)
    send_backend_result(client, state, ok, backend_ok, result_or_err)
end

---@param client uv_pipe_t
---@param state HerdConnState
---@param req table<string, any>
local function handle_kill(client, state, req)
    local params, err = validate_fields(req, AGENT_REQUIRED_FIELDS)
    if err ~= nil then
        send_reply(client, state, { ok = false, error = err }, false)
        return
    end
    assert(params ~= nil, 'validate_fields returned no params without error')
    local ok, backend_ok, result_or_err = pcall(backend.kill, params)
    send_backend_result(client, state, ok, backend_ok, result_or_err)
end

---@param client uv_pipe_t
---@param state HerdConnState
---@param req table<string, any>
local function handle_list(client, state, req)
    local params, err = validate_fields(req, NO_FIELDS)
    if err ~= nil then
        send_reply(client, state, { ok = false, error = err }, false)
        return
    end
    assert(params ~= nil, 'validate_fields returned no params without error')
    local ok, backend_ok, result_or_err = pcall(backend.list, params)
    send_backend_result(client, state, ok, backend_ok, result_or_err)
end

local DISPATCH = {
    spawn = handle_spawn,
    prompt = handle_prompt,
    status = handle_status,
    wait_blocked = handle_wait_blocked,
    kill = handle_kill,
    list = handle_list,
}

---@param client uv_pipe_t
---@param state HerdConnState
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
        local err = 'unknown command: ' .. label
        send_reply(client, state, { ok = false, error = err }, false)
        return
    end
    handler(client, state, req)
end

---Frame bytes into newline-delimited messages, enforcing
---MESSAGE_BYTES_MAX on each single message.
---@param client uv_pipe_t
---@param state HerdConnState
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
            local msg = { ok = false, error = 'message too large' }
            send_reply(client, state, msg, true)
            return
        end
        if line:find('%S') ~= nil then
            -- Requests run scheduled on the main loop, never in this
            -- fast event context: backend calls use vim.fn.* and
            -- vim.wait, which are forbidden here (E5560). Scheduled
            -- callbacks run FIFO, so multi-line pipelining stays ordered.
            -- Each handler rechecks state.closed via send_reply.
            vim.schedule(function()
                handle_line(client, state, line)
            end)
        end
    end
    if #state.buffer > MESSAGE_BYTES_MAX then
        -- No newline in sight and the pending bytes already exceed the
        -- bound, so this message can never become valid.
        local msg = { ok = false, error = 'message too large' }
        send_reply(client, state, msg, true)
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
    local state = { buffer = '', closed = false } ---@type HerdConnState
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

---Resolve the socket path, ensuring the runtime dir exists with mode
---0700. Prefers vim.fn.stdpath('run'), then $XDG_RUNTIME_DIR.
---@return string? path
---@return string? err
function M.socket_path()
    local dir = vim.fn.stdpath('run')
    if dir == nil or dir == '' then
        dir = os.getenv('XDG_RUNTIME_DIR')
    end
    if dir == nil or dir == '' then
        return nil, 'no runtime dir'
    end
    local dir_ok, dir_err = ensure_private_dir(dir)
    if not dir_ok then
        return nil, dir_err
    end
    return dir .. '/' .. SOCKET_FILENAME, nil
end

---Wire in the agent backend (provided by ai.herd at setup time). This
---module never requires ai.herd itself, so there is no load cycle.
---@param b HerdBackend
function M.set_backend(b)
    assert(type(b) == 'table', 'backend must be a table')
    assert(type(b.spawn) == 'function', 'backend.spawn must be a function')
    assert(type(b.prompt) == 'function', 'backend.prompt must be a function')
    assert(type(b.status) == 'function', 'backend.status must be a function')
    local wb = b.wait_blocked
    assert(type(wb) == 'function', 'backend.wait_blocked must be a function')
    assert(type(b.kill) == 'function', 'backend.kill must be a function')
    assert(type(b.list) == 'function', 'backend.list must be a function')
    backend = b
end

---Start the unix-domain socket listener. Refuses when already running
---or when no backend was wired in.
---@return boolean ok
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
    -- (Residual v1 race: a second live herd instance listening on the
    -- same path would have its socket stolen; the coordinator runs one
    -- herd per user, so this stays a documented edge.)
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
