--- BSP side of the AI debug bridge — lets agents drive builds through the
--- notify-based bsp/ layer and get results back through callbacks.
---
--- Plain-language version: the bsp/ layer talks to build servers (programs
--- that know how to compile a project), but it reports answers with on-screen
--- notifications, which an AI agent cannot read. This module wraps the same
--- layer and delivers every answer through a callback instead: it starts the
--- build server for a project root, lists build targets, compiles them, and
--- hands the result table to the caller.
---
--- Reuse, not a fork: sessions live in the layer's own
--- `require('bsp').state.sessions` table, startup goes through the layer's
--- `M.start(bufnr)`, and requests go through each session's wrapped rpc
--- handle (`session.rpc.request`, see `wrap_rpc` in lua/bsp/init.lua). The
--- layer's local `request()` helper is unreachable from outside, so this
--- module performs the same liveness checks itself before calling
--- `session.rpc.request` directly with a dot-call, exactly like the layer.
---
--- Root validation: the root must be a non-empty absolute path with no `..`
--- segments, and it must contain a recognized project marker (`Cargo.toml`
--- for cargo projects, or one of the Bazel workspace markers that
--- `bsp.bazel`'s `detect()` looks for). Bazel roots validate but cannot be
--- started: the layer's `M.start` only wires cargo connections, so `ensure`
--- reports that honestly instead of inventing support.
---@module 'ai.debugbridge.bsp'

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local uv = vim.uv

local bsp = require('bsp')

local M = {}

--- Retry budget for waiting on the layer's asynchronous `build/initialize`
--- handshake. Exactly one start attempt is made; these retries only re-check.
local RETRY_COUNT_MAX = 2
--- Delay between initialize checks, in milliseconds.
local INITIALIZE_POLL_MS = 1000
--- Cap on targets copied out of a `workspace/buildTargets` response.
local TARGET_COUNT_MAX = 4096
--- Cap on caller-supplied target URI lists.
local TARGET_URI_COUNT_MAX = 256
--- Cap on language IDs copied per target.
local LANGUAGE_ID_COUNT_MAX = 64
--- Cap on path segments scanned while rejecting `..` in roots.
local PATH_SEGMENT_COUNT_MAX = 256
--- Scratch buffer name used to give the layer's `M.start(bufnr)` a buffer
--- under the root. The file is never created on disk and the buffer is
--- deleted right after `M.start` returns; it exists only so the layer's
--- `cargo.root(bufnr)` (which searches upward from the buffer's directory
--- for `.bsp`/`Cargo.toml`) resolves to our root without touching the user's
--- buffers.
local SCRATCH_FILENAME = '.nvim-debugbridge-scratch'

--- Bazel workspace markers, mirroring what `bsp.bazel`'s `detect()` accepts.
local BAZEL_WORKSPACE_MARKERS = {
    'MODULE.bazel',
    'WORKSPACE.bazel',
    'WORKSPACE',
    'REPO.bazel',
}

---@class AiDebugBridgeBspTarget
---@field uri string
---@field display_name string|nil
---@field language_ids string[]

---@class AiDebugBridgeBspBuildResult
---@field status string # 'ok' | 'error' | 'cancelled'
---@field diagnostics table # Always empty: the layer routes build/publishDiagnostics to buffer diagnostics.

---@param kind string
---@param detail table
---@return nil
local function log_event(kind, detail)
    assert(type(kind) == 'string')
    assert(type(detail) == 'table')
    local ok_require, log = pcall(require, 'ai.debugbridge.log')
    if not ok_require then
        return
    end
    if type(log) ~= 'table' then
        return
    end
    if type(log.append) ~= 'function' then
        return
    end
    pcall(log.append, kind, detail)
end

---@param err any
---@return string
local function describe_error(err)
    if type(err) == 'table' and type(err.message) == 'string' then
        return err.message
    end
    return tostring(err)
end

---@param path string
---@return boolean
local function is_file(path)
    assert(type(path) == 'string')
    local stat = uv.fs_stat(path)
    return stat ~= nil and stat.type == 'file'
end

---@param path string
---@return boolean
local function is_dir(path)
    assert(type(path) == 'string')
    local stat = uv.fs_stat(path)
    return stat ~= nil and stat.type == 'directory'
end

---@param root string
---@return string|nil # 'cargo' | 'bazel' | nil when no marker is found
local function project_kind(root)
    assert(type(root) == 'string')
    assert(root ~= '')
    if is_file(fs.joinpath(root, 'Cargo.toml')) then
        return 'cargo'
    end
    if is_dir(fs.joinpath(root, '.bazelbsp')) then
        return 'bazel'
    end
    for index = 1, #BAZEL_WORKSPACE_MARKERS do
        if is_file(fs.joinpath(root, BAZEL_WORKSPACE_MARKERS[index])) then
            return 'bazel'
        end
    end
    return nil
end

---@param root any
---@return string|nil, string|nil
local function validate_root(root)
    if type(root) ~= 'string' then
        return nil, 'root must be a non-empty string'
    end
    if root == '' then
        return nil, 'root must be a non-empty string'
    end
    -- Check the raw input: normalization may collapse `..` away and hide it.
    local segment_count = 0
    for segment in root:gmatch('[^/]+') do
        segment_count = segment_count + 1
        if segment_count > PATH_SEGMENT_COUNT_MAX then
            return nil, 'root has too many path segments'
        end
        if segment == '..' then
            return nil, 'root must not contain ".." segments'
        end
    end
    local normalized = fs.normalize(root)
    if normalized == '' then
        return nil, 'root must be an absolute path'
    end
    if normalized:sub(1, 1) ~= '/' then
        return nil, 'root must be an absolute path'
    end
    -- Resolve symlinks so a symlinked root cannot smuggle a different
    -- tree under the project root the caller believes in; the marker
    -- check below then runs against the real tree.
    local real_root = vim.uv.fs_realpath(normalized)
    if real_root == nil then
        return nil, 'root does not resolve'
    end
    if project_kind(real_root) == nil then
        return nil, 'no recognized project marker (Cargo.toml or Bazel workspace file) under ' .. normalized
    end
    return real_root, nil
end

---@param session QompassBspSession|nil
---@return boolean
local function session_is_live(session)
    if type(session) ~= 'table' then
        return false
    end
    local rpc = session.rpc
    if type(rpc) ~= 'table' then
        return false
    end
    if type(rpc.is_closing) ~= 'function' then
        return false
    end
    local ok, closing = pcall(rpc.is_closing)
    if not ok then
        return false
    end
    return not closing
end

---@param root string
---@return QompassBspSession|nil, string|nil
local function live_session(root)
    assert(type(root) == 'string')
    local session = bsp.state.sessions[root]
    if session == nil then
        return nil, 'no live bsp session for ' .. root .. '; call ensure() first'
    end
    if not session_is_live(session) then
        return nil, 'no live bsp session for ' .. root .. '; call ensure() first'
    end
    if not session.initialized then
        return nil, 'bsp session for ' .. root .. ' is still initializing'
    end
    return session, nil
end

---@param target_uris any
---@return string[]|nil, string|nil
local function normalize_target_uris(target_uris)
    if target_uris == nil then
        return nil, nil
    end
    if type(target_uris) ~= 'table' then
        return nil, 'target_uris must be a list of target URI strings'
    end
    ---@type string[]
    local uris = {}
    for index, uri in ipairs(target_uris) do
        if type(uri) ~= 'string' then
            return nil, string.format('target_uris[%d] must be a non-empty string', index)
        end
        if uri == '' then
            return nil, string.format('target_uris[%d] must be a non-empty string', index)
        end
        if #uris >= TARGET_URI_COUNT_MAX then
            return nil, 'target_uris exceeds the limit of ' .. tostring(TARGET_URI_COUNT_MAX)
        end
        uris[#uris + 1] = uri
    end
    return uris, nil
end

---@param values any
---@return string[]
local function string_list(values)
    ---@type string[]
    local list = {}
    if type(values) ~= 'table' then
        return list
    end
    for _, value in ipairs(values) do
        if type(value) == 'string' and value ~= '' then
            list[#list + 1] = value
        end
        if #list >= LANGUAGE_ID_COUNT_MAX then
            break
        end
    end
    return list
end

---@param target QompassBspTarget
---@return AiDebugBridgeBspTarget|nil
local function map_target(target)
    if type(target) ~= 'table' then
        return nil
    end
    local id = target.id
    local uri = type(id) == 'table' and id.uri or nil
    if type(uri) ~= 'string' then
        return nil
    end
    if uri == '' then
        return nil
    end
    return {
        uri = uri,
        display_name = type(target.displayName) == 'string' and target.displayName or nil,
        language_ids = string_list(target.languageIds),
    }
end

---@param session QompassBspSession
---@param callback fun(err: string|nil, targets: QompassBspTarget[]|nil)
---@return nil
local function fetch_targets(session, callback)
    assert(type(session) == 'table')
    assert(type(callback) == 'function')
    assert(type(session.rpc) == 'table')
    assert(type(session.rpc.request) == 'function')
    local request = session.rpc.request
    local ok, sent = pcall(request, 'workspace/buildTargets', nil, function(err, result)
        vim.schedule(function()
            if err ~= nil then
                callback('workspace/buildTargets failed: ' .. describe_error(err))
                return
            end
            if type(result) ~= 'table' then
                callback('the bsp server returned an invalid target list')
                return
            end
            if type(result.targets) ~= 'table' then
                callback('the bsp server returned an invalid target list')
                return
            end
            ---@type QompassBspTarget[]
            local targets = {}
            for index, target in ipairs(result.targets) do
                if index > TARGET_COUNT_MAX then
                    log_event('bsp_error', {
                        limit = TARGET_COUNT_MAX,
                        note = 'target list truncated',
                        op = 'fetch_targets',
                    })
                    break
                end
                targets[#targets + 1] = target
            end
            callback(nil, targets)
        end)
    end)
    if not ok then
        callback('failed to send workspace/buildTargets')
        return
    end
    if sent ~= true then
        callback('failed to send workspace/buildTargets')
    end
end

---@param session QompassBspSession
---@param targets QompassBspTarget[]
---@param root string
---@param callback fun(err: string|nil, result: AiDebugBridgeBspBuildResult|nil)
---@return nil
local function compile_targets(session, targets, root, callback)
    assert(type(session) == 'table')
    assert(type(targets) == 'table')
    assert(type(root) == 'string')
    assert(type(callback) == 'function')
    assert(type(session.rpc) == 'table')
    assert(type(session.rpc.request) == 'function')
    ---@type QompassBspTargetIdentifier[]
    local identifiers = {}
    for _, target in ipairs(targets) do
        local id = type(target) == 'table' and target.id or nil
        local uri = type(id) == 'table' and id.uri or nil
        if type(uri) == 'string' and uri ~= '' then
            identifiers[#identifiers + 1] = { uri = uri }
        end
    end
    if #identifiers == 0 then
        callback('the bsp server reported no compilable targets')
        return
    end
    local params = {
        originId = 'ai-debugbridge-' .. tostring(uv.hrtime()),
        targets = identifiers,
    }
    local request = session.rpc.request
    local ok, sent = pcall(request, 'buildTarget/compile', params, function(err, result)
        vim.schedule(function()
            if err ~= nil then
                local failure = 'buildTarget/compile failed: ' .. describe_error(err)
                log_event('bsp_error', { error = failure, op = 'build_targets', root = root })
                callback(failure)
                return
            end
            -- BSP status codes: 1 = ok, 2 = error, 3 = cancelled.
            local status_code = type(result) == 'table' and result.statusCode or nil
            local status = 'error'
            if status_code == 1 then
                status = 'ok'
            elseif status_code == 3 then
                status = 'cancelled'
            end
            log_event('bsp_build', { root = root, status = status, target_count = #identifiers })
            -- Diagnostics arrive via build/publishDiagnostics notifications,
            -- which the layer routes to buffer diagnostics; this bridge does
            -- not intercept them, so diagnostics is always empty here.
            callback(nil, { diagnostics = {}, status = status })
        end)
    end)
    if not ok then
        local send_error = 'failed to send buildTarget/compile'
        log_event('bsp_error', { error = send_error, op = 'build_targets', root = root })
        callback(send_error)
        return
    end
    if sent ~= true then
        local send_error = 'failed to send buildTarget/compile'
        log_event('bsp_error', { error = send_error, op = 'build_targets', root = root })
        callback(send_error)
    end
end

---@param root string
---@param callback fun(err: string|nil, session: QompassBspSession|nil)
---@param attempts_left integer
---@return nil
local function wait_initialized(root, callback, attempts_left)
    assert(type(root) == 'string')
    assert(type(callback) == 'function')
    assert(type(attempts_left) == 'number')
    assert(attempts_left >= 0)
    local session = bsp.state.sessions[root]
    if session ~= nil and session_is_live(session) and session.initialized then
        log_event('bsp_ensure', { reused = false, root = root })
        callback(nil, session)
        return
    end
    if session == nil or not session_is_live(session) then
        -- The layer removes the session itself when build/initialize fails,
        -- so a missing session here means the start did not take.
        local gone_error = 'bsp session failed to start for ' .. root
        log_event('bsp_error', { error = gone_error, op = 'ensure', root = root })
        callback(gone_error)
        return
    end
    if attempts_left <= 0 then
        local timeout_error = 'bsp session did not finish initializing for ' .. root
        log_event('bsp_error', { error = timeout_error, op = 'ensure', root = root })
        callback(timeout_error)
        return
    end
    vim.defer_fn(function()
        wait_initialized(root, callback, attempts_left - 1)
    end, INITIALIZE_POLL_MS)
end

---@param root string
---@param callback fun(err: string|nil, session: QompassBspSession|nil)
---@return nil
function M.ensure(root, callback)
    assert(type(callback) == 'function')
    local normalized, root_error = validate_root(root)
    if normalized == nil then
        local message = root_error or 'invalid root'
        log_event('bsp_error', { error = message, op = 'ensure', root = tostring(root) })
        callback(message)
        return
    end
    if project_kind(normalized) ~= 'cargo' then
        local kind_error = 'bsp start is only wired for cargo projects: ' .. normalized
        log_event('bsp_error', { error = kind_error, op = 'ensure', root = normalized })
        callback(kind_error)
        return
    end
    local existing = bsp.state.sessions[normalized]
    if existing ~= nil and session_is_live(existing) then
        log_event('bsp_ensure', { reused = true, root = normalized })
        callback(nil, existing)
        return
    end
    -- The layer's M.start(bufnr) derives the project root from the buffer via
    -- cargo.root(bufnr), which searches upward from the buffer's directory.
    -- A scratch buffer named under the root is the smallest honest way to
    -- point it at the right project without touching the user's buffers.
    local bufnr = fn.bufadd(fs.joinpath(normalized, SCRATCH_FILENAME))
    assert(type(bufnr) == 'number')
    assert(bufnr > 0)
    local ok_start, start_error = pcall(bsp.start, bufnr)
    if api.nvim_buf_is_valid(bufnr) then
        pcall(api.nvim_buf_delete, bufnr, { force = true })
    end
    if not ok_start then
        local start_message = 'bsp start failed: ' .. tostring(start_error)
        log_event('bsp_error', { error = start_message, op = 'ensure', root = normalized })
        callback(start_message)
        return
    end
    wait_initialized(normalized, callback, RETRY_COUNT_MAX)
end

---@param root string
---@param target_uris string[]|nil Target URIs to compile; nil compiles all known targets.
---@param callback fun(err: string|nil, result: AiDebugBridgeBspBuildResult|nil)
---@return nil
function M.build_targets(root, target_uris, callback)
    assert(type(callback) == 'function')
    local normalized, root_error = validate_root(root)
    if normalized == nil then
        callback(root_error or 'invalid root')
        return
    end
    local uris, uris_error = normalize_target_uris(target_uris)
    if uris_error ~= nil then
        callback(uris_error)
        return
    end
    local session, session_error = live_session(normalized)
    if session == nil then
        callback(session_error or 'no live bsp session')
        return
    end
    if uris ~= nil then
        ---@type QompassBspTarget[]
        local explicit = {}
        for _, uri in ipairs(uris) do
            explicit[#explicit + 1] = { id = { uri = uri } }
        end
        compile_targets(session, explicit, normalized, callback)
        return
    end
    if #session.targets > 0 then
        compile_targets(session, session.targets, normalized, callback)
        return
    end
    fetch_targets(session, function(fetch_error, targets)
        if fetch_error ~= nil then
            callback(fetch_error)
            return
        end
        assert(targets ~= nil)
        session.targets = targets
        compile_targets(session, targets, normalized, callback)
    end)
end

---@param root string
---@param callback fun(err: string|nil, targets: AiDebugBridgeBspTarget[]|nil)
---@return nil
function M.list_targets(root, callback)
    assert(type(callback) == 'function')
    local normalized, root_error = validate_root(root)
    if normalized == nil then
        callback(root_error or 'invalid root')
        return
    end
    local session, session_error = live_session(normalized)
    if session == nil then
        callback(session_error or 'no live bsp session')
        return
    end
    ---@param targets QompassBspTarget[]
    local function deliver(targets)
        ---@type AiDebugBridgeBspTarget[]
        local mapped = {}
        for index, target in ipairs(targets) do
            if index > TARGET_COUNT_MAX then
                break
            end
            local entry = map_target(target)
            if entry ~= nil then
                mapped[#mapped + 1] = entry
            end
        end
        callback(nil, mapped)
    end
    if #session.targets > 0 then
        deliver(session.targets)
        return
    end
    fetch_targets(session, function(fetch_error, targets)
        if fetch_error ~= nil then
            callback(fetch_error)
            return
        end
        assert(targets ~= nil)
        session.targets = targets
        deliver(targets)
    end)
end

---@param root string
---@param target_uris string[]|nil Validated like build_targets, but unused: testing is unsupported.
---@param callback fun(err: string|nil, result: AiDebugBridgeBspBuildResult|nil)
---@return nil
function M.test_targets(root, target_uris, callback)
    assert(type(callback) == 'function')
    local normalized, root_error = validate_root(root)
    if normalized == nil then
        callback(root_error or 'invalid root')
        return
    end
    local _, uris_error = normalize_target_uris(target_uris)
    if uris_error ~= nil then
        callback(uris_error)
        return
    end
    -- Honest limitation: the wrapped layer never negotiates the BSP test
    -- provider capability and contains no buildTarget/test path (verified:
    -- zero references in lua/bsp). Sending the method anyway would invent
    -- protocol support the client cannot honor.
    local message = 'buildTarget/test not supported by the wrapped client'
    log_event('bsp_test', { root = normalized, supported = false })
    log_event('bsp_error', { error = message, op = 'test_targets', root = normalized })
    callback(message)
end

---@param root string
---@return nil
function M.stop(root)
    local normalized, root_error = validate_root(root)
    if normalized == nil then
        local message = root_error or 'invalid root'
        log_event('bsp_error', { error = message, op = 'stop', root = tostring(root) })
        return
    end
    local session = bsp.state.sessions[normalized]
    if not session_is_live(session) then
        log_event('bsp_stop', { reason = 'no live session', root = normalized, stopped = false })
        return
    end
    local ok, stop_error = pcall(bsp.stop, normalized)
    if not ok then
        log_event('bsp_error', { error = tostring(stop_error), op = 'stop', root = normalized })
        return
    end
    log_event('bsp_stop', { root = normalized, stopped = true })
end

return M
