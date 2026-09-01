-- #################################################################
-- ~/.config/nvim/lua/dap/sql.lua
-- Qompass AI Diver Native SQL Debug / Inspection Configuration
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
---@source https://www.postgresql.org/docs/current/sql-explain.html
---@source https://www.sqlite.org/lang_explain.html
---@source https://sqlite.org/eqp.html
---@source https://sqlite.org/profile.html

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local levels = vim.log.levels
local uv = vim.uv

local M = {}

local SOURCE = 'sql-debug'

---@alias SqlDebugBackend
---| "auto"
---| "generic"
---| "postgres"
---| "sqlite"

---@type string[]
local ROOT_MARKERS = {
  'flyway.conf',
  'liquibase.properties',
  'sqitch.conf',
  'migrations',
  'schema',
  'database',
  'db',
  'flake.nix',
  '.git',
}

---@type string[]
local SQLITE_EXTENSIONS = {
  '.db',
  '.db3',
  '.sqlite',
  '.sqlite3',
}

---@type table<string, boolean>
local POSTGRES_FILETYPES = {
  pgsql = true,
  postgresql = true,
}

---@type table<string, boolean>
local MUTATING_KEYWORDS = {
  ALTER = true,
  CALL = true,
  CREATE = true,
  DELETE = true,
  DROP = true,
  GRANT = true,
  INSERT = true,
  MERGE = true,
  REINDEX = true,
  REPLACE = true,
  REVOKE = true,
  TRUNCATE = true,
  UPDATE = true,
  VACUUM = true,
}

---@class SqlDebugState
---@field backend SqlDebugBackend
---@field root string?
---@field sqlite_database string?
local state = {
  backend = 'auto',
  root = nil,
  sqlite_database = nil,
}

---@param message string
---@param level? integer
local function notify(message, level)
  vim.notify(('[%s] %s'):format(SOURCE, message), level or levels.INFO)
end

---@param value unknown
---@return boolean
local function callable(value)
  return type(value) == 'function'
end

---@param value unknown
---@return boolean
local function nonempty_string(value)
  return type(value) == 'string' and value ~= ''
end

---@param path string
---@return boolean
local function is_file(path)
  if not nonempty_string(path) then
    return false
  end

  local stat = uv.fs_stat(path)

  return stat ~= nil and stat.type == 'file'
end

---@param path string
---@return boolean
local function is_directory(path)
  if not nonempty_string(path) then
    return false
  end

  local stat = uv.fs_stat(path)

  return stat ~= nil and stat.type == 'directory'
end

---@param path string
---@return boolean
local function executable(path)
  return nonempty_string(path) and fn.executable(path) == 1
end

---@param path string
---@return string
local function normalize(path)
  if path == '' then
    return ''
  end

  return fs.normalize(fn.fnamemodify(path, ':p'))
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
  bufnr = bufnr or api.nvim_get_current_buf()

  if not api.nvim_buf_is_valid(bufnr) then
    return ''
  end

  local name = api.nvim_buf_get_name(bufnr)

  if name == '' then
    return ''
  end

  return normalize(name)
end

---@param bufnr? integer
---@return string
local function filetype(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()

  if not api.nvim_buf_is_valid(bufnr) then
    return ''
  end

  return vim.bo[bufnr].filetype
end

---@param bufnr? integer
---@return string
local function project_root(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()

  local current = filename(bufnr)

  if current ~= '' then
    local detected = fs.root(current, ROOT_MARKERS)

    if type(detected) == 'string' and detected ~= '' then
      return fs.normalize(detected)
    end

    local parent = fs.dirname(current)

    if type(parent) == 'string' and parent ~= '' then
      return fs.normalize(parent)
    end
  end

  return fs.normalize(fn.getcwd())
end

---@param value string
---@param suffix string
---@return boolean
local function ends_with(value, suffix)
  return #value >= #suffix and value:sub(-#suffix) == suffix
end

---@param path string
---@return boolean
local function sqlite_filename(path)
  local lower = path:lower()

  for _, extension in ipairs(SQLITE_EXTENSIONS) do
    if ends_with(lower, extension) then
      return true
    end
  end

  return false
end

---@param root string
---@return string[]
local function sqlite_databases(root)
  if not is_directory(root) then
    return {}
  end

  ---@type string[]
  local result = {}

  for name, kind in fs.dir(root) do
    if kind == 'file' and sqlite_filename(name) then
      result[#result + 1] = fs.normalize(fs.joinpath(root, name))
    end
  end

  table.sort(result)

  return result
end

---@return string?
local function resolve_psql()
  local configured = vim.env.NVIM_PSQL_EXECUTABLE

  if nonempty_string(configured) then
    local candidate = normalize(fn.expand(configured))

    if executable(candidate) then
      return candidate
    end
  end

  return executable_path('psql')
end

---@return string?
local function resolve_sqlite()
  local configured = vim.env.NVIM_SQLITE_EXECUTABLE

  if nonempty_string(configured) then
    local candidate = normalize(fn.expand(configured))

    if executable(candidate) then
      return candidate
    end
  end

  return executable_path('sqlite3')
end

---@return string?
local function configured_sqlite_database()
  local configured = vim.env.NVIM_SQLITE_DATABASE

  if not nonempty_string(configured) then
    return nil
  end

  local candidate = normalize(fn.expand(configured))

  if is_file(candidate) then
    return candidate
  end

  return nil
end

---@return string?
local function resolve_sqlite_database()
  if state.sqlite_database ~= nil and is_file(state.sqlite_database) then
    return state.sqlite_database
  end

  local configured = configured_sqlite_database()

  if configured ~= nil then
    state.sqlite_database = configured

    return configured
  end

  local candidates = sqlite_databases(project_root())

  if #candidates == 1 then
    state.sqlite_database = candidates[1]

    return candidates[1]
  end

  return nil
end

---@return boolean
local function postgres_environment()
  return nonempty_string(vim.env.PGSERVICE)
    or nonempty_string(vim.env.PGDATABASE)
    or nonempty_string(vim.env.PGHOST)
    or nonempty_string(vim.env.PGPORT)
end

---@return SqlDebugBackend?
local function database_url_backend()
  local url = vim.env.DATABASE_URL

  if not nonempty_string(url) then
    return nil
  end

  local lower = url:lower()

  if lower:find('postgres://', 1, true) == 1 or lower:find('postgresql://', 1, true) == 1 then
    return 'postgres'
  end

  if lower:find('sqlite://', 1, true) == 1 then
    return 'sqlite'
  end

  return nil
end

---@return SqlDebugBackend
local function detect_backend()
  if state.backend ~= 'auto' then
    return state.backend
  end

  local configured = vim.env.NVIM_SQL_BACKEND

  if nonempty_string(configured) then
    local normalized = configured:lower()

    if normalized == 'postgres' or normalized == 'postgresql' or normalized == 'pgsql' then
      return 'postgres'
    end

    if normalized == 'sqlite' then
      return 'sqlite'
    end

    if normalized == 'generic' then
      return 'generic'
    end
  end

  if POSTGRES_FILETYPES[filetype()] then
    return 'postgres'
  end

  local url_backend = database_url_backend()

  if url_backend ~= nil then
    return url_backend
  end

  if postgres_environment() then
    return 'postgres'
  end

  if configured_sqlite_database() ~= nil then
    return 'sqlite'
  end

  if #sqlite_databases(project_root()) == 1 then
    return 'sqlite'
  end

  return 'generic'
end

---@param text string
---@param position integer
---@return string?
local function dollar_quote_at(text, position)
  if text:sub(position, position) ~= '$' then
    return nil
  end

  local tail = text:sub(position)

  return tail:match('^%$%$') or tail:match('^%$[%a_][%w_]*%$')
end

---@param text string
---@param cursor_offset integer
---@return string
local function statement_from_text(text, cursor_offset)
  local start_offset = 1
  local statement_start = 1
  local statement_end = #text

  local state_name = 'normal'
  local dollar_tag
  local block_depth = 0
  local index = 1

  while index <= #text do
    local char = text:sub(index, index)

    local next_char = text:sub(index + 1, index + 1)

    if state_name == 'normal' then
      if char == '-' and next_char == '-' then
        state_name = 'line-comment'

        index = index + 2
      elseif char == '/' and next_char == '*' then
        state_name = 'block-comment'

        block_depth = 1

        index = index + 2
      elseif char == "'" then
        state_name = 'single-quote'

        index = index + 1
      elseif char == '"' then
        state_name = 'double-quote'

        index = index + 1
      elseif char == '$' then
        local tag = dollar_quote_at(text, index)

        if tag ~= nil then
          state_name = 'dollar-quote'

          dollar_tag = tag

          index = index + #tag
        else
          index = index + 1
        end
      elseif char == ';' then
        if cursor_offset >= statement_start and cursor_offset <= index then
          statement_end = index

          break
        end

        statement_start = index + 1

        index = index + 1
      else
        index = index + 1
      end
    elseif state_name == 'line-comment' then
      if char == '\n' then
        state_name = 'normal'
      end

      index = index + 1
    elseif state_name == 'block-comment' then
      if char == '/' and next_char == '*' then
        block_depth = block_depth + 1

        index = index + 2
      elseif char == '*' and next_char == '/' then
        block_depth = block_depth - 1

        index = index + 2

        if block_depth == 0 then
          state_name = 'normal'
        end
      else
        index = index + 1
      end
    elseif state_name == 'single-quote' then
      if char == "'" and next_char == "'" then
        index = index + 2
      elseif char == "'" then
        state_name = 'normal'

        index = index + 1
      else
        index = index + 1
      end
    elseif state_name == 'double-quote' then
      if char == '"' and next_char == '"' then
        index = index + 2
      elseif char == '"' then
        state_name = 'normal'

        index = index + 1
      else
        index = index + 1
      end
    elseif state_name == 'dollar-quote' then
      if dollar_tag ~= nil and text:sub(index, index + #dollar_tag - 1) == dollar_tag then
        index = index + #dollar_tag

        dollar_tag = nil
        state_name = 'normal'
      else
        index = index + 1
      end
    end
  end

  if cursor_offset < statement_start then
    statement_start = start_offset
  end

  local statement = vim.trim(text:sub(statement_start, statement_end))

  return statement
end

---@param bufnr? integer
---@return string
local function current_statement(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()

  if not api.nvim_buf_is_valid(bufnr) then
    return ''
  end

  local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)

  if #lines == 0 then
    return ''
  end

  local cursor = api.nvim_win_get_cursor(0)

  local cursor_line = cursor[1]

  local cursor_column = cursor[2]

  local offset = 1

  for index = 1, cursor_line - 1 do
    offset = offset + #lines[index] + 1
  end

  offset = offset + cursor_column

  local text = table.concat(lines, '\n')

  return statement_from_text(text, offset)
end

---@param sql string
---@return string?
local function first_keyword(sql)
  local cleaned = sql:gsub('^%s*%-%-[^\n]*\n', '')

  return cleaned:match('^%s*([%a_]+)')
end

---@param sql string
---@return boolean
local function potentially_mutating(sql)
  local keyword = first_keyword(sql)

  if keyword == nil then
    return false
  end

  return MUTATING_KEYWORDS[keyword:upper()] == true
end

---@param title string
---@param output string
---@param stderr? string
local function show_output(title, output, stderr)
  local text = output

  if type(stderr) == 'string' and stderr ~= '' then
    if text ~= '' then
      text = text .. '\n\n--- stderr ---\n' .. stderr
    else
      text = stderr
    end
  end

  if text == '' then
    text = '(no output)'
  end

  vim.cmd('botright new')

  local bufnr = api.nvim_get_current_buf()

  vim.bo[bufnr].buftype = 'nofile'

  vim.bo[bufnr].bufhidden = 'wipe'

  vim.bo[bufnr].swapfile = false

  vim.bo[bufnr].modifiable = true

  vim.bo[bufnr].filetype = 'sql'

  api.nvim_buf_set_name(bufnr, ('[SQL Debug: %s]'):format(title))

  api.nvim_buf_set_lines(
    bufnr,
    0,
    -1,
    false,
    vim.split(text, '\n', {
      plain = true,
    })
  )

  vim.bo[bufnr].modifiable = false

  vim.bo[bufnr].modified = false
end

---@param command string[]
---@param options table
---@param title string
local function run_async(command, options, title)
  options = options or {}

  options.text = true

  local ok, process = pcall(vim.system, command, options, function(result)
    vim.schedule(function()
      show_output(title, result.stdout or '', result.stderr or '')

      if result.code ~= 0 then
        notify(('%s exited with status %d'):format(title, result.code), levels.WARN)
      end
    end)
  end)

  if not ok then
    notify(('%s failed to start: %s'):format(title, tostring(process)), levels.ERROR)
  end
end

---@return table<string, string>
local function postgres_environment_table()
  local env = fn.environ()

  if not nonempty_string(env.PGCONNECT_TIMEOUT) then
    env.PGCONNECT_TIMEOUT = '5'
  end

  return env
end

---@param sql string
---@param title string
local function postgres_run(sql, title)
  local psql = resolve_psql()

  if psql == nil then
    notify('psql was not found', levels.ERROR)

    return
  end

  run_async({
    psql,

    '-X',

    '--no-psqlrc',

    '--set',
    'ON_ERROR_STOP=1',

    '--pset',
    'pager=off',
  }, {
    cwd = project_root(),

    env = postgres_environment_table(),

    stdin = sql .. '\n',
  }, title)
end

---@param sql string
---@param title string
local function sqlite_run(sql, title)
  local sqlite = resolve_sqlite()

  if sqlite == nil then
    notify('sqlite3 was not found', levels.ERROR)

    return
  end

  local database = resolve_sqlite_database()

  if database == nil then
    notify(
      table.concat({
        'SQLite database was not resolved.',

        '',

        'Use :SqlDebugDatabase or set:',

        '  NVIM_SQLITE_DATABASE=/path/to/database.sqlite',
      }, '\n'),
      levels.ERROR
    )

    return
  end

  run_async({
    sqlite,

    '-batch',

    database,
  }, {
    cwd = project_root(),

    stdin = table.concat({
      '.bail on',
      '.headers on',
      '.mode box',
      sql,
      '',
    }, '\n'),
  }, title)
end

---@param sql string
---@param title string
local function execute_for_backend(sql, title)
  local backend = detect_backend()

  if backend == 'postgres' then
    postgres_run(sql, title)

    return
  end

  if backend == 'sqlite' then
    sqlite_run(sql, title)

    return
  end

  notify(
    table.concat({
      'No executable SQL backend is selected.',

      '',

      'Use :SqlDebugBackend to choose PostgreSQL or SQLite.',
    }, '\n'),
    levels.WARN
  )
end

local function execute_statement()
  local sql = current_statement()

  if sql == '' then
    notify('no SQL statement found under cursor', levels.WARN)

    return
  end

  if potentially_mutating(sql) then
    local answer = fn.confirm('Execute a potentially mutating SQL statement?', '&Execute\n&Cancel', 2)

    if answer ~= 1 then
      return
    end
  end

  execute_for_backend(sql, 'Execute')
end

local function explain_statement()
  local sql = current_statement()

  if sql == '' then
    notify('no SQL statement found under cursor', levels.WARN)

    return
  end

  local backend = detect_backend()

  if backend == 'postgres' then
    postgres_run(
      table.concat({
        'EXPLAIN (',
        '  VERBOSE,',
        '  COSTS,',
        '  SETTINGS,',
        '  SUMMARY,',
        '  FORMAT TEXT',
        ')',
        sql,
      }, '\n'),
      'PostgreSQL EXPLAIN'
    )

    return
  end

  if backend == 'sqlite' then
    sqlite_run('EXPLAIN QUERY PLAN ' .. sql, 'SQLite Query Plan')

    return
  end

  notify('EXPLAIN requires a PostgreSQL or SQLite backend', levels.WARN)
end

local function sqlite_bytecode()
  if detect_backend() ~= 'sqlite' then
    notify('SQLite bytecode inspection requires the SQLite backend', levels.WARN)

    return
  end

  local sql = current_statement()

  if sql == '' then
    notify('no SQL statement found under cursor', levels.WARN)

    return
  end

  sqlite_run('EXPLAIN ' .. sql, 'SQLite VDBE Bytecode')
end

local function sqlite_full_trace()
  if detect_backend() ~= 'sqlite' then
    notify('SQLite full EQP tracing requires the SQLite backend', levels.WARN)

    return
  end

  local sql = current_statement()

  if sql == '' then
    notify('no SQL statement found under cursor', levels.WARN)

    return
  end

  local answer = fn.confirm('SQLite .eqp full executes the statement. Continue?', '&Execute\n&Cancel', 2)

  if answer ~= 1 then
    return
  end

  local sqlite = resolve_sqlite()

  local database = resolve_sqlite_database()

  if sqlite == nil or database == nil then
    notify('SQLite executable/database is unavailable', levels.ERROR)

    return
  end

  run_async({
    sqlite,
    '-batch',
    database,
  }, {
    cwd = project_root(),

    stdin = table.concat({
      '.bail on',
      '.headers on',
      '.mode box',
      '.eqp full',
      sql,
      '',
    }, '\n'),
  }, 'SQLite EQP Full')
end

local function postgres_profile()
  if detect_backend() ~= 'postgres' then
    notify('PostgreSQL profiling requires the PostgreSQL backend', levels.WARN)

    return
  end

  local sql = current_statement()

  if sql == '' then
    notify('no SQL statement found under cursor', levels.WARN)

    return
  end

  local answer = fn.confirm(
    table.concat({
      'EXPLAIN ANALYZE executes the SQL statement.',
      'Run it inside a transaction and roll it back?',
    }, '\n'),
    '&Profile\n&Cancel',
    2
  )

  if answer ~= 1 then
    return
  end

  postgres_run(
    table.concat({
      'BEGIN;',

      "SET LOCAL statement_timeout = '30s';",

      'EXPLAIN (',
      '  ANALYZE,',
      '  BUFFERS,',
      '  WAL,',
      '  SETTINGS,',
      '  SUMMARY,',
      '  FORMAT TEXT',
      ')',

      sql,

      'ROLLBACK;',
    }, '\n'),
    'PostgreSQL Profile'
  )
end

local function sqlite_profile_available()
  local sqlite = resolve_sqlite()

  local database = resolve_sqlite_database()

  if sqlite == nil or database == nil then
    return false
  end

  local ok, result = pcall(function()
    return vim
      .system({
        sqlite,
        '-batch',
        database,
      }, {
        stdin = 'PRAGMA compile_options;\n',

        text = true,
      })
      :wait()
  end)

  if not ok then
    return false
  end

  return result.code == 0 and (result.stdout or ''):find('ENABLE_STMT_SCANSTATUS', 1, true) ~= nil
end

local function sqlite_profile()
  if detect_backend() ~= 'sqlite' then
    notify('SQLite profiling requires the SQLite backend', levels.WARN)

    return
  end

  if not sqlite_profile_available() then
    notify(
      table.concat({
        'This sqlite3 build does not advertise',

        'SQLITE_ENABLE_STMT_SCANSTATUS.',

        '',

        'Use EXPLAIN QUERY PLAN or VDBE inspection instead.',
      }, '\n'),
      levels.WARN
    )

    return
  end

  local sql = current_statement()

  if sql == '' then
    notify('no SQL statement found under cursor', levels.WARN)

    return
  end

  local answer = fn.confirm('SQLite scan-status profiling executes the statement. Continue?', '&Profile\n&Cancel', 2)

  if answer ~= 1 then
    return
  end

  local sqlite = resolve_sqlite()

  local database = resolve_sqlite_database()

  if sqlite == nil or database == nil then
    return
  end

  run_async({
    sqlite,
    '-batch',
    database,
  }, {
    cwd = project_root(),

    stdin = table.concat({
      '.bail on',
      '.headers on',
      '.mode box',
      '.scanstats on',
      sql,
      '',
    }, '\n'),
  }, 'SQLite Profile')
end

local function profile_statement()
  local backend = detect_backend()

  if backend == 'postgres' then
    postgres_profile()

    return
  end

  if backend == 'sqlite' then
    sqlite_profile()

    return
  end

  notify('profiling requires a PostgreSQL or SQLite backend', levels.WARN)
end

local function select_backend()
  local selected = fn.inputlist({
    'SQL debug backend:',

    '1. Auto',

    '2. PostgreSQL',

    '3. SQLite',

    '4. Generic SQL',
  })

  if selected == 1 then
    state.backend = 'auto'
  elseif selected == 2 then
    state.backend = 'postgres'
  elseif selected == 3 then
    state.backend = 'sqlite'
  elseif selected == 4 then
    state.backend = 'generic'
  else
    return
  end

  notify(('SQL backend: %s (resolved: %s)'):format(state.backend, detect_backend()))
end

local function select_sqlite_database()
  local current = resolve_sqlite_database() or project_root()

  local selected = fn.input('SQLite database: ', current, 'file')

  if selected == '' then
    return
  end

  selected = normalize(fn.expand(selected))

  if not is_file(selected) then
    notify(('database file does not exist: %s'):format(selected), levels.ERROR)

    return
  end

  state.sqlite_database = selected

  state.backend = 'sqlite'

  notify(('SQLite database: %s'):format(selected))
end

local function open_postgres()
  local psql = resolve_psql()

  if psql == nil then
    notify('psql was not found', levels.ERROR)

    return
  end

  vim.cmd('botright new')

  local bufnr = api.nvim_get_current_buf()

  vim.bo[bufnr].bufhidden = 'wipe'

  local job = fn.jobstart({
    psql,
    '-X',
    '--no-psqlrc',
  }, {
    cwd = project_root(),

    env = postgres_environment_table(),

    term = true,
  })

  if job <= 0 then
    notify('failed to start psql', levels.ERROR)

    return
  end

  vim.cmd('startinsert')
end

local function open_sqlite()
  local sqlite = resolve_sqlite()

  if sqlite == nil then
    notify('sqlite3 was not found', levels.ERROR)

    return
  end

  local database = resolve_sqlite_database()

  if database == nil then
    select_sqlite_database()

    database = resolve_sqlite_database()
  end

  if database == nil then
    return
  end

  vim.cmd('botright new')

  local bufnr = api.nvim_get_current_buf()

  vim.bo[bufnr].bufhidden = 'wipe'

  local job = fn.jobstart({
    sqlite,
    database,
  }, {
    cwd = project_root(),

    term = true,
  })

  if job <= 0 then
    notify('failed to start sqlite3', levels.ERROR)

    return
  end

  vim.cmd('startinsert')
end

local function open_backend_shell()
  local backend = detect_backend()

  if backend == 'postgres' then
    open_postgres()

    return
  end

  if backend == 'sqlite' then
    open_sqlite()

    return
  end

  notify('select PostgreSQL or SQLite before opening a database shell', levels.WARN)
end

local function start_postgres_dap()
  if detect_backend() ~= 'postgres' then
    notify('true SQL DAP debugging is currently available only through the PostgreSQL backend', levels.WARN)

    return
  end

  local ok, dap = pcall(require, 'dap')

  if not ok or type(dap) ~= 'table' then
    notify('native DAP registry could not be loaded', levels.ERROR)

    return
  end

  if not callable(dap.load) then
    notify('native DAP registry does not expose load()', levels.ERROR)

    return
  end

  if not dap.load('postgres') then
    notify('PostgreSQL DAP module could not be loaded', levels.ERROR)

    return
  end

  if callable(dap.run) then
    dap.run()

    return
  end

  notify('PostgreSQL DAP loaded; use :DebugRun to start it')
end

local function status()
  local backend = detect_backend()

  local sqlite_db = resolve_sqlite_database()

  notify(table.concat({
    'root: ' .. project_root(),

    'configured backend: ' .. state.backend,

    'resolved backend: ' .. backend,

    'current statement:',
    current_statement() ~= '' and current_statement() or '(none)',

    'psql: ' .. (resolve_psql() or 'not found'),

    'PostgreSQL connection hints: ' .. (postgres_environment() and 'present' or 'not detected'),

    'sqlite3: ' .. (resolve_sqlite() or 'not found'),

    'SQLite database: ' .. (sqlite_db or 'not selected'),

    'SQLite scanstatus profiling: '
      .. (backend == 'sqlite' and sqlite_profile_available() and 'available' or 'unavailable/not selected'),

    'true DAP backend: ' .. (backend == 'postgres' and 'PostgreSQL via dap.postgres/pgdap' or 'none'),
  }, '\n'))
end

local function clear_cache()
  state.backend = 'auto'
  state.root = nil
  state.sqlite_database = nil

  notify('SQL debug state cleared')
end

---@type table<string, DebugCommand>
M.commands = {
  SqlDebugBackend = {
    callback = function()
      select_backend()
    end,

    desc = 'Select SQL debug backend',
  },

  SqlDebugClear = {
    callback = function()
      clear_cache()
    end,

    desc = 'Clear SQL debug state',
  },

  SqlDebugDatabase = {
    callback = function()
      select_sqlite_database()
    end,

    desc = 'Select SQLite database',
  },

  SqlDebugExecute = {
    callback = function()
      execute_statement()
    end,

    desc = 'Execute SQL statement under cursor',
  },

  SqlDebugExplain = {
    callback = function()
      explain_statement()
    end,

    desc = 'Explain SQL statement under cursor',
  },

  SqlDebugPostgres = {
    callback = function()
      start_postgres_dap()
    end,

    desc = 'Start PostgreSQL PL/pgSQL DAP',
  },

  SqlDebugProfile = {
    callback = function()
      profile_statement()
    end,

    desc = 'Profile SQL statement under cursor',
  },

  SqlDebugShell = {
    callback = function()
      open_backend_shell()
    end,

    desc = 'Open native database shell',
  },

  SqlDebugSQLiteBytecode = {
    callback = function()
      sqlite_bytecode()
    end,

    desc = 'Show SQLite VDBE bytecode',
  },

  SqlDebugSQLiteTrace = {
    callback = function()
      sqlite_full_trace()
    end,

    desc = 'Run SQLite full EQP trace',
  },

  SqlDebugStatus = {
    callback = function()
      status()
    end,

    desc = 'Show SQL debug status',
  },
}

---@type table<string, DebugMapping>
M.mappings = {
  sql_debug_backend = {
    lhs = '<leader>dSb',

    mode = 'n',

    rhs = function()
      select_backend()
    end,

    desc = 'Debug SQL: Backend',
  },

  sql_debug_execute = {
    lhs = '<leader>dSe',

    mode = 'n',

    rhs = function()
      execute_statement()
    end,

    desc = 'Debug SQL: Execute',
  },

  sql_debug_explain = {
    lhs = '<leader>dSx',

    mode = 'n',

    rhs = function()
      explain_statement()
    end,

    desc = 'Debug SQL: Explain',
  },

  sql_debug_postgres = {
    lhs = '<leader>dSd',

    mode = 'n',

    rhs = function()
      start_postgres_dap()
    end,

    desc = 'Debug SQL: PostgreSQL DAP',
  },

  sql_debug_profile = {
    lhs = '<leader>dSp',

    mode = 'n',

    rhs = function()
      profile_statement()
    end,

    desc = 'Debug SQL: Profile',
  },

  sql_debug_shell = {
    lhs = '<leader>dSr',

    mode = 'n',

    rhs = function()
      open_backend_shell()
    end,

    desc = 'Debug SQL: REPL / shell',
  },

  sql_debug_sqlite_bytecode = {
    lhs = '<leader>dSv',

    mode = 'n',

    rhs = function()
      sqlite_bytecode()
    end,

    desc = 'Debug SQL: SQLite VDBE',
  },

  sql_debug_status = {
    lhs = '<leader>dSs',

    mode = 'n',

    rhs = function()
      status()
    end,

    desc = 'Debug SQL: Status',
  },
}

---@param opts? table
function M.setup(opts)
  opts = opts or {}

  state.root = nonempty_string(opts.root) and fs.normalize(opts.root) or project_root()

  local configured = vim.env.NVIM_SQL_BACKEND

  if nonempty_string(configured) then
    local backend = configured:lower()

    if backend == 'postgres' or backend == 'postgresql' or backend == 'pgsql' then
      state.backend = 'postgres'
    elseif backend == 'sqlite' then
      state.backend = 'sqlite'
    elseif backend == 'generic' then
      state.backend = 'generic'
    end
  end

  local configured_database = configured_sqlite_database()

  if configured_database ~= nil then
    state.sqlite_database = configured_database
  end
end

---@return SqlDebugBackend
function M.backend()
  return detect_backend()
end

---@return string
function M.root()
  return project_root()
end

---@return string
function M.statement()
  return current_statement()
end

---@return string?
function M.sqlite_database()
  return resolve_sqlite_database()
end

---@return boolean
function M.postgres_available()
  return resolve_psql() ~= nil
end

---@return boolean
function M.sqlite_available()
  return resolve_sqlite() ~= nil
end

return M