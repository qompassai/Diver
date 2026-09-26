-- /qompassai/Diver/lua/ai/debugbridge/api.lua
-- Qompass AI Debug Bridge Socket API (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Agent-native control surface for the debug bridge (one managed
-- bridge over diver's lua/dap/ DAP client suite and lua/bsp/ build
-- client): a unix-domain socket server speaking newline-delimited
-- JSON, so an AI coordinator can acquire debug sessions, set
-- breakpoints, launch security-scanned targets, run builds, and
-- quarantine malicious processes — all without spawning repeat
-- adapter processes.
--
-- ============================================================
-- LOCAL SOCKET ONLY. This module NEVER binds a network port. The
-- listener is a unix-domain socket at
-- <runtime-dir>/ai-debugbridge.sock, reachable only by processes on
-- this same machine. No TCP, no TLS, no remote access: the trust
-- boundary is the local user account.
-- ============================================================
--
-- Plain words: this is the doorman for the debug bridge. The
-- coordinator knocks on a local file-socket and sends one-line notes
-- ("acquire a session", "build this", "quarantine that file"). This
-- module reads each note, checks every field against its limits,
-- writes security-relevant commands to the audit log, hands the clean
-- params to the backend, and writes the answer back on the same line.
-- The backend is wired in with set_backend() (this module never
-- requires sibling bridge modules at load, so there is no load
-- cycle); debugging and building are the backend's job, while this
-- file owns only the socket protocol.
--
-- v1 LIMITATION: backend calls run scheduled on the server's main
-- loop, so a backend call that blocks synchronously (a long build, a
-- blocking wait) stalls EVERY connection until it returns. v1 has no
-- per-command cancellation or timeout; the backend must keep its work
-- bounded and non-blocking, and the coordinator must not treat the
-- socket as a job queue.
--
-- Security notes: nothing here ever spawns a shell and nothing from
-- the wire is interpolated anywhere (subprocesses are the backend's
-- argv-only business); every JSON encode and decode runs inside
-- pcall, and every request field is validated before the backend sees
-- it. Audit logging of security-relevant commands is best-effort: a
-- logging failure never blocks the command itself.

local M = {}

local SOCKET_FILENAME = 'ai-debugbridge.sock'
local SOCKET_DIR_MODE = '0700'
local LISTEN_BACKLOG = 128
local MESSAGE_BYTES_MAX = 65536
-- Simultaneous client connections. Each connection holds a bounded
-- read buffer, but the count itself was unbounded: a hostile local
-- client could exhaust memory by opening thousands of connections.
local CONNECTION_COUNT_MAX = 64
local CMD_LABEL_MAX = 64
local FALLBACK_REPLY = '{"ok":false,"error":"reply encode failed"}'

local SESSION_KEY_MAX = 128
local LANG_MAX = 64
local ADAPTER_NAME_MAX = 128
local TARGET_MAX = 4096
local PROJECT_ROOT_MAX = 4096
local FILE_PATH_MAX = 4096
local ROOT_MAX = 4096
local TARGET_NAME_MAX = 256
local STRING_LIST_MAX = 256
local LINE_NUMBER_MAX = 2147483647
local LOG_TAIL_DEFAULT = 50
local LOG_TAIL_MIN = 1
local LOG_TAIL_MAX = 200

---@class DebugBridgeBackend
---@field session_acquire fun(params: table<string, any>): boolean, any
---Acquire (or reuse) a debug session for a language adapter.
---@field session_release fun(params: table<string, any>): boolean, any
---Release a session back to the pool without killing it.
---@field session_kill fun(params: table<string, any>): boolean, any
---Kill a session and its adapter process.
---@field set_breakpoint fun(params: table<string, any>): boolean, any
---Set a breakpoint at file:line.
---@field launch_scanned fun(params: table<string, any>): boolean, any
---Launch a target after the security scan passes.
---@field bsp_build fun(params: table<string, any>): boolean, any
---Run a BSP build for targets under root.
---@field bsp_targets fun(params: table<string, any>): boolean, any
---List BSP build targets under root.
---@field quarantine fun(params: table<string, any>): boolean, any
---Move a malicious path into quarantine.
---@field status fun(params: table<string, any>): boolean, any
---Report bridge status.

---@class DebugBridgeConnState
---@field buffer string Bytes received but not yet framed into lines.
---@field closed boolean True once the client handle is torn down.

---@class DebugBridgeFieldSpec
---@field name string Request field to validate.
---@field required boolean Whether the field must be present.
---@field limit integer Maximum byte length of the field value.

---@class DebugBridgeListSpec
---@field name string Request field holding a string list.
---@field required boolean Whether the field must be present.
---@field count_max integer Maximum number of list entries.
---@field item_max integer Maximum byte length of one entry.

local backend = nil ---@type DebugBridgeBackend?
local server = nil ---@type uv.uv_pipe_t?
local bound_path = nil ---@type string?
local active_connections = 0
-- Every accepted client until close_client runs: M.stop() closes them
-- all, so a late close can never decrement the next generation's
-- counter and defeat the connection budget.
local live_clients = {} ---@type table<uv.uv_pipe_t, DebugBridgeConnState>

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
---@param spec DebugBridgeFieldSpec[]
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

---Validate an optional/required list of bounded strings (used for
---launch file lists and BSP target lists). The list must be dense:
---keys are exactly the integers 1..count.
---@param req table<string, any>
---@param params table<string, any> Clean params table to extend.
---@param spec DebugBridgeListSpec
---@return string? err
local function validate_string_list(req, params, spec)
    local value = req[spec.name]
    if value == nil then
        if spec.required then
            return spec.name .. ' is required and must be a list of strings'
        end
        return nil
    end
    if type(value) ~= 'table' then
        return spec.name .. ' must be a list of strings'
    end
    local count = 0
    local max_key = 0
    for key in pairs(value) do
        count = count + 1
        if count > spec.count_max then
            return spec.name .. ' has too many entries'
        end
        if type(key) ~= 'number' or key < 1 or key ~= math.floor(key) then
            return spec.name .. ' must be a dense list of strings'
        end
        if key > max_key then
            max_key = key
        end
    end
    if max_key ~= count then
        return spec.name .. ' must be a dense list of strings'
    end
    local items = {}
    for index = 1, count do
        local item = value[index]
        if not is_bounded_string(item, spec.item_max) then
            local fmt = '%s[%d] must be a 1..%d byte string'
            return fmt:format(spec.name, index, spec.item_max)
        end
        items[index] = item
    end
    params[spec.name] = items
    return nil
end

---Read the breakpoint line number: a finite integer in 1..LINE_NUMBER_MAX.
---@param req table<string, any>
---@return integer? line_number
---@return string? err
local function line_param(req)
    local value = req.line
    if value == nil then
        return nil, 'line is required and must be a number'
    end
    if type(value) ~= 'number' then
        return nil, 'line must be a number'
    end
    if value ~= value or value == math.huge or value == -math.huge then
        return nil, 'line must be a finite number'
    end
    local line_number = math.floor(value)
    if line_number < 1 or line_number > LINE_NUMBER_MAX then
        return nil, 'line must be between 1 and ' .. tostring(LINE_NUMBER_MAX)
    end
    return line_number, nil
end

---Read the log_tail count: a finite number clamped to
---LOG_TAIL_MIN..LOG_TAIL_MAX. Absent means LOG_TAIL_DEFAULT.
---@param req table<string, any>
---@return integer? count
---@return string? err
local function log_tail_param(req)
    local value = req.n
    if value == nil then
        return LOG_TAIL_DEFAULT, nil
    end
    if type(value) ~= 'number' then
        return nil, 'n must be a number'
    end
    if value ~= value or value == math.huge or value == -math.huge then
        return nil, 'n must be a finite number'
    end
    local count = math.floor(value)
    if count < LOG_TAIL_MIN then
        count = LOG_TAIL_MIN
    elseif count > LOG_TAIL_MAX then
        count = LOG_TAIL_MAX
    end
    return count, nil
end

---Best-effort audit append for security-relevant commands. The log
---module is required here — never at load time — and log.lua has no
---dependencies of its own, so this cannot create a require cycle. A
---logging failure never blocks the command itself.
---@param kind string
---@param detail table<string, any>
local function audit(kind, detail)
    local require_ok, log = pcall(require, 'ai.debugbridge.log')
    if not require_ok or type(log) ~= 'table' then
        return
    end
    if type(log.append) ~= 'function' then
        return
    end
    pcall(log.append, kind, detail)
end

---@param client uv.uv_pipe_t
---@param state DebugBridgeConnState
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
---@param client uv.uv_pipe_t
---@param state DebugBridgeConnState
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
---@param client uv.uv_pipe_t
---@param state DebugBridgeConnState
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

local SESSION_ACQUIRE_FIELDS = {
    { name = 'lang', required = true, limit = LANG_MAX },
    { name = 'adapter_name', required = true, limit = ADAPTER_NAME_MAX },
    { name = 'target', required = true, limit = TARGET_MAX },
    { name = 'project_root', required = true, limit = PROJECT_ROOT_MAX },
}
local SESSION_KEY_FIELDS = {
    { name = 'key', required = true, limit = SESSION_KEY_MAX },
}
local SET_BREAKPOINT_FIELDS = {
    { name = 'file', required = true, limit = FILE_PATH_MAX },
}
local LAUNCH_SCANNED_FIELDS = {
    { name = 'lang', required = true, limit = LANG_MAX },
    { name = 'adapter_name', required = true, limit = ADAPTER_NAME_MAX },
    { name = 'target', required = true, limit = TARGET_MAX },
    { name = 'project_root', required = true, limit = PROJECT_ROOT_MAX },
}
local LAUNCH_FILES_SPEC = {
    name = 'files',
    required = false,
    count_max = STRING_LIST_MAX,
    item_max = FILE_PATH_MAX,
}
local BSP_ROOT_FIELDS = {
    { name = 'root', required = true, limit = ROOT_MAX },
}
local BSP_TARGETS_SPEC = {
    name = 'targets',
    required = false,
    count_max = STRING_LIST_MAX,
    item_max = TARGET_NAME_MAX,
}
local QUARANTINE_FIELDS = {
    { name = 'path', required = true, limit = FILE_PATH_MAX },
}
local NO_FIELDS = {}

---@param client uv.uv_pipe_t
---@param state DebugBridgeConnState
---@param req table<string, any>
local function handle_session_acquire(client, state, req)
    local params, err = validate_fields(req, SESSION_ACQUIRE_FIELDS)
    if err ~= nil then
        send_reply(client, state, { ok = false, error = err }, false)
        return
    end
    assert(params ~= nil, 'validate_fields returned no params without error')
    local ok, backend_ok, result_or_err = pcall(backend.session_acquire, params)
    send_backend_result(client, state, ok, backend_ok, result_or_err)
end

---@param client uv.uv_pipe_t
---@param state DebugBridgeConnState
---@param req table<string, any>
local function handle_session_release(client, state, req)
    local params, err = validate_fields(req, SESSION_KEY_FIELDS)
    if err ~= nil then
        send_reply(client, state, { ok = false, error = err }, false)
        return
    end
    assert(params ~= nil, 'validate_fields returned no params without error')
    local ok, backend_ok, result_or_err = pcall(backend.session_release, params)
    send_backend_result(client, state, ok, backend_ok, result_or_err)
end

---@param client uv.uv_pipe_t
---@param state DebugBridgeConnState
---@param req table<string, any>
local function handle_session_kill(client, state, req)
    local params, err = validate_fields(req, SESSION_KEY_FIELDS)
    if err ~= nil then
        send_reply(client, state, { ok = false, error = err }, false)
        return
    end
    assert(params ~= nil, 'validate_fields returned no params without error')
    audit('session_kill', params)
    local ok, backend_ok, result_or_err = pcall(backend.session_kill, params)
    send_backend_result(client, state, ok, backend_ok, result_or_err)
end

---@param client uv.uv_pipe_t
---@param state DebugBridgeConnState
---@param req table<string, any>
local function handle_set_breakpoint(client, state, req)
    local params, err = validate_fields(req, SET_BREAKPOINT_FIELDS)
    if err ~= nil then
        send_reply(client, state, { ok = false, error = err }, false)
        return
    end
    local line_number, line_err = line_param(req)
    if line_err ~= nil then
        send_reply(client, state, { ok = false, error = line_err }, false)
        return
    end
    assert(params ~= nil, 'validate_fields returned no params without error')
    assert(line_number ~= nil, 'line_param returned no line without error')
    params.line = line_number
    audit('set_breakpoint', params)
    local ok, backend_ok, result_or_err = pcall(backend.set_breakpoint, params)
    send_backend_result(client, state, ok, backend_ok, result_or_err)
end

---@param client uv.uv_pipe_t
---@param state DebugBridgeConnState
---@param req table<string, any>
local function handle_launch_scanned(client, state, req)
    local params, err = validate_fields(req, LAUNCH_SCANNED_FIELDS)
    if err ~= nil then
        send_reply(client, state, { ok = false, error = err }, false)
        return
    end
    assert(params ~= nil, 'validate_fields returned no params without error')
    local list_err = validate_string_list(req, params, LAUNCH_FILES_SPEC)
    if list_err ~= nil then
        send_reply(client, state, { ok = false, error = list_err }, false)
        return
    end
    audit('launch_scanned', params)
    local ok, backend_ok, result_or_err = pcall(backend.launch_scanned, params)
    send_backend_result(client, state, ok, backend_ok, result_or_err)
end

---@param client uv.uv_pipe_t
---@param state DebugBridgeConnState
---@param req table<string, any>
local function handle_bsp_build(client, state, req)
    local params, err = validate_fields(req, BSP_ROOT_FIELDS)
    if err ~= nil then
        send_reply(client, state, { ok = false, error = err }, false)
        return
    end
    assert(params ~= nil, 'validate_fields returned no params without error')
    local list_err = validate_string_list(req, params, BSP_TARGETS_SPEC)
    if list_err ~= nil then
        send_reply(client, state, { ok = false, error = list_err }, false)
        return
    end
    local ok, backend_ok, result_or_err = pcall(backend.bsp_build, params)
    send_backend_result(client, state, ok, backend_ok, result_or_err)
end

---@param client uv.uv_pipe_t
---@param state DebugBridgeConnState
---@param req table<string, any>
local function handle_bsp_targets(client, state, req)
    local params, err = validate_fields(req, BSP_ROOT_FIELDS)
    if err ~= nil then
        send_reply(client, state, { ok = false, error = err }, false)
        return
    end
    assert(params ~= nil, 'validate_fields returned no params without error')
    local ok, backend_ok, result_or_err = pcall(backend.bsp_targets, params)
    send_backend_result(client, state, ok, backend_ok, result_or_err)
end

---@param client uv.uv_pipe_t
---@param state DebugBridgeConnState
---@param req table<string, any>
local function handle_quarantine(client, state, req)
    local params, err = validate_fields(req, QUARANTINE_FIELDS)
    if err ~= nil then
        send_reply(client, state, { ok = false, error = err }, false)
        return
    end
    assert(params ~= nil, 'validate_fields returned no params without error')
    -- Traversal rejection is the backend's job: this layer only bounds
    -- the string and drops unknown fields, then passes the path through.
    audit('quarantine', params)
    local ok, backend_ok, result_or_err = pcall(backend.quarantine, params)
    send_backend_result(client, state, ok, backend_ok, result_or_err)
end

---@param client uv.uv_pipe_t
---@param state DebugBridgeConnState
---@param req table<string, any>
local function handle_status(client, state, req)
    local params, err = validate_fields(req, NO_FIELDS)
    if err ~= nil then
        send_reply(client, state, { ok = false, error = err }, false)
        return
    end
    assert(params ~= nil, 'validate_fields returned no params without error')
    local ok, backend_ok, result_or_err = pcall(backend.status, params)
    send_backend_result(client, state, ok, backend_ok, result_or_err)
end

---log_tail is served from the audit log directly, not the backend.
---@param client uv.uv_pipe_t
---@param state DebugBridgeConnState
---@param req table<string, any>
local function handle_log_tail(client, state, req)
    local count, count_err = log_tail_param(req)
    if count_err ~= nil then
        send_reply(client, state, { ok = false, error = count_err }, false)
        return
    end
    assert(count ~= nil, 'log_tail_param returned no count without error')
    local require_ok, log = pcall(require, 'ai.debugbridge.log')
    if not require_ok or type(log) ~= 'table' or type(log.tail) ~= 'function' then
        local err = 'log unavailable: ' .. tostring(log)
        send_reply(client, state, { ok = false, error = err }, false)
        return
    end
    local tail_ok, lines = pcall(log.tail, count)
    if not tail_ok or type(lines) ~= 'table' then
        local err = 'log tail failed: ' .. tostring(lines)
        send_reply(client, state, { ok = false, error = err }, false)
        return
    end
    send_reply(client, state, { ok = true, result = lines }, false)
end

local DISPATCH = {
    session_acquire = handle_session_acquire,
    session_release = handle_session_release,
    session_kill = handle_session_kill,
    set_breakpoint = handle_set_breakpoint,
    launch_scanned = handle_launch_scanned,
    bsp_build = handle_bsp_build,
    bsp_targets = handle_bsp_targets,
    quarantine = handle_quarantine,
    status = handle_status,
    log_tail = handle_log_tail,
}

---@param client uv.uv_pipe_t
---@param state DebugBridgeConnState
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
---@param client uv.uv_pipe_t
---@param state DebugBridgeConnState
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
    local state = { buffer = '', closed = false } ---@type DebugBridgeConnState
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

---Wire in the debug bridge backend. This module never requires the
---backend (or any sibling bridge module) at load time, so there is no
---load cycle; every backend function takes validated params and
---returns ok, result.
---@param b DebugBridgeBackend
function M.set_backend(b)
    assert(type(b) == 'table', 'backend must be a table')
    assert(type(b.session_acquire) == 'function', 'backend.session_acquire must be a function')
    assert(type(b.session_release) == 'function', 'backend.session_release must be a function')
    assert(type(b.session_kill) == 'function', 'backend.session_kill must be a function')
    assert(type(b.set_breakpoint) == 'function', 'backend.set_breakpoint must be a function')
    assert(type(b.launch_scanned) == 'function', 'backend.launch_scanned must be a function')
    assert(type(b.bsp_build) == 'function', 'backend.bsp_build must be a function')
    assert(type(b.bsp_targets) == 'function', 'backend.bsp_targets must be a function')
    assert(type(b.quarantine) == 'function', 'backend.quarantine must be a function')
    assert(type(b.status) == 'function', 'backend.status must be a function')
    backend = b
end

---Start the unix-domain socket listener. Idempotent: a second call
---while running is a no-op success. Refuses when no backend was wired
---in.
---@return boolean ok
---@return string? err
function M.start()
    if server ~= nil then
        return true, nil
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
    -- (Residual v1 race: a second live debugbridge instance listening
    -- on the same path would have its socket stolen; the coordinator
    -- runs one bridge per user, so this stays a documented edge.)
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
