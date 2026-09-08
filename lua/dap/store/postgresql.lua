.../dap/store $ cat postgresql.lua
-- ~/.config/nvim/lua/dap/store/postgresql.lua
local common = require('dap.store.common')
local schema = require('dap.store.schema')

local M = {}

---@class DapPostgresStoreOptions
---@field database? string PostgreSQL database name. Prefer PGDATABASE or PGSERVICE.
---@field service? string PostgreSQL service name from ~/.pg_service.conf.
---@field timeout? integer Milliseconds for synchronous health checks.
---@field env? table<string, string>

---@type DapPostgresStoreOptions
local options = {
  timeout = 2000,
}

---@param callback? fun(ok: boolean, result?: vim.SystemCompleted)
local function unavailable(callback)
  if callback then
    vim.schedule(function()
      callback(false, {
        code = 127,
        signal = 0,
        stdout = '',
        stderr = 'psql is not executable',
      })
    end)
  end
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

  if vim.fn.executable('psql') ~= 1 then
    unavailable(callback)
    return
  end

  vim.system({
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
    if callback then
      vim.schedule(function()
        callback(result.code == 0, result)
      end)
    end
  end)
end

---@return boolean
function M.available()
  return vim.fn.executable('psql') == 1
end

---@param opts? DapPostgresStoreOptions
---@param callback? fun(ok: boolean, error?: string)
function M.setup(opts, callback)
  options = vim.tbl_deep_extend('force', options, opts or {})

  if not M.available() then
    if callback then
      callback(false, 'psql is not executable')
    end
    return
  end

  M.exec(schema.postgresql, function(ok, result)
    if callback then
      callback(ok, ok and nil or vim.trim(result.stderr or 'PostgreSQL schema initialization failed'))
    end
  end)
end

---@param callback fun(ok: boolean, error?: string)
function M.health(callback)
  M.exec('SELECT 1;', function(ok, result)
    callback(ok, ok and nil or vim.trim(result.stderr or 'PostgreSQL health check failed'))
  end)
end

---@param project table
---@param callback? fun(ok: boolean, result?: vim.SystemCompleted)
function M.ensure_project(project, callback)
  local sql = ([[
INSERT INTO dap_projects (id, root)
VALUES (%s, %s)
ON CONFLICT (root)
DO UPDATE SET updated_at = now();
]]):format(
    common.literal(project.id),
    common.literal(project.root)
  )

  M.exec(sql, callback)
end

---@param session table
---@param callback? fun(ok: boolean, result?: vim.SystemCompleted)
function M.session_start(session, callback)
  local sql = ([[
INSERT INTO dap_sessions (
  id, project_id, host_name, adapter, configuration, request,
  executable, cwd, git_commit, git_branch, metadata
)
VALUES (
  %s, %s, %s, %s, %s, %s,
  %s, %s, %s, %s, %s::jsonb
);
]]):format(
    common.literal(session.id),
    common.literal(session.project_id),
    common.literal(session.host_name),
    common.literal(session.adapter),
    common.literal(session.configuration),
    common.literal(session.request),
    common.literal(session.executable),
    common.literal(session.cwd),
    common.literal(session.git_commit),
    common.literal(session.git_branch),
    common.json(session.metadata)
  )

  M.exec(sql, callback)
end

---@param session_id string
---@param outcome table
---@param callback? fun(ok: boolean, result?: vim.SystemCompleted)
function M.session_finish(session_id, outcome, callback)
  local sql = ([[
UPDATE dap_sessions
SET ended_at = now(),
    exit_code = %s,
    result = %s
WHERE id = %s;
]]):format(
    common.literal(outcome.exit_code),
    common.literal(outcome.result),
    common.literal(session_id)
  )

  M.exec(sql, callback)
end

---@param event table
---@param callback? fun(ok: boolean, result?: vim.SystemCompleted)
function M.event_append(event, callback)
  local sql = ([[
INSERT INTO dap_events (session_id, event_type, payload)
VALUES (%s, %s, %s::jsonb);
]]):format(
    common.literal(event.session_id),
    common.literal(event.event_type),
    common.json(event.payload)
  )

  M.exec(sql, callback)
end

---@param breakpoint table
---@param callback? fun(ok: boolean, result?: vim.SystemCompleted)
function M.breakpoint_put(breakpoint, callback)
  local sql = ([[
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
]]):format(
    common.literal(breakpoint.id),
    common.literal(breakpoint.project_id),
    common.literal(breakpoint.path),
    common.literal(breakpoint.line),
    common.literal(breakpoint.column_number),
    common.literal(breakpoint.condition),
    common.literal(breakpoint.hit_condition),
    common.literal(breakpoint.log_message),
    common.literal(breakpoint.enabled ~= false)
  )

  M.exec(sql, callback)
end

---@param metric table
---@param callback? fun(ok: boolean, result?: vim.SystemCompleted)
function M.metric_put(metric, callback)
  local sql = ([[
INSERT INTO dap_adapter_metrics (
  session_id, adapter, metric_name, metric_value, unit, metadata
)
VALUES (%s, %s, %s, %s, %s, %s::jsonb);
]]):format(
    common.literal(metric.session_id),
    common.literal(metric.adapter),
    common.literal(metric.metric_name),
    common.literal(metric.metric_value),
    common.literal(metric.unit),
    common.json(metric.metadata)
  )

  M.exec(sql, callback)
end

return M