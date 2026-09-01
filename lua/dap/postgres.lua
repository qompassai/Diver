-- #################################################################
-- ~/.config/nvim/lua/dap/postgres.lua
-- Qompass AI Diver Native PostgreSQL PL/pgSQL Debug Configuration
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
---@source https://github.com/EnterpriseDB/pldebugger
---@source https://www.pgadmin.org/docs/pgadmin4/latest/developer_tools.html
---@source https://www.postgresql.org/docs/current/libpq-envars.html

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local levels = vim.log.levels
local uv = vim.uv

local M = {}

local SOURCE = "postgres-dap"

---@type string[]
local ROOT_MARKERS = {
  "flyway.conf",
  "liquibase.properties",
  "sqitch.conf",
  "migrations",
  "db",
  "database",
  "schema",
  ".pg_service.conf",
  ".git",
}

---@type string[]
local SQL_FILETYPES = {
  "sql",
  "pgsql",
  "postgresql",
}

---@class PostgresDapState
---@field adapter string?
---@field database string?
---@field root string?
---@field service string?
local state = {
  adapter = nil,
  database = nil,
  root = nil,
  service = nil,
}

---@param message string
---@param level? integer
local function notify(message, level)
  vim.notify(
    ("[%s] %s"):format(
      SOURCE,
      message
    ),
    level or levels.INFO
  )
end

---@param value unknown
---@return boolean
local function nonempty_string(value)
  return type(value) == "string"
    and value ~= ""
end

---@param path string
---@return boolean
local function executable(path)
  return nonempty_string(path)
    and fn.executable(path) == 1
end

---@param path string
---@return string
local function normalize(path)
  if path == "" then
    return ""
  end

  return fs.normalize(
    fn.fnamemodify(
      path,
      ":p"
    )
  )
end

---@param command string
---@return string?
local function executable_path(command)
  local path = fn.exepath(command)

  if not nonempty_string(path) then
    return nil
  end

  return fs.normalize(path)
end

---@param bufnr? integer
---@return string
local function filename(bufnr)
  bufnr = bufnr
    or api.nvim_get_current_buf()

  if not api.nvim_buf_is_valid(bufnr) then
    return ""
  end

  local name =
    api.nvim_buf_get_name(bufnr)

  if name == "" then
    return ""
  end

  return normalize(name)
end

---@param bufnr? integer
---@return string
local function project_root(bufnr)
  bufnr = bufnr
    or api.nvim_get_current_buf()

  local current = filename(bufnr)

  if current ~= "" then
    local detected = fs.root(
      current,
      ROOT_MARKERS
    )

    if
      type(detected) == "string"
      and detected ~= ""
    then
      return fs.normalize(detected)
    end

    local parent = fs.dirname(current)

    if
      type(parent) == "string"
      and parent ~= ""
    then
      return fs.normalize(parent)
    end
  end

  return fs.normalize(
    fn.getcwd()
  )
end

---@param command string[]
---@param cwd? string
---@param env? table<string, string>
---@return vim.SystemCompleted?
local function system(command, cwd, env)
  local ok, result = pcall(function()
    return vim.system(
      command,
      {
        cwd = cwd,

        env = env,

        text = true,
      }
    ):wait()
  end)

  if not ok then
    return nil
  end

  return result
end

---@return string?
local function resolve_psql()
  local configured =
    vim.env.NVIM_PSQL_EXECUTABLE

  if nonempty_string(configured) then
    local candidate = normalize(
      fn.expand(configured)
    )

    if executable(candidate) then
      return candidate
    end

    notify(
      ("NVIM_PSQL_EXECUTABLE is not executable: %s"):format(
        candidate
      ),
      levels.WARN
    )
  end

  return executable_path("psql")
end

---@return string?
local function resolve_adapter()
  if
    state.adapter ~= nil
    and executable(state.adapter)
  then
    return state.adapter
  end

  local configured =
    vim.env.NVIM_PGDAP_EXECUTABLE

  if nonempty_string(configured) then
    local candidate = normalize(
      fn.expand(configured)
    )

    if executable(candidate) then
      state.adapter = candidate

      return candidate
    end

    notify(
      ("NVIM_PGDAP_EXECUTABLE is not executable: %s"):format(
        candidate
      ),
      levels.WARN
    )
  end

  local candidate =
    executable_path("pgdap")

  if candidate ~= nil then
    state.adapter = candidate

    return candidate
  end

  return nil
end

---@return string
local function service()
  if nonempty_string(state.service) then
    return state.service
  end

  local configured =
    vim.env.NVIM_PGDAP_SERVICE
      or vim.env.PGSERVICE

  if nonempty_string(configured) then
    state.service = configured

    return configured
  end

  return ""
end

---@return string
local function database()
  if nonempty_string(state.database) then
    return state.database
  end

  local configured =
    vim.env.NVIM_PGDAP_DATABASE
      or vim.env.PGDATABASE

  if nonempty_string(configured) then
    state.database = configured

    return configured
  end

  return ""
end

---@return table<string, string>
local function connection_environment()
  local env = vim.fn.environ()

  --
  -- Keep libpq responsible for credentials.
  --
  -- This intentionally does not introduce PGPASSWORD or a password prompt.
  --
  local selected_service = service()

  if selected_service ~= "" then
    env.PGSERVICE = selected_service
  end

  local selected_database = database()

  if selected_database ~= "" then
    env.PGDATABASE = selected_database
  end

  if
    not nonempty_string(
      env.PGCONNECT_TIMEOUT
    )
  then
    env.PGCONNECT_TIMEOUT = "5"
  end

  return env
end

---@return string
local function current_file()
  local current = filename()

  if current ~= "" then
    return current
  end

  return "${file}"
end

---@return string
local function cwd()
  local root = project_root()

  state.root = root

  return root
end

---@param query string
---@return vim.SystemCompleted?
local function psql_query(query)
  local psql = resolve_psql()

  if psql == nil then
    notify(
      "psql was not found",
      levels.ERROR
    )

    return nil
  end

  return system(
    {
      psql,

      "-X",

      "--no-psqlrc",

      "--set",
      "ON_ERROR_STOP=1",

      "--tuples-only",

      "--no-align",

      "--quiet",

      "--command",
      query,
    },
    project_root(),
    connection_environment()
  )
end

---@return boolean
local function connection_available()
  local result = psql_query(
    "SELECT 1;"
  )

  return result ~= nil
    and result.code == 0
    and vim.trim(
      result.stdout or ""
    ) == "1"
end

---@return boolean
local function pldbgapi_installed()
  local result = psql_query(
    [[
SELECT EXISTS (
  SELECT 1
  FROM pg_extension
  WHERE extname = 'pldbgapi'
);
]]
  )

  if
    result == nil
    or result.code ~= 0
  then
    return false
  end

  local value =
    vim.trim(
      result.stdout or ""
    )

  return value == "t"
    or value == "true"
end

---@return boolean
local function debugger_preloaded()
  local result = psql_query(
    [[
SELECT
  current_setting(
    'shared_preload_libraries',
    true
  );
]]
  )

  if
    result == nil
    or result.code ~= 0
  then
    return false
  end

  local libraries =
    vim.trim(
      result.stdout or ""
    )

  return libraries:find(
    "plugin_debugger",
    1,
    true
  ) ~= nil
end

---@return string?
local function server_version()
  local result = psql_query(
    "SHOW server_version;"
  )

  if
    result == nil
    or result.code ~= 0
  then
    return nil
  end

  local value =
    vim.trim(
      result.stdout or ""
    )

  if value == "" then
    return nil
  end

  return value
end

---@return integer?
local function server_pid()
  local result = psql_query(
    "SELECT pg_backend_pid();"
  )

  if
    result == nil
    or result.code ~= 0
  then
    return nil
  end

  local pid =
    tonumber(
      vim.trim(
        result.stdout or ""
      )
    )

  if pid == nil then
    return nil
  end

  return math.floor(pid)
end

---@return string
local function prompt_service()
  local selected = fn.input(
    "PostgreSQL service: ",
    service()
  )

  state.service = selected

  return selected
end

---@return string
local function prompt_database()
  local selected = fn.input(
    "PostgreSQL database: ",
    database()
  )

  state.database = selected

  return selected
end

---@return string
local function prompt_function()
  return fn.input(
    "PL/pgSQL function signature: ",
    "public."
  )
end

---@return string
local function prompt_procedure()
  return fn.input(
    "PL/pgSQL procedure signature: ",
    "public."
  )
end

---@return string[]
local function prompt_arguments()
  local input = fn.input(
    "Function arguments: "
  )

  if input == "" then
    return {}
  end

  return fn.shellsplit(input)
end

---@return integer
local function prompt_target_pid()
  local value = fn.input(
    "PostgreSQL target backend PID: "
  )

  local pid = tonumber(value)

  if
    pid == nil
    or pid < 1
  then
    notify(
      ("invalid PostgreSQL PID: %s"):format(
        value
      ),
      levels.ERROR
    )

    return 0
  end

  return math.floor(pid)
end

---@return string
local function prompt_schema()
  local value = fn.input(
    "PostgreSQL schema: ",
    "public"
  )

  if value == "" then
    return "public"
  end

  return value
end

---@return string
local function prompt_expression()
  return fn.input(
    "PL/pgSQL expression: "
  )
end

---@return string
local function prompt_variable()
  return fn.input(
    "PL/pgSQL variable: "
  )
end

---@return string
local function prompt_variable_value()
  return fn.input(
    "New variable value: "
  )
end

local function select_adapter()
  local selected = fn.input(
    "PostgreSQL DAP adapter: ",
    resolve_adapter() or "",
    "file"
  )

  if selected == "" then
    return
  end

  selected = normalize(
    fn.expand(selected)
  )

  if not executable(selected) then
    notify(
      ("not executable: %s"):format(
        selected
      ),
      levels.ERROR
    )

    return
  end

  state.adapter = selected

  if type(M.adapter) == "table" then
    M.adapter.command = selected
  end

  notify(
    ("PostgreSQL DAP adapter: %s"):format(
      selected
    )
  )
end

local function select_service()
  local selected = prompt_service()

  if selected == "" then
    notify(
      "PostgreSQL service selection cleared"
    )

    return
  end

  notify(
    ("PostgreSQL service: %s"):format(
      selected
    )
  )
end

local function select_database()
  local selected = prompt_database()

  if selected == "" then
    notify(
      "PostgreSQL database selection cleared"
    )

    return
  end

  notify(
    ("PostgreSQL database: %s"):format(
      selected
    )
  )
end

local function list_debuggable_functions()
  local result = psql_query(
    [[
SELECT
  format(
    '%I.%I(%s)',
    n.nspname,
    p.proname,
    pg_get_function_identity_arguments(p.oid)
  )
FROM pg_proc AS p
JOIN pg_namespace AS n
  ON n.oid = p.pronamespace
JOIN pg_language AS l
  ON l.oid = p.prolang
WHERE l.lanname = 'plpgsql'
ORDER BY
  n.nspname,
  p.proname;
]]
  )

  if result == nil then
    return
  end

  if result.code ~= 0 then
    notify(
      vim.trim(
        result.stderr
          or "failed to query PL/pgSQL functions"
      ),
      levels.ERROR
    )

    return
  end

  local output =
    vim.trim(
      result.stdout or ""
    )

  if output == "" then
    notify(
      "no PL/pgSQL functions found"
    )

    return
  end

  notify(output)
end

local function show_proxy_info()
  if not pldbgapi_installed() then
    notify(
      "pldbgapi is not installed in the selected database",
      levels.WARN
    )

    return
  end

  local result = psql_query(
    [[
SELECT *
FROM pldbg_get_proxy_info();
]]
  )

  if result == nil then
    return
  end

  local output =
    vim.trim(
      result.stdout
        or result.stderr
        or ""
    )

  if output == "" then
    output =
      "no pldbg proxy information returned"
  end

  notify(
    output,
    result.code == 0
        and levels.INFO
      or levels.ERROR
  )
end

local function open_psql()
  local psql = resolve_psql()

  if psql == nil then
    notify(
      "psql was not found",
      levels.ERROR
    )

    return
  end

  vim.cmd(
    "botright new"
  )

  local buffer =
    api.nvim_get_current_buf()

  vim.bo[buffer].bufhidden =
    "wipe"

  local job = fn.termopen(
    {
      psql,
      "-X",
    },
    {
      cwd = project_root(),

      env = connection_environment(),
    }
  )

  if job <= 0 then
    notify(
      "failed to start psql",
      levels.ERROR
    )

    return
  end

  vim.cmd(
    "startinsert"
  )
end

local function clear_cache()
  state.adapter = nil
  state.database = nil
  state.root = nil
  state.service = nil

  notify(
    "PostgreSQL DAP discovery cache cleared"
  )
end

local function status()
  local psql = resolve_psql()
  local adapter = resolve_adapter()

  local connected =
    psql ~= nil
      and connection_available()

  local extension =
    connected
      and pldbgapi_installed()

  local preload =
    connected
      and debugger_preloaded()

  notify(
    table.concat({
      "root: "
        .. project_root(),

      "psql: "
        .. (psql or "not found"),

      "service: "
        .. (
          service() ~= ""
              and service()
            or "default libpq resolution"
        ),

      "database: "
        .. (
          database() ~= ""
              and database()
            or "default libpq resolution"
        ),

      "connection: "
        .. (
          connected
              and "available"
            or "unavailable"
        ),

      "server version: "
        .. (
          connected
              and (
                server_version()
                  or "unknown"
              )
            or "unknown"
        ),

      "pldbgapi: "
        .. (
          extension
              and "installed"
            or "not detected"
        ),

      "plugin_debugger preload: "
        .. (
          preload
              and "detected"
            or "not detected"
        ),

      "pgdap: "
        .. (
          adapter
            or "not found"
        ),

      "DAP: "
        .. (
          adapter ~= nil
              and extension
              and "available"
            or "unavailable"
        ),
    }, "\n"),
    (
      connected
      and extension
      and adapter ~= nil
    )
        and levels.INFO
      or levels.WARN
  )
end

--
-- IMPORTANT:
--
-- PostgreSQL currently provides pldbgapi, not a standard DAP server.
--
-- This descriptor expects a standalone `pgdap` bridge implementing DAP over
-- stdin/stdout and translating requests into the pldbgapi API.
--
-- Expected bridge responsibilities include:
--
--   DAP setBreakpoints -> pldbg_set_breakpoint()
--   DAP continue       -> pldbg_continue()
--   DAP next           -> pldbg_step_over()
--   DAP stepIn         -> pldbg_step_into()
--   DAP stackTrace     -> pldbg_get_stack()
--   DAP scopes         -> current selected PL/pgSQL frame
--   DAP variables      -> pldbg_get_variables()
--   DAP setVariable    -> pldbg_deposit_value()
--   DAP disconnect     -> pldbg_abort_target()
--
-- pldbgapi itself does not currently expose a dedicated step-out primitive;
-- a bridge must implement DAP stepOut conservatively using stack state and
-- continue/step operations.
--
---@type table
M.adapter = {
  name = "postgres",

  type = "executable",

  command =
    resolve_adapter()
      or "pgdap",

  args = {
    "--stdio",
  },

  options = {
    source_filetype = "sql",
  },
}

---@type table[]
local configurations = {
  --
  -- Direct debugging:
  --
  -- The bridge starts the selected PL/pgSQL routine and owns both the proxy
  -- and target-side database connections.
  --
  {
    name =
      "PostgreSQL: Debug Function",

    type = "postgres",

    request = "launch",

    mode = "function",

    service = service,

    database = database,

    functionName =
      prompt_function,

    args =
      prompt_arguments,

    sourceFile =
      current_file,

    cwd = cwd,

    stopOnEntry = true,
  },

  {
    name =
      "PostgreSQL: Debug Procedure",

    type = "postgres",

    request = "launch",

    mode = "procedure",

    service = service,

    database = database,

    procedureName =
      prompt_procedure,

    args =
      prompt_arguments,

    sourceFile =
      current_file,

    cwd = cwd,

    stopOnEntry = true,
  },

  {
    name =
      "PostgreSQL: Debug Function Without Entry Stop",

    type = "postgres",

    request = "launch",

    mode = "function",

    service = service,

    database = database,

    functionName =
      prompt_function,

    args =
      prompt_arguments,

    sourceFile =
      current_file,

    cwd = cwd,

    stopOnEntry = false,
  },

  --
  -- Global/in-context debugging:
  --
  -- The bridge establishes the global breakpoint through pldbgapi and waits
  -- for another PostgreSQL backend (web request, job worker, application,
  -- another psql session, etc.) to invoke the routine.
  --
  {
    name =
      "PostgreSQL: Attach Global Breakpoint",

    type = "postgres",

    request = "attach",

    mode = "global",

    service = service,

    database = database,

    functionName =
      prompt_function,

    sourceFile =
      current_file,

    targetPid = 0,

    stopOnEntry = true,
  },

  {
    name =
      "PostgreSQL: Attach Global Breakpoint to Backend PID",

    type = "postgres",

    request = "attach",

    mode = "global",

    service = service,

    database = database,

    functionName =
      prompt_function,

    sourceFile =
      current_file,

    targetPid =
      prompt_target_pid,

    stopOnEntry = true,
  },

  --
  -- Schema-targeted routine resolution is useful when the local file does not
  -- contain a directly resolvable CREATE FUNCTION/PROCEDURE statement.
  --
  {
    name =
      "PostgreSQL: Debug Function by Schema",

    type = "postgres",

    request = "launch",

    mode = "function",

    service = service,

    database = database,

    schema =
      prompt_schema,

    functionName =
      prompt_function,

    args =
      prompt_arguments,

    sourceFile =
      current_file,

    cwd = cwd,

    stopOnEntry = true,
  },
}

---@type table<string, table[]>
M.configurations = {
  sql = configurations,

  pgsql = configurations,

  postgresql = configurations,
}

---@type table<string, DebugCommand>
M.commands = {
  PostgresDebugAdapter = {
    callback = function()
      select_adapter()
    end,

    desc =
      "Select PostgreSQL DAP bridge",
  },

  PostgresDebugClear = {
    callback = function()
      clear_cache()
    end,

    desc =
      "Clear PostgreSQL debugger discovery cache",
  },

  PostgresDebugDatabase = {
    callback = function()
      select_database()
    end,

    desc =
      "Select PostgreSQL database",
  },

  PostgresDebugFunctions = {
    callback = function()
      list_debuggable_functions()
    end,

    desc =
      "List PL/pgSQL functions",
  },

  PostgresDebugProxy = {
    callback = function()
      show_proxy_info()
    end,

    desc =
      "Show pldbgapi proxy information",
  },

  PostgresDebugPsql = {
    callback = function()
      open_psql()
    end,

    desc =
      "Open psql for current PostgreSQL connection",
  },

  PostgresDebugService = {
    callback = function()
      select_service()
    end,

    desc =
      "Select PostgreSQL libpq service",
  },

  PostgresDebugStatus = {
    callback = function()
      status()
    end,

    desc =
      "Show PostgreSQL debugger status",
  },
}

---@type table<string, DebugMapping>
M.mappings = {
  postgres_debug_database = {
    lhs = "<leader>dPd",

    mode = "n",

    rhs = function()
      select_database()
    end,

    desc =
      "Debug PostgreSQL: Database",
  },

  postgres_debug_functions = {
    lhs = "<leader>dPf",

    mode = "n",

    rhs = function()
      list_debuggable_functions()
    end,

    desc =
      "Debug PostgreSQL: Functions",
  },

  postgres_debug_psql = {
    lhs = "<leader>dPp",

    mode = "n",

    rhs = function()
      open_psql()
    end,

    desc =
      "Debug PostgreSQL: psql",
  },

  postgres_debug_service = {
    lhs = "<leader>dPs",

    mode = "n",

    rhs = function()
      select_service()
    end,

    desc =
      "Debug PostgreSQL: Service",
  },

  postgres_debug_status = {
    lhs = "<leader>dPS",

    mode = "n",

    rhs = function()
      status()
    end,

    desc =
      "Debug PostgreSQL: Status",
  },
}

---@param opts? table
function M.setup(opts)
  opts = opts or {}

  state.root =
    nonempty_string(opts.root)
        and fs.normalize(opts.root)
      or project_root()

  local adapter = resolve_adapter()

  if adapter ~= nil then
    M.adapter.command = adapter
  end

  if resolve_psql() == nil then
    vim.schedule(function()
      notify(
        table.concat({
          "psql was not found.",

          "",

          "Install the PostgreSQL client or set:",

          "  NVIM_PSQL_EXECUTABLE=/path/to/psql",
        }, "\n"),
        levels.WARN
      )
    end)
  end

  if adapter == nil then
    vim.schedule(function()
      notify(
        table.concat({
          "No PostgreSQL DAP bridge was found.",

          "",

          "pldbgapi itself is not a DAP server.",

          "For vim.debug sessions, install a compatible `pgdap`",
          "bridge or set:",

          "  NVIM_PGDAP_EXECUTABLE=/path/to/pgdap",

          "",

          "psql/pldbgapi health and discovery commands remain usable.",
        }, "\n"),
        levels.DEBUG
      )
    end)
  end
end

---@return string?
function M.adapter_path()
  return resolve_adapter()
end

---@return string?
function M.psql()
  return resolve_psql()
end

---@return string
function M.root()
  return project_root()
end

---@return boolean
function M.connection_available()
  return connection_available()
end

---@return boolean
function M.pldbgapi_available()
  return pldbgapi_installed()
end

---@return boolean
function M.available()
  return resolve_adapter() ~= nil
    and connection_available()
    and pldbgapi_installed()
end

return M