-- #################################################################
-- ~/.config/nvim/lua/dap/sqlite.lua
-- Qompass AI Diver Native SQLite Debug / Inspection Configuration
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
---@source https://sqlite.org/lang_explain.html
---@source https://sqlite.org/eqp.html
---@source https://sqlite.org/profile.html
---@source https://sqlite.org/debugging.html
---@source https://sqlite.org/opcode.html
---@source https://sqlite.org/compile.html
---@source https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap
---@source https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local levels = vim.log.levels
local uv = vim.uv

local M = {}

local SOURCE = "sqlite-dap"

---@type string[]
local ROOT_MARKERS = {
  "sqlite3.c",
  "sqlite3.h",
  "Makefile",
  "CMakeLists.txt",
  "meson.build",
  "database",
  "db",
  "migrations",
  "schema",
  ".git",
}

---@type string[]
local DATABASE_EXTENSIONS = {
  ".db",
  ".db3",
  ".sqlite",
  ".sqlite3",
}

---@class SQLiteDapState
---@field adapter "lldb"|"gdb"
---@field database string?
---@field executable string?
---@field root string?
---@field sqlite3 string?
local state = {
  adapter = "lldb",
  database = nil,
  executable = nil,
  root = nil,
  sqlite3 = nil,
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
local function is_file(path)
  if not nonempty_string(path) then
    return false
  end

  local stat = uv.fs_stat(path)

  return stat ~= nil
    and stat.type == "file"
end

---@param path string
---@return boolean
local function is_directory(path)
  if not nonempty_string(path) then
    return false
  end

  local stat = uv.fs_stat(path)

  return stat ~= nil
    and stat.type == "directory"
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
      return fs.normalize(
        detected
      )
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
---@return vim.SystemCompleted?
local function system(command, cwd)
  local ok, result = pcall(function()
    return vim.system(
      command,
      {
        cwd = cwd,
        text = true,
      }
    ):wait()
  end)

  if not ok then
    return nil
  end

  return result
end

---@param value string
---@param suffix string
---@return boolean
local function ends_with(value, suffix)
  return #value >= #suffix
    and value:sub(-#suffix) == suffix
end

---@param path string
---@return boolean
local function is_database_filename(path)
  local lower = path:lower()

  for _, extension in ipairs(
    DATABASE_EXTENSIONS
  ) do
    if ends_with(lower, extension) then
      return true
    end
  end

  return false
end

---@param root string
---@param depth integer
---@param result string[]
local function collect_databases(
  root,
  depth,
  result
)
  if
    depth > 3
    or not is_directory(root)
  then
    return
  end

  for name, kind in fs.dir(root) do
    local path = fs.joinpath(
      root,
      name
    )

    if kind == "directory" then
      if
        name ~= ".git"
        and name ~= "node_modules"
        and name ~= "target"
        and name ~= "build"
      then
        collect_databases(
          path,
          depth + 1,
          result
        )
      end
    elseif
      kind == "file"
      and is_database_filename(name)
    then
      result[#result + 1] =
        fs.normalize(path)
    end
  end
end

---@return string[]
local function database_candidates()
  ---@type string[]
  local result = {}

  collect_databases(
    project_root(),
    0,
    result
  )

  table.sort(result)

  return result
end

---@return string?
local function resolve_sqlite3()
  if
    state.sqlite3 ~= nil
    and executable(state.sqlite3)
  then
    return state.sqlite3
  end

  local configured =
    vim.env.NVIM_SQLITE_EXECUTABLE

  if nonempty_string(configured) then
    local candidate = normalize(
      fn.expand(configured)
    )

    if executable(candidate) then
      state.sqlite3 = candidate

      return candidate
    end

    notify(
      ("NVIM_SQLITE_EXECUTABLE is not executable: %s"):format(
        candidate
      ),
      levels.WARN
    )
  end

  local candidate =
    executable_path("sqlite3")

  if candidate ~= nil then
    state.sqlite3 = candidate

    return candidate
  end

  return nil
end

---@return string?
local function resolve_database()
  if
    state.database ~= nil
    and is_file(state.database)
  then
    return state.database
  end

  local configured =
    vim.env.NVIM_SQLITE_DATABASE

  if nonempty_string(configured) then
    local candidate = normalize(
      fn.expand(configured)
    )

    if is_file(candidate) then
      state.database = candidate

      return candidate
    end

    notify(
      ("NVIM_SQLITE_DATABASE does not exist: %s"):format(
        candidate
      ),
      levels.WARN
    )
  end

  local candidates =
    database_candidates()

  if #candidates == 1 then
    state.database = candidates[1]

    return candidates[1]
  end

  return nil
end

---@return string?
local function resolve_lldb_dap()
  local configured =
    vim.env.NVIM_SQLITE_LLDB_DAP
      or vim.env.NVIM_LLDB_DAP

  if nonempty_string(configured) then
    local candidate = normalize(
      fn.expand(configured)
    )

    if executable(candidate) then
      return candidate
    end
  end

  return executable_path(
    "lldb-dap"
  )
end

---@return string?
local function resolve_gdb()
  local configured =
    vim.env.NVIM_SQLITE_GDB_DAP
      or vim.env.NVIM_GDB_DAP

  if nonempty_string(configured) then
    local candidate = normalize(
      fn.expand(configured)
    )

    if executable(candidate) then
      return candidate
    end
  end

  return executable_path("gdb")
end

---@return boolean
local function gdb_supports_dap()
  local gdb = resolve_gdb()

  if gdb == nil then
    return false
  end

  local result = system({
    gdb,
    "--quiet",
    "--batch",
    "-ex",
    "python import sys; print(sys.version_info[0])",
  })

  return result ~= nil
    and result.code == 0
end

---@return string
local function active_adapter_type()
  if
    state.adapter == "lldb"
    and resolve_lldb_dap() ~= nil
  then
    return "sqlite-lldb"
  end

  if
    state.adapter == "gdb"
    and gdb_supports_dap()
  then
    return "sqlite-gdb"
  end

  if resolve_lldb_dap() ~= nil then
    state.adapter = "lldb"

    return "sqlite-lldb"
  end

  if gdb_supports_dap() then
    state.adapter = "gdb"

    return "sqlite-gdb"
  end

  return "sqlite-lldb"
end

---@return string?
local function sqlite_version()
  local sqlite = resolve_sqlite3()

  if sqlite == nil then
    return nil
  end

  local result = system({
    sqlite,
    "--version",
  })

  if
    result == nil
    or result.code ~= 0
  then
    return nil
  end

  local value = vim.trim(
    result.stdout or ""
  )

  if value == "" then
    return nil
  end

  return value:match("[^\r\n]+")
end

---@return string[]
local function compile_options()
  local sqlite = resolve_sqlite3()
  local database = resolve_database()

  if
    sqlite == nil
    or database == nil
  then
    return {}
  end

  local result = system({
    sqlite,
    "-batch",
    database,
    "PRAGMA compile_options;",
  })

  if
    result == nil
    or result.code ~= 0
  then
    return {}
  end

  ---@type string[]
  local options = {}

  for line in (
    result.stdout or ""
  ):gmatch("[^\r\n]+") do
    local value = vim.trim(line)

    if value ~= "" then
      options[#options + 1] =
        value
    end
  end

  return options
end

---@param option string
---@return boolean
local function has_compile_option(option)
  for _, value in ipairs(
    compile_options()
  ) do
    if value == option then
      return true
    end
  end

  return false
end

---@return boolean
local function has_scanstatus()
  return has_compile_option(
    "ENABLE_STMT_SCANSTATUS"
  )
end

---@return boolean
local function has_sqlite_debug()
  return has_compile_option(
    "DEBUG"
  )
end

---@return boolean
local function has_bytecode_vtab()
  return has_compile_option(
    "ENABLE_BYTECODE_VTAB"
  )
end

---@return string
local function cwd()
  local root = project_root()

  state.root = root

  return root
end

---@return string
local function database_program()
  return resolve_sqlite3()
    or "sqlite3"
end

---@return string[]
local function database_args()
  local database =
    resolve_database()

  if database == nil then
    return {}
  end

  return {
    database,
  }
end

---@return integer
local function prompt_pid()
  local input = fn.input(
    "SQLite process PID: "
  )

  local pid = tonumber(input)

  if
    pid == nil
    or pid < 1
  then
    notify(
      ("invalid PID: %s"):format(
        input
      ),
      levels.ERROR
    )

    return 0
  end

  return math.floor(pid)
end

---@return string
local function prompt_executable()
  local selected = fn.input(
    "SQLite embedding executable: ",
    state.executable
      or project_root(),
    "file"
  )

  if selected == "" then
    return ""
  end

  selected = normalize(
    fn.expand(selected)
  )

  if not executable(selected) then
    notify(
      ("not an executable: %s"):format(
        selected
      ),
      levels.ERROR
    )

    return ""
  end

  state.executable = selected

  return selected
end

---@return string[]
local function prompt_program_args()
  local input = fn.input(
    "Program arguments: "
  )

  if input == "" then
    return {}
  end

  return fn.shellsplit(input)
end

---@return string
local function buffer_text()
  local bufnr =
    api.nvim_get_current_buf()

  if not api.nvim_buf_is_valid(bufnr) then
    return ""
  end

  return table.concat(
    api.nvim_buf_get_lines(
      bufnr,
      0,
      -1,
      false
    ),
    "\n"
  )
end

---@return string
local function current_statement()
  --
  -- Prefer the generic SQL layer when it is available because that module
  -- contains the more complete SQL statement parser.
  --
  local ok, sql =
    pcall(
      require,
      "dap.sql"
    )

  if
    ok
    and type(sql) == "table"
    and type(sql.statement) == "function"
  then
    local statement =
      sql.statement()

    if
      type(statement) == "string"
      and statement ~= ""
    then
      return statement
    end
  end

  --
  -- Conservative standalone fallback.
  --
  local lines =
    api.nvim_buf_get_lines(
      0,
      0,
      -1,
      false
    )

  local cursor =
    api.nvim_win_get_cursor(0)

  local line_index =
    cursor[1]

  local start_line = line_index
  local end_line = line_index

  while start_line > 1 do
    if
      lines[start_line - 1]:find(
        ";",
        1,
        true
      ) ~= nil
    then
      break
    end

    start_line =
      start_line - 1
  end

  while end_line <= #lines do
    if
      lines[end_line]:find(
        ";",
        1,
        true
      ) ~= nil
    then
      break
    end

    end_line =
      end_line + 1
  end

  if end_line > #lines then
    end_line = #lines
  end

  return vim.trim(
    table.concat(
      vim.list_slice(
        lines,
        start_line,
        end_line
      ),
      "\n"
    )
  )
end

---@param title string
---@param stdout string
---@param stderr string
local function show_output(
  title,
  stdout,
  stderr
)
  local output = stdout

  if stderr ~= "" then
    if output ~= "" then
      output =
        output
        .. "\n\n--- stderr ---\n"
        .. stderr
    else
      output = stderr
    end
  end

  if output == "" then
    output = "(no output)"
  end

  vim.cmd("botright new")

  local bufnr =
    api.nvim_get_current_buf()

  vim.bo[bufnr].buftype =
    "nofile"

  vim.bo[bufnr].bufhidden =
    "wipe"

  vim.bo[bufnr].swapfile =
    false

  vim.bo[bufnr].modifiable =
    true

  api.nvim_buf_set_name(
    bufnr,
    ("[SQLite: %s]"):format(
      title
    )
  )

  api.nvim_buf_set_lines(
    bufnr,
    0,
    -1,
    false,
    vim.split(
      output,
      "\n",
      {
        plain = true,
      }
    )
  )

  vim.bo[bufnr].modifiable =
    false

  vim.bo[bufnr].modified =
    false
end

---@param input string
---@param title string
local function sqlite_run(
  input,
  title
)
  local sqlite = resolve_sqlite3()
  local database = resolve_database()

  if sqlite == nil then
    notify(
      "sqlite3 was not found",
      levels.ERROR
    )

    return
  end

  if database == nil then
    notify(
      table.concat({
        "SQLite database was not resolved.",
        "",
        "Use :SQLiteDebugDatabase or set:",
        "  NVIM_SQLITE_DATABASE=/path/to/database.sqlite",
      }, "\n"),
      levels.ERROR
    )

    return
  end

  vim.system(
    {
      sqlite,
      "-batch",
      database,
    },
    {
      cwd = project_root(),

      stdin = table.concat({
        ".bail on",
        ".headers on",
        ".mode box",
        input,
        "",
      }, "\n"),

      text = true,
    },
    function(result)
      vim.schedule(function()
        show_output(
          title,
          result.stdout or "",
          result.stderr or ""
        )

        if result.code ~= 0 then
          notify(
            ("%s exited with status %d"):format(
              title,
              result.code
            ),
            levels.WARN
          )
        end
      end)
    end
  )
end

local function query_plan()
  local statement =
    current_statement()

  if statement == "" then
    notify(
      "no SQL statement found under cursor",
      levels.WARN
    )

    return
  end

  sqlite_run(
    "EXPLAIN QUERY PLAN "
      .. statement,
    "Query Plan"
  )
end

local function bytecode()
  local statement =
    current_statement()

  if statement == "" then
    notify(
      "no SQL statement found under cursor",
      levels.WARN
    )

    return
  end

  sqlite_run(
    "EXPLAIN " .. statement,
    "VDBE Bytecode"
  )
end

local function eqp_full()
  local statement =
    current_statement()

  if statement == "" then
    notify(
      "no SQL statement found under cursor",
      levels.WARN
    )

    return
  end

  local answer = fn.confirm(
    table.concat({
      ".eqp full shows query-plan and VDBE information",
      "and then executes the SQL statement.",
      "",
      "Continue?",
    }, "\n"),
    "&Execute\n&Cancel",
    2
  )

  if answer ~= 1 then
    return
  end

  sqlite_run(
    table.concat({
      ".echo on",
      ".eqp full",
      statement,
    }, "\n"),
    "EQP Full"
  )
end

local function eqp_trace()
  local statement =
    current_statement()

  if statement == "" then
    notify(
      "no SQL statement found under cursor",
      levels.WARN
    )

    return
  end

  local answer = fn.confirm(
    table.concat({
      ".eqp trace enables VDBE tracing and executes",
      "the selected SQL statement.",
      "",
      "Continue?",
    }, "\n"),
    "&Trace\n&Cancel",
    2
  )

  if answer ~= 1 then
    return
  end

  sqlite_run(
    table.concat({
      ".echo on",
      ".eqp trace",
      statement,
    }, "\n"),
    "EQP Trace"
  )
end

local function scanstatus()
  if not has_scanstatus() then
    notify(
      table.concat({
        "This SQLite build does not advertise",
        "SQLITE_ENABLE_STMT_SCANSTATUS.",
        "",
        "Use EXPLAIN QUERY PLAN or VDBE inspection instead.",
      }, "\n"),
      levels.WARN
    )

    return
  end

  local statement =
    current_statement()

  if statement == "" then
    notify(
      "no SQL statement found under cursor",
      levels.WARN
    )

    return
  end

  local answer = fn.confirm(
    "Scan-status profiling executes the SQL statement. Continue?",
    "&Profile\n&Cancel",
    2
  )

  if answer ~= 1 then
    return
  end

  sqlite_run(
    table.concat({
      ".scanstats on",
      statement,
    }, "\n"),
    "Scan Status"
  )
end

local function execute_statement()
  local statement =
    current_statement()

  if statement == "" then
    notify(
      "no SQL statement found under cursor",
      levels.WARN
    )

    return
  end

  local answer = fn.confirm(
    "Execute the current SQLite statement?",
    "&Execute\n&Cancel",
    2
  )

  if answer ~= 1 then
    return
  end

  sqlite_run(
    statement,
    "Execute"
  )
end

local function execute_buffer()
  local text = buffer_text()

  if text == "" then
    notify(
      "current buffer is empty",
      levels.WARN
    )

    return
  end

  local answer = fn.confirm(
    "Execute the entire SQL buffer against the selected database?",
    "&Execute\n&Cancel",
    2
  )

  if answer ~= 1 then
    return
  end

  sqlite_run(
    text,
    "Execute Buffer"
  )
end

local function schema()
  sqlite_run(
    ".schema",
    "Schema"
  )
end

local function tables()
  sqlite_run(
    ".tables",
    "Tables"
  )
end

local function indexes()
  sqlite_run(
    [[
SELECT
  type,
  name,
  tbl_name,
  sql
FROM sqlite_schema
WHERE type = 'index'
ORDER BY
  tbl_name,
  name;
]],
    "Indexes"
  )
end

local function database_info()
  sqlite_run(
    table.concat({
      ".databases",
      ".dbconfig",
    }, "\n"),
    "Database"
  )
end

local function integrity_check()
  sqlite_run(
    "PRAGMA integrity_check;",
    "Integrity Check"
  )
end

local function quick_check()
  sqlite_run(
    "PRAGMA quick_check;",
    "Quick Check"
  )
end

local function foreign_key_check()
  sqlite_run(
    "PRAGMA foreign_key_check;",
    "Foreign Key Check"
  )
end

local function optimize()
  local answer = fn.confirm(
    "Run PRAGMA optimize on the selected SQLite database?",
    "&Optimize\n&Cancel",
    2
  )

  if answer ~= 1 then
    return
  end

  sqlite_run(
    "PRAGMA optimize;",
    "Optimize"
  )
end

local function open_shell()
  local sqlite = resolve_sqlite3()
  local database = resolve_database()

  if sqlite == nil then
    notify(
      "sqlite3 was not found",
      levels.ERROR
    )

    return
  end

  if database == nil then
    notify(
      "no SQLite database selected",
      levels.ERROR
    )

    return
  end

  vim.cmd("botright new")

  local bufnr =
    api.nvim_get_current_buf()

  vim.bo[bufnr].bufhidden =
    "wipe"

  local job = fn.termopen(
    {
      sqlite,
      database,
    },
    {
      cwd = project_root(),
    }
  )

  if job <= 0 then
    notify(
      "failed to start sqlite3",
      levels.ERROR
    )

    return
  end

  vim.cmd("startinsert")
end

local function select_database()
  local candidates =
    database_candidates()

  if #candidates > 0 then
    local choices = {
      "SQLite database:",
    }

    for index, candidate in ipairs(
      candidates
    ) do
      choices[#choices + 1] =
        ("%d. %s"):format(
          index,
          candidate
        )
    end

    choices[#choices + 1] =
      ("%d. Other..."):format(
        #candidates + 1
      )

    local selected =
      fn.inputlist(choices)

    if
      selected >= 1
      and selected <= #candidates
    then
      state.database =
        candidates[selected]

      notify(
        ("SQLite database: %s"):format(
          state.database
        )
      )

      return
    end

    if selected ~= #candidates + 1 then
      return
    end
  end

  local selected = fn.input(
    "SQLite database: ",
    resolve_database()
      or project_root(),
    "file"
  )

  if selected == "" then
    return
  end

  selected = normalize(
    fn.expand(selected)
  )

  if not is_file(selected) then
    notify(
      ("database does not exist: %s"):format(
        selected
      ),
      levels.ERROR
    )

    return
  end

  state.database = selected

  notify(
    ("SQLite database: %s"):format(
      selected
    )
  )
end

local function select_sqlite3()
  local selected = fn.input(
    "sqlite3 executable: ",
    resolve_sqlite3() or "",
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

  state.sqlite3 = selected

  notify(
    ("sqlite3: %s"):format(
      selected
    )
  )
end

local function select_adapter()
  local selected = fn.inputlist({
    "SQLite native debugger:",
    "1. LLDB DAP",
    "2. GDB DAP",
  })

  if selected == 1 then
    if resolve_lldb_dap() == nil then
      notify(
        "lldb-dap is unavailable",
        levels.ERROR
      )

      return
    end

    state.adapter = "lldb"

    notify(
      "SQLite native debugger: LLDB DAP"
    )
  elseif selected == 2 then
    if not gdb_supports_dap() then
      notify(
        "GDB DAP is unavailable",
        levels.ERROR
      )

      return
    end

    state.adapter = "gdb"

    notify(
      "SQLite native debugger: GDB DAP"
    )
  end
end

local function clear_cache()
  state.adapter = "lldb"
  state.database = nil
  state.executable = nil
  state.root = nil
  state.sqlite3 = nil

  notify(
    "SQLite debug state cleared"
  )
end

local function status()
  local options =
    compile_options()

  notify(
    table.concat({
      "root: "
        .. project_root(),

      "sqlite3: "
        .. (
          resolve_sqlite3()
            or "not found"
        ),

      "SQLite version: "
        .. (
          sqlite_version()
            or "unknown"
        ),

      "database: "
        .. (
          resolve_database()
            or "not selected"
        ),

      "native debugger: "
        .. state.adapter,

      "lldb-dap: "
        .. (
          resolve_lldb_dap()
            or "not found"
        ),

      "GDB DAP: "
        .. (
          gdb_supports_dap()
              and "available"
            or "unavailable"
        ),

      "SQLITE_DEBUG: "
        .. (
          has_sqlite_debug()
              and "enabled"
            or "disabled"
        ),

      "SQLITE_ENABLE_STMT_SCANSTATUS: "
        .. (
          has_scanstatus()
              and "enabled"
            or "disabled"
        ),

      "SQLITE_ENABLE_BYTECODE_VTAB: "
        .. (
          has_bytecode_vtab()
              and "enabled"
            or "disabled"
        ),

      "compile options: "
        .. (
          #options > 0
              and tostring(#options)
            or "unknown"
        ),

      "SQL source-level DAP: none",

      "native C/C++ DAP: "
        .. (
          resolve_lldb_dap() ~= nil
              or gdb_supports_dap()
                and "available"
              or "unavailable"
        ),
    }, "\n")
  )
end

--
-- SQLite SQL is compiled into VDBE bytecode and does not expose a
-- source-level SQL debugger protocol.
--
-- These adapters therefore debug the native sqlite3 executable, SQLite
-- itself, or another application embedding libsqlite3.
--
---@type table<string, table>
M.adapters = {
  ["sqlite-lldb"] = {
    name = "sqlite-lldb",

    type = "executable",

    command =
      resolve_lldb_dap()
        or "lldb-dap",

    options = {
      source_filetype = "c",
    },
  },

  ["sqlite-gdb"] = {
    name = "sqlite-gdb",

    type = "executable",

    command =
      resolve_gdb()
        or "gdb",

    args = {
      "-q",
      "-i=dap",
    },

    options = {
      source_filetype = "c",
    },
  },
}

---@type table[]
local native_configurations = {
  --
  -- Debug the sqlite3 shell itself. Breakpoints should normally be placed in
  -- SQLite's C source rather than in the .sql file.
  --
  {
    name = "SQLite Native: sqlite3 CLI",

    type = active_adapter_type,

    request = "launch",

    program = database_program,

    cwd = cwd,

    args = database_args,

    stopOnEntry = false,

    runInTerminal = true,
  },

  {
    name = "SQLite Native: sqlite3 CLI (Stop on Entry)",

    type = active_adapter_type,

    request = "launch",

    program = database_program,

    cwd = cwd,

    args = database_args,

    stopOnEntry = true,

    runInTerminal = true,
  },

  --
  -- Debug an application that embeds SQLite.
  --
  {
    name = "SQLite Native: Embedding Application",

    type = active_adapter_type,

    request = "launch",

    program = prompt_executable,

    cwd = cwd,

    args = prompt_program_args,

    stopOnEntry = false,

    runInTerminal = true,
  },

  {
    name = "SQLite Native: Attach PID",

    type = active_adapter_type,

    request = "attach",

    pid = prompt_pid,
  },
}

---@type table<string, table[]>
M.configurations = {
  c = native_configurations,

  cpp = native_configurations,

  sql = native_configurations,

  sqlite = native_configurations,
}

---@type table<string, DebugCommand>
M.commands = {
  SQLiteDebugAdapter = {
    callback = function()
      select_adapter()
    end,

    desc = "Select SQLite native debugger",
  },

  SQLiteDebugBytecode = {
    callback = function()
      bytecode()
    end,

    desc = "Show SQLite VDBE bytecode",
  },

  SQLiteDebugClear = {
    callback = function()
      clear_cache()
    end,

    desc = "Clear SQLite debug state",
  },

  SQLiteDebugDatabase = {
    callback = function()
      select_database()
    end,

    desc = "Select SQLite database",
  },

  SQLiteDebugDatabaseInfo = {
    callback = function()
      database_info()
    end,

    desc = "Show SQLite database configuration",
  },

  SQLiteDebugEQPFull = {
    callback = function()
      eqp_full()
    end,

    desc = "Run SQLite .eqp full",
  },

  SQLiteDebugEQPTrace = {
    callback = function()
      eqp_trace()
    end,

    desc = "Run SQLite .eqp trace",
  },

  SQLiteDebugExecute = {
    callback = function()
      execute_statement()
    end,

    desc = "Execute SQLite statement under cursor",
  },

  SQLiteDebugExecuteBuffer = {
    callback = function()
      execute_buffer()
    end,

    desc = "Execute current SQL buffer",
  },

  SQLiteDebugForeignKeys = {
    callback = function()
      foreign_key_check()
    end,

    desc = "Run SQLite foreign key check",
  },

  SQLiteDebugIndexes = {
    callback = function()
      indexes()
    end,

    desc = "Show SQLite indexes",
  },

  SQLiteDebugIntegrity = {
    callback = function()
      integrity_check()
    end,

    desc = "Run SQLite integrity check",
  },

  SQLiteDebugOptimize = {
    callback = function()
      optimize()
    end,

    desc = "Run PRAGMA optimize",
  },

  SQLiteDebugPlan = {
    callback = function()
      query_plan()
    end,

    desc = "Show SQLite query plan",
  },

  SQLiteDebugQuickCheck = {
    callback = function()
      quick_check()
    end,

    desc = "Run SQLite quick check",
  },

  SQLiteDebugScanStatus = {
    callback = function()
      scanstatus()
    end,

    desc = "Profile SQLite statement with scanstatus",
  },

  SQLiteDebugSchema = {
    callback = function()
      schema()
    end,

    desc = "Show SQLite schema",
  },

  SQLiteDebugShell = {
    callback = function()
      open_shell()
    end,

    desc = "Open SQLite shell",
  },

  SQLiteDebugSQLite = {
    callback = function()
      select_sqlite3()
    end,

    desc = "Select sqlite3 executable",
  },

  SQLiteDebugStatus = {
    callback = function()
      status()
    end,

    desc = "Show SQLite debug status",
  },

  SQLiteDebugTables = {
    callback = function()
      tables()
    end,

    desc = "Show SQLite tables",
  },
}

---@type table<string, DebugMapping>
M.mappings = {
  sqlite_debug_bytecode = {
    lhs = "<leader>dQb",

    mode = "n",

    rhs = function()
      bytecode()
    end,

    desc = "Debug SQLite: VDBE bytecode",
  },

  sqlite_debug_database = {
    lhs = "<leader>dQd",

    mode = "n",

    rhs = function()
      select_database()
    end,

    desc = "Debug SQLite: Database",
  },

  sqlite_debug_execute = {
    lhs = "<leader>dQe",

    mode = "n",

    rhs = function()
      execute_statement()
    end,

    desc = "Debug SQLite: Execute",
  },

  sqlite_debug_full = {
    lhs = "<leader>dQf",

    mode = "n",

    rhs = function()
      eqp_full()
    end,

    desc = "Debug SQLite: EQP full",
  },

  sqlite_debug_plan = {
    lhs = "<leader>dQp",

    mode = "n",

    rhs = function()
      query_plan()
    end,

    desc = "Debug SQLite: Query plan",
  },

  sqlite_debug_scanstatus = {
    lhs = "<leader>dQr",

    mode = "n",

    rhs = function()
      scanstatus()
    end,

    desc = "Debug SQLite: Scan status",
  },

  sqlite_debug_shell = {
    lhs = "<leader>dQi",

    mode = "n",

    rhs = function()
      open_shell()
    end,

    desc = "Debug SQLite: Shell",
  },

  sqlite_debug_status = {
    lhs = "<leader>dQs",

    mode = "n",

    rhs = function()
      status()
    end,

    desc = "Debug SQLite: Status",
  },

  sqlite_debug_trace = {
    lhs = "<leader>dQt",

    mode = "n",

    rhs = function()
      eqp_trace()
    end,

    desc = "Debug SQLite: VDBE trace",
  },
}

---@param opts? table
function M.setup(opts)
  opts = opts or {}

  state.root =
    nonempty_string(opts.root)
        and fs.normalize(opts.root)
      or project_root()

  if resolve_sqlite3() == nil then
    vim.schedule(function()
      notify(
        table.concat({
          "sqlite3 was not found.",
          "",
          "Install SQLite or set:",
          "  NVIM_SQLITE_EXECUTABLE=/path/to/sqlite3",
        }, "\n"),
        levels.WARN
      )
    end)
  end

  if
    resolve_lldb_dap() == nil
    and not gdb_supports_dap()
  then
    vim.schedule(function()
      notify(
        table.concat({
          "No native SQLite debugger is available.",
          "",
          "SQL inspection remains fully usable.",
          "For native SQLite C debugging install either:",
          "  lldb-dap",
          "  gdb with DAP/Python support",
        }, "\n"),
        levels.DEBUG
      )
    end)
  elseif resolve_lldb_dap() == nil then
    state.adapter = "gdb"
  end
end

---@return string?
function M.sqlite3()
  return resolve_sqlite3()
end

---@return string?
function M.database()
  return resolve_database()
end

---@return string
function M.root()
  return project_root()
end

---@return boolean
function M.scanstatus_available()
  return has_scanstatus()
end

---@return boolean
function M.debug_build()
  return has_sqlite_debug()
end

---@return "lldb"|"gdb"
function M.active_adapter()
  return state.adapter
end

---@return boolean
function M.available()
  return resolve_sqlite3() ~= nil
end

return M