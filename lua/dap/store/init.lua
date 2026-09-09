-- ~/.config/nvim/lua/dap/store/init.lua
local common = require('dap.store.common')

local M = {}

---@alias DapStoreBackend 'postgresql'|'sqlite'

---@class DapStoreOptions
---@field backend? DapStoreBackend
---@field fallback? DapStoreBackend|false
---@field postgresql? DapPostgresStoreOptions
---@field sqlite? DapSqliteStoreOptions

---@type DapStoreOptions
local options = {
    backend = 'postgresql',
    fallback = 'sqlite',
    postgresql = {},
    sqlite = {},
}

local active_backend = nil
local active_name = nil

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
    options = vim.tbl_deep_extend('force', options, opts or {})

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
        if fallback == false or fallback == preferred then
            if callback then
                callback(false, nil, err)
            end
            return
        end

        activate(fallback, function(fallback_ok, fallback_err)
            if callback then
                callback(fallback_ok, fallback_ok and fallback or nil, fallback_ok and err or fallback_err)
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

---@param spec table
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

    active_backend.ensure_project({
        id = project_id,
        root = root,
    }, function(project_ok)
        if not project_ok then
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
            git_commit = spec.git_commit or common.git_commit(root),
            git_branch = spec.git_branch or common.git_branch(root),
            metadata = spec.metadata or {},
        }, function(ok)
            if callback then
                callback(ok, session_id)
            end
        end)
    end)

    return session_id
end

---@param session_id string
---@param outcome? table
---@param callback? fun(ok: boolean, result?: vim.SystemCompleted)
function M.session_finish(session_id, outcome, callback)
    if not active_backend then
        if callback then
            callback(false)
        end
        return
    end

    active_backend.session_finish(session_id, outcome or {}, callback)
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

    active_backend.event_append({
        session_id = session_id,
        event_type = event_type,
        payload = payload or {},
    }, callback)
end

---@param root string
---@param breakpoint table
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

---@param metric table
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
