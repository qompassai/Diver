-- ~/.config/nvim/lua/dap/store/init.lua
local common = require('dap.store.common')

local M = {}

---@alias DapStoreBackend 'postgresql'|'sqlite'

---@class DapStoreOptions
---@field backend? DapStoreBackend
---@field fallback? DapStoreBackend|false
---@field postgresql? DapPostgresStoreOptions
---@field sqlite? DapSqliteStoreOptions

---@class DapStoreSessionSpec
---@field root? string
---@field adapter? string
---@field configuration? string
---@field request? string
---@field executable? string
---@field cwd? string
---@field git_commit? string
---@field git_branch? string
---@field metadata? table

---@class DapStoreOutcome
---@field exit_code? integer
---@field result? string

---@class DapStoreBreakpointSpec
---@field path? string
---@field line? integer
---@field column_number? integer
---@field condition? string
---@field hit_condition? string
---@field log_message? string
---@field enabled? boolean

---@class DapStoreMetricSpec
---@field session_id string
---@field adapter string
---@field metric_name string
---@field metric_value number
---@field unit? string
---@field metadata? table

---@type DapStoreOptions
local options = {
    backend = 'postgresql',
    fallback = 'sqlite',
    postgresql = {},
    sqlite = {},
}

local active_backend = nil
local active_name = nil

---Maximum queued writes per session. Bounds memory when events arrive
---faster than the session row is inserted; overflow fails the write.
---@type integer
local SESSION_QUEUE_MAX = 100

---@class DapSessionWriteState
---@field started boolean true once the session row insert completed
---@field finished boolean true once session_finish was requested
---@field queue fun(backend: table)[] writes waiting for the session row

---@type table<string, DapSessionWriteState>
local session_writes = {}

---@class DapGitCacheEntry
---@field pending boolean
---@field commit? string
---@field branch? string
---@field waiters fun(info: { commit?: string, branch?: string })[]

---@type table<string, DapGitCacheEntry>
local git_cache = {}

---@param name DapStoreBackend
---@return table
local function backend_module(name)
    return require('dap.store.' .. name)
end

---@param name DapStoreBackend
---@param callback fun(ok: boolean, error?: string)
local function activate(name, callback)
    local backend = backend_module(name)
    local backend_opts = options[name] or {}

    backend.setup(backend_opts, function(ok, err)
        if ok then
            active_backend = backend
            active_name = name
        end

        callback(ok, err)
    end)
end

---@param opts? DapStoreOptions
---@param callback? fun(ok: boolean, backend?: DapStoreBackend, error?: string)
function M.setup(opts, callback)
    -- Fresh defaults on every setup: a previous setup's backend, fallback,
    -- and per-backend options must not leak into a later one.
    options = vim.tbl_deep_extend('force', {
        backend = 'postgresql',
        fallback = 'sqlite',
        postgresql = {},
        sqlite = {},
    }, opts or {})

    -- A re-setup starts clean: the previous backend must not serve writes
    -- while the new one initializes.
    active_backend = nil
    active_name = nil

    local env_backend = vim.env.DIVER_DAP_STORE
    if env_backend == 'postgresql' or env_backend == 'sqlite' then
        options.backend = env_backend
    end

    local preferred = options.backend or 'postgresql'

    activate(preferred, function(ok, err)
        if ok then
            if callback then
                callback(true, preferred)
            end
            return
        end

        local fallback = options.fallback
        if fallback == nil or fallback == false or fallback == preferred then
            if callback then
                callback(false, nil, err)
            end
            return
        end

        activate(fallback, function(fallback_ok, fallback_err)
            if callback then
                local backend_arg = fallback_ok and fallback or nil
                local err_arg = fallback_ok and err or fallback_err
                callback(fallback_ok, backend_arg, err_arg)
            end
        end)
    end)
end

---@return DapStoreBackend?
function M.backend_name()
    return active_name
end

---@return boolean
function M.ready()
    return active_backend ~= nil
end

---@param callback fun(ok: boolean, error?: string)
function M.health(callback)
    if not active_backend then
        callback(false, 'DAP store is not initialized')
        return
    end

    active_backend.health(callback)
end

---@param root string
---@param callback? fun(ok: boolean, result?: vim.SystemCompleted)
function M.ensure_project(root, callback)
    assert(type(root) == 'string' and root ~= '', 'root must be a non-empty string')

    if not active_backend then
        if callback then
            callback(false)
        end
        return
    end

    active_backend.ensure_project({
        id = common.project_id(root),
        root = vim.fs.normalize(root),
    }, callback)
end

---Resolve git metadata for a project root without blocking the main loop.
---Results are cached per root; concurrent callers share one probe.
---@param root string
---@param callback fun(info: { commit?: string, branch?: string })
local function git_info_async(root, callback)
    if vim.fn.executable('git') ~= 1 then
        vim.schedule(function()
            callback({})
        end)
        return
    end

    local cached = git_cache[root]
    if cached and not cached.pending then
        vim.schedule(function()
            callback({ commit = cached.commit, branch = cached.branch })
        end)
        return
    end
    if cached then
        cached.waiters[#cached.waiters + 1] = callback
        return
    end

    cached = { pending = true, waiters = { callback } }
    git_cache[root] = cached
    vim.system({ 'git', '-C', root, 'rev-parse', 'HEAD' }, { text = true }, function(commit_result)
        local branch_cmd = { 'git', '-C', root, 'branch', '--show-current' }
        vim.system(branch_cmd, { text = true }, function(branch_result)
            local commit = commit_result.code == 0 and vim.trim(commit_result.stdout or '') or nil
            local branch = branch_result.code == 0 and vim.trim(branch_result.stdout or '') or nil
            cached.pending = false
            cached.commit = commit ~= '' and commit or nil
            cached.branch = branch ~= '' and branch or nil
            local waiters = cached.waiters
            cached.waiters = {}
            vim.schedule(function()
                for _, waiter in ipairs(waiters) do
                    waiter({ commit = cached.commit, branch = cached.branch })
                end
            end)
        end)
    end)
end

---Mark a session row as written and flush its queued writes in FIFO order
---through the current backend. Queued writes flush even when the insert
---failed so failures surface through each write's callback instead of
---hanging silently.
---@param session_id string
---@param ok boolean whether the session row was written
local function mark_session_started(session_id, ok)
    local state = session_writes[session_id]
    if not state then
        return
    end
    state.started = true
    local backend = active_backend
    local queue = state.queue
    state.queue = {}
    if backend then
        for _, write in ipairs(queue) do
            write(backend)
        end
    end
    if not ok or state.finished then
        session_writes[session_id] = nil
    end
end

---Queue a session-dependent write behind the session row insert. Returns
---true when the write was queued (or dropped on overflow); the caller must
---then do nothing further. Returns false when no ordering is needed and the
---caller should write directly.
---@param session_id string
---@param write fun(backend: table) performs the backend write
---@param on_drop fun() called when the queue is full and the write is dropped
---@return boolean queued
local function enqueue_session_write(session_id, write, on_drop)
    local state = session_writes[session_id]
    if not state or state.started then
        return false
    end
    if #state.queue >= SESSION_QUEUE_MAX then
        on_drop()
        return true
    end
    state.queue[#state.queue + 1] = write
    return true
end

---@param spec DapStoreSessionSpec
---@param callback? fun(ok: boolean, session_id?: string)
---@return string
function M.session_start(spec, callback)
    assert(type(spec) == 'table', 'session spec must be a table')

    local root = vim.fs.normalize(spec.root or vim.fn.getcwd())
    local session_id = common.id(root .. tostring(spec.adapter or ''))
    local project_id = common.project_id(root)

    if not active_backend then
        if callback then
            callback(false, session_id)
        end
        return session_id
    end

    -- Register the session before any async work so events/finish queue
    -- behind the session row instead of racing it (foreign-key violation).
    session_writes[session_id] = { started = false, finished = false, queue = {} }

    ---@param git { commit?: string, branch?: string }
    local function write_session_row(git)
        active_backend.ensure_project({
            id = project_id,
            root = root,
        }, function(project_ok)
            if not project_ok then
                mark_session_started(session_id, false)
                if callback then
                    callback(false, session_id)
                end
                return
            end

            active_backend.session_start({
                id = session_id,
                project_id = project_id,
                host_name = common.hostname(),
                adapter = spec.adapter or 'unknown',
                configuration = spec.configuration,
                request = spec.request,
                executable = spec.executable,
                cwd = spec.cwd or root,
                git_commit = spec.git_commit or git.commit,
                git_branch = spec.git_branch or git.branch,
                metadata = spec.metadata or {},
            }, function(ok)
                mark_session_started(session_id, ok)
                if callback then
                    callback(ok, session_id)
                end
            end)
        end)
    end

    -- Skip the git probe when the spec already supplies both values.
    if spec.git_commit ~= nil and spec.git_branch ~= nil then
        write_session_row({ commit = spec.git_commit, branch = spec.git_branch })
    else
        git_info_async(root, write_session_row)
    end

    return session_id
end

---@param session_id string
---@param outcome? DapStoreOutcome
---@param callback? fun(ok: boolean, result?: vim.SystemCompleted)
function M.session_finish(session_id, outcome, callback)
    if not active_backend then
        if callback then
            callback(false)
        end
        return
    end

    local record = outcome or {}
    local function write(backend)
        backend.session_finish(session_id, record, function(ok, result)
            session_writes[session_id] = nil
            if callback then
                callback(ok, result)
            end
        end)
    end

    local state = session_writes[session_id]
    if state and not state.started then
        state.finished = true
        local queued = enqueue_session_write(session_id, write, function()
            if callback then
                callback(false)
            end
        end)
        if queued then
            return
        end
    end
    write(active_backend)
end

---@param session_id string
---@param event_type string
---@param payload? table
---@param callback? fun(ok: boolean, result?: vim.SystemCompleted)
function M.event(session_id, event_type, payload, callback)
    if not active_backend then
        if callback then
            callback(false)
        end
        return
    end

    local function write(backend)
        backend.event_append({
            session_id = session_id,
            event_type = event_type,
            payload = payload or {},
        }, callback)
    end

    local queued = enqueue_session_write(session_id, write, function()
        if callback then
            callback(false)
        end
    end)
    if queued then
        return
    end
    write(active_backend)
end

---@param root string
---@param breakpoint DapStoreBreakpointSpec
---@param callback? fun(ok: boolean, result?: vim.SystemCompleted)
function M.breakpoint(root, breakpoint, callback)
    if not active_backend then
        if callback then
            callback(false)
        end
        return
    end

    local project_id = common.project_id(root)
    local id_seed = table.concat({
        project_id,
        tostring(breakpoint.path or ''),
        tostring(breakpoint.line or 0),
        tostring(breakpoint.column_number or 0),
    }, '\0')

    active_backend.ensure_project({
        id = project_id,
        root = vim.fs.normalize(root),
    }, function(project_ok)
        if not project_ok then
            if callback then
                callback(false)
            end
            return
        end

        active_backend.breakpoint_put({
            id = vim.fn.sha256(id_seed):sub(1, 32),
            project_id = project_id,
            path = breakpoint.path,
            line = breakpoint.line,
            column_number = breakpoint.column_number,
            condition = breakpoint.condition,
            hit_condition = breakpoint.hit_condition,
            log_message = breakpoint.log_message,
            enabled = breakpoint.enabled,
        }, callback)
    end)
end

---@param metric DapStoreMetricSpec
---@param callback? fun(ok: boolean, result?: vim.SystemCompleted)
function M.metric(metric, callback)
    if not active_backend then
        if callback then
            callback(false)
        end
        return
    end

    active_backend.metric_put(metric, callback)
end

return M
