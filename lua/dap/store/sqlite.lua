-- ~/.config/nvim/lua/dap/store/sqlite.lua
local common = require('dap.store.common')
local schema = require('dap.store.schema')

local M = {}

---@class DapSqliteStoreOptions
---@field path? string

---@class DapStoreProjectRecord
---@field id string
---@field root string

---@class DapStoreSessionRecord
---@field id string
---@field project_id string
---@field host_name string
---@field adapter string
---@field configuration? string
---@field request? string
---@field executable? string
---@field cwd? string
---@field git_commit? string
---@field git_branch? string
---@field metadata? table

---@class DapStoreOutcomeRecord
---@field exit_code? integer
---@field result? string

---@class DapStoreEventRecord
---@field session_id string
---@field event_type string
---@field payload? table

---@class DapStoreBreakpointRecord
---@field id string
---@field project_id string
---@field path string
---@field line integer
---@field column_number? integer
---@field condition? string
---@field hit_condition? string
---@field log_message? string
---@field enabled? boolean

---@class DapStoreMetricRecord
---@field session_id string
---@field adapter string
---@field metric_name string
---@field metric_value number
---@field unit? string
---@field metadata? table

---@type DapSqliteStoreOptions
local options = {}

---@type boolean?
local available_cache

---@return string
local function database_path()
    local configured = options.path or vim.env.DIVER_DAP_SQLITE_DATABASE

    if configured and configured ~= '' then
        return vim.fs.normalize(configured)
    end

    return vim.fs.joinpath(vim.fn.stdpath('state'), 'dap', 'dap.sqlite3')
end

---Encode positional values for a SQL template: plain values via
---common.literal, values at `json_indexes` via common.json. Aborts with
---nil and an error instead of formatting a corrupt query.
---@param template string SQL template with %s placeholders
---@param values unknown[] positional values
---@param json_indexes? table<integer, boolean> positions to JSON-encode
---@return string? sql
---@return string? err
local function build_sql(template, values, json_indexes)
    local literals = {}
    for i, value in ipairs(values) do
        local encoded, err
        if json_indexes and json_indexes[i] then
            encoded, err = common.json(value)
        else
            encoded, err = common.literal(value)
        end
        if encoded == nil then
            return nil, err
        end
        literals[i] = encoded
    end
    return template:format(table.unpack(literals))
end

---@param callback? fun(ok: boolean, result: vim.SystemCompleted)
---@param err string
local function fail_async(callback, err)
    if callback then
        vim.schedule(function()
            callback(false, {
                code = 1,
                signal = 0,
                stdout = '',
                stderr = err,
            })
        end)
    end
end

---@param sql string
---@param callback? fun(ok: boolean, result: vim.SystemCompleted)
function M.exec(sql, callback)
    assert(type(sql) == 'string' and sql ~= '', 'sql must be a non-empty string')

    if not M.available() then
        fail_async(callback, 'sqlite3 is not executable')
        return
    end

    -- Every invocation is a fresh process: re-establish the per-connection
    -- PRAGMAs (foreign keys, WAL, timeouts) via -cmd before the query runs.
    local command = {
        'sqlite3',
        '-batch',
        '-noheader',
        '-separator',
        '\t',
    }
    for _, pragma in ipairs(schema.sqlite_connection_pragmas) do
        command[#command + 1] = '-cmd'
        command[#command + 1] = pragma
    end
    command[#command + 1] = database_path()

    vim.system(command, {
        text = true,
        stdin = sql,
    }, function(result)
        if callback then
            vim.schedule(function()
                callback(result.code == 0, result)
            end)
        end
    end)
end

---@return boolean
function M.available()
    if available_cache == nil then
        available_cache = vim.fn.executable('sqlite3') == 1
    end
    return available_cache
end

---@param opts? DapSqliteStoreOptions
---@param callback? fun(ok: boolean, error?: string)
function M.setup(opts, callback)
    -- Fresh defaults on every setup: a previous setup's path must not leak
    -- into a later one.
    options = vim.tbl_deep_extend('force', {}, opts or {})
    available_cache = nil

    if not M.available() then
        if callback then
            callback(false, 'sqlite3 is not executable')
        end
        return
    end

    -- Create the database directory once here; M.exec assumes setup ran.
    vim.fn.mkdir(vim.fs.dirname(database_path()), 'p')

    M.exec(schema.sqlite, function(ok, result)
        local err = ok and nil or vim.trim(result.stderr or 'SQLite schema initialization failed')
        if callback then
            callback(ok, err)
        end
    end)
end

---@param callback fun(ok: boolean, error?: string)
function M.health(callback)
    M.exec('SELECT 1;', function(ok, result)
        callback(ok, ok and nil or vim.trim(result.stderr or 'SQLite health check failed'))
    end)
end

---@param project DapStoreProjectRecord
---@param callback? fun(ok: boolean, result?: vim.SystemCompleted)
function M.ensure_project(project, callback)
    local sql, err = build_sql(
        [[
INSERT INTO dap_projects (id, root)
VALUES (%s, %s)
ON CONFLICT(root)
DO UPDATE SET updated_at = CURRENT_TIMESTAMP;
]],
        { project.id, project.root }
    )
    if not sql then
        fail_async(callback, err or 'failed to build query')
        return
    end

    M.exec(sql, callback)
end

---@param session DapStoreSessionRecord
---@param callback? fun(ok: boolean, result?: vim.SystemCompleted)
function M.session_start(session, callback)
    local sql, err = build_sql(
        [[
INSERT INTO dap_sessions (
  id, project_id, host_name, adapter, configuration, request,
  executable, cwd, git_commit, git_branch, metadata
)
VALUES (
  %s, %s, %s, %s, %s, %s,
  %s, %s, %s, %s, %s
);
]],
        {
            session.id,
            session.project_id,
            session.host_name,
            session.adapter,
            session.configuration,
            session.request,
            session.executable,
            session.cwd,
            session.git_commit,
            session.git_branch,
            session.metadata,
        },
        { [11] = true }
    )
    if not sql then
        fail_async(callback, err or 'failed to build query')
        return
    end

    M.exec(sql, callback)
end

---@param session_id string
---@param outcome DapStoreOutcomeRecord
---@param callback? fun(ok: boolean, result?: vim.SystemCompleted)
function M.session_finish(session_id, outcome, callback)
    local sql, err = build_sql(
        [[
UPDATE dap_sessions
SET ended_at = CURRENT_TIMESTAMP,
    exit_code = %s,
    result = %s
WHERE id = %s;
]],
        { outcome.exit_code, outcome.result, session_id }
    )
    if not sql then
        fail_async(callback, err or 'failed to build query')
        return
    end

    M.exec(sql, callback)
end

---@param event DapStoreEventRecord
---@param callback? fun(ok: boolean, result?: vim.SystemCompleted)
function M.event_append(event, callback)
    local sql, err = build_sql(
        [[
INSERT INTO dap_events (session_id, event_type, payload)
VALUES (%s, %s, %s);
]],
        { event.session_id, event.event_type, event.payload },
        { [3] = true }
    )
    if not sql then
        fail_async(callback, err or 'failed to build query')
        return
    end

    M.exec(sql, callback)
end

---@param breakpoint DapStoreBreakpointRecord
---@param callback? fun(ok: boolean, result?: vim.SystemCompleted)
function M.breakpoint_put(breakpoint, callback)
    local sql, err = build_sql(
        [[
INSERT INTO dap_breakpoints (
  id, project_id, path, line, column_number,
  condition, hit_condition, log_message, enabled
)
VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
ON CONFLICT(project_id, path, line, column_number)
DO UPDATE SET
  condition = excluded.condition,
  hit_condition = excluded.hit_condition,
  log_message = excluded.log_message,
  enabled = excluded.enabled,
  updated_at = CURRENT_TIMESTAMP;
]],
        {
            breakpoint.id,
            breakpoint.project_id,
            breakpoint.path,
            breakpoint.line,
            breakpoint.column_number,
            breakpoint.condition,
            breakpoint.hit_condition,
            breakpoint.log_message,
            breakpoint.enabled ~= false and 1 or 0,
        }
    )
    if not sql then
        fail_async(callback, err or 'failed to build query')
        return
    end

    M.exec(sql, callback)
end

---@param metric DapStoreMetricRecord
---@param callback? fun(ok: boolean, result?: vim.SystemCompleted)
function M.metric_put(metric, callback)
    local sql, err = build_sql(
        [[
INSERT INTO dap_adapter_metrics (
  session_id, adapter, metric_name, metric_value, unit, metadata
)
VALUES (%s, %s, %s, %s, %s, %s);
]],
        {
            metric.session_id,
            metric.adapter,
            metric.metric_name,
            metric.metric_value,
            metric.unit,
            metric.metadata,
        },
        { [6] = true }
    )
    if not sql then
        fail_async(callback, err or 'failed to build query')
        return
    end

    M.exec(sql, callback)
end

return M
