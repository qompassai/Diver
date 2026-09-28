-- ~/.config/nvim/lua/dap/store/postgresql.lua
local common = require('dap.store.common')
local schema = require('dap.store.schema')

local M = {}

---@class DapPostgresStoreOptions
---@field database? string PostgreSQL database name. Prefer PGDATABASE or PGSERVICE.
---@field service? string PostgreSQL service name from ~/.pg_service.conf.
---@field timeout? integer Milliseconds before a psql invocation is killed.
---@field env? table<string, string>

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

---Default per-query timeout in milliseconds.
---@type integer
local PG_TIMEOUT_DEFAULT_MS = 2000

---Hard upper bound for the per-query timeout in milliseconds.
---@type integer
local PG_TIMEOUT_MAX_MS = 30000

---@type DapPostgresStoreOptions
local options = {
    timeout = PG_TIMEOUT_DEFAULT_MS,
}

---@type boolean?
local available_cache

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

---@param callback? fun(ok: boolean, result?: vim.SystemCompleted)
local function unavailable(callback)
    fail_async(callback, 'psql is not executable')
end

---@return table<string, string>
local function process_env()
    local env = vim.fn.environ()

    if options.service and options.service ~= '' then
        env.PGSERVICE = options.service
    end

    if options.database and options.database ~= '' then
        env.PGDATABASE = options.database
    end

    for key, value in pairs(options.env or {}) do
        env[key] = value
    end

    return env
end

---@param sql string
---@param callback? fun(ok: boolean, result: vim.SystemCompleted)
function M.exec(sql, callback)
    assert(type(sql) == 'string' and sql ~= '', 'sql must be a non-empty string')

    if not M.available() then
        unavailable(callback)
        return
    end

    -- Clamp the configured timeout: a stuck psql must not outlive the bound.
    local timeout = math.min(options.timeout or PG_TIMEOUT_DEFAULT_MS, PG_TIMEOUT_MAX_MS)
    local done = false
    local timer = vim.uv.new_timer()
    local proc = vim.system({
        'psql',
        '-X',
        '--no-psqlrc',
        '--set',
        'ON_ERROR_STOP=1',
        '--quiet',
        '--tuples-only',
        '--no-align',
        '--field-separator',
        '\t',
    }, {
        text = true,
        stdin = sql,
        env = process_env(),
    }, function(result)
        if done then
            return
        end
        done = true
        if timer then
            timer:stop()
            timer:close()
        end
        if callback then
            vim.schedule(function()
                callback(result.code == 0, result)
            end)
        end
    end)

    -- The watchdog owns the process handle: on timeout it kills the query
    -- exactly once and reports failure; the completion callback above is
    -- then a no-op thanks to the `done` flag.
    if timer then
        timer:start(timeout, 0, function()
            if done then
                return
            end
            done = true
            proc:kill('sigterm')
            timer:stop()
            timer:close()
            fail_async(callback, 'psql query timed out after ' .. timeout .. 'ms')
        end)
    end
end

---@return boolean
function M.available()
    if available_cache == nil then
        available_cache = vim.fn.executable('psql') == 1
    end
    return available_cache
end

---@param opts? DapPostgresStoreOptions
---@param callback? fun(ok: boolean, error?: string)
function M.setup(opts, callback)
    -- Fresh defaults on every setup: a previous setup's options (database,
    -- service, timeout, env) must not leak into a later one.
    options = vim.tbl_deep_extend('force', { timeout = PG_TIMEOUT_DEFAULT_MS }, opts or {})
    available_cache = nil

    if not M.available() then
        if callback then
            callback(false, 'psql is not executable')
        end
        return
    end

    M.exec(schema.postgresql, function(ok, result)
        local err_msg = 'PostgreSQL schema initialization failed'
        local err = ok and nil or vim.trim(result.stderr or err_msg)
        if callback then
            callback(ok, err)
        end
    end)
end

---@param callback fun(ok: boolean, error?: string)
function M.health(callback)
    M.exec('SELECT 1;', function(ok, result)
        callback(ok, ok and nil or vim.trim(result.stderr or 'PostgreSQL health check failed'))
    end)
end

---@param project DapStoreProjectRecord
---@param callback? fun(ok: boolean, result?: vim.SystemCompleted)
function M.ensure_project(project, callback)
    local sql, err = build_sql(
        [[
INSERT INTO dap_projects (id, root)
VALUES (%s, %s)
ON CONFLICT (root)
DO UPDATE SET updated_at = now();
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
  %s, %s, %s, %s, %s::jsonb
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
SET ended_at = now(),
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
VALUES (%s, %s, %s::jsonb);
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
ON CONFLICT (project_id, path, line, column_number)
DO UPDATE SET
  condition = EXCLUDED.condition,
  hit_condition = EXCLUDED.hit_condition,
  log_message = EXCLUDED.log_message,
  enabled = EXCLUDED.enabled,
  updated_at = now();
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
            breakpoint.enabled ~= false,
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
VALUES (%s, %s, %s, %s, %s, %s::jsonb);
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
