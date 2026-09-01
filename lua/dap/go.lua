-- #################################################################
-- ~/.config/nvim/lua/dap/go.lua
-- Qompass AI Diver Native Go Debug Adapter Configuration
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
---@source https://github.com/go-delve/delve
---@source https://github.com/go-delve/delve/blob/master/Documentation/usage/dlv_dap.md
---@source https://github.com/go-delve/delve/blob/master/service/dap/types.go

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local levels = vim.log.levels
local uv = vim.uv

local M = {}

local SOURCE = "go-dap"

---@type string[]
local ROOT_MARKERS = {
  "go.work",
  "go.mod",
  "go.sum",
  "vendor",
  ".git",
}

---@type string[]
local GO_EXECUTABLES = {
  "go",
}

---@type string[]
local DELVE_EXECUTABLES = {
  "dlv",
}

---@class GoDapState
---@field dlv string?
---@field go_executable string?
---@field root string?
---@field executable string?
local state = {
  dlv = nil,
  executable = nil,
  go_executable = nil,
  root = nil,
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
    fn.fnamemodify(path, ":p")
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

  local name = api.nvim_buf_get_name(bufnr)

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

---@return string?
local function resolve_dlv()
  if
    state.dlv ~= nil
    and executable(state.dlv)
  then
    return state.dlv
  end

  local configured = vim.env.NVIM_DLV_EXECUTABLE

  if nonempty_string(configured) then
    local candidate = normalize(
      fn.expand(configured)
    )

    if executable(candidate) then
      state.dlv = candidate

      return candidate
    end

    notify(
      ("NVIM_DLV_EXECUTABLE is not executable: %s"):format(
        candidate
      ),
      levels.WARN
    )
  end

  for _, command in ipairs(
    DELVE_EXECUTABLES
  ) do
    local candidate = executable_path(
      command
    )

    if candidate ~= nil then
      state.dlv = candidate

      return candidate
    end
  end

  return nil
end

---@return string?
local function resolve_go()
  if
    state.go_executable ~= nil
    and executable(state.go_executable)
  then
    return state.go_executable
  end

  local configured = vim.env.NVIM_GO_EXECUTABLE

  if nonempty_string(configured) then
    local candidate = normalize(
      fn.expand(configured)
    )

    if executable(candidate) then
      state.go_executable = candidate

      return candidate
    end

    notify(
      ("NVIM_GO_EXECUTABLE is not executable: %s"):format(
        candidate
      ),
      levels.WARN
    )
  end

  for _, command in ipairs(
    GO_EXECUTABLES
  ) do
    local candidate = executable_path(
      command
    )

    if candidate ~= nil then
      state.go_executable = candidate

      return candidate
    end
  end

  return nil
end

---@return string?
local function go_version()
  local go = resolve_go()

  if go == nil then
    return nil
  end

  local result = system({
    go,
    "version",
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

  return value
end

---@return string?
local function dlv_version()
  local dlv = resolve_dlv()

  if dlv == nil then
    return nil
  end

  local result = system({
    dlv,
    "version",
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

  return value
end

---@return string
local function cwd()
  local root = project_root()

  state.root = root

  return root
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
local function current_package()
  local current = filename()

  if current == "" then
    return project_root()
  end

  local parent = fs.dirname(current)

  if
    type(parent) == "string"
    and parent ~= ""
  then
    return parent
  end

  return project_root()
end

---@return string[]
local function prompt_args()
  local input = fn.input(
    "Go program arguments: "
  )

  if input == "" then
    return {}
  end

  return fn.shellsplit(input)
end

---@return string[]
local function prompt_test_args()
  local input = fn.input(
    "Go test arguments: ",
    "-test.v"
  )

  if input == "" then
    return {}
  end

  return fn.shellsplit(input)
end

---@return string[]
local function prompt_build_flags()
  local input = fn.input(
    "Go build flags: "
  )

  if input == "" then
    return {}
  end

  return fn.shellsplit(input)
end

---@return table<string, string>
local function prompt_environment()
  local input = fn.input(
    "Environment KEY=VALUE pairs: "
  )

  if input == "" then
    return {}
  end

  ---@type table<string, string>
  local result = {}

  for _, item in ipairs(
    fn.shellsplit(input)
  ) do
    local key, value =
      item:match(
        "^([%a_][%w_]*)=(.*)$"
      )

    if key ~= nil then
      result[key] = value
    else
      notify(
        ("ignoring invalid environment assignment: %s"):format(
          item
        ),
        levels.WARN
      )
    end
  end

  return result
end

---@return integer
local function prompt_pid()
  local input = fn.input(
    "Go process PID: "
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
local function prompt_process_prefix()
  return fn.input(
    "Wait for process name prefix: "
  )
end

---@return string
local function prompt_executable()
  local default = state.executable
    or fs.joinpath(
      project_root(),
      "bin",
      ""
    )

  local selected = fn.input(
    "Go executable: ",
    default,
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
      ("not an executable file: %s"):format(
        selected
      ),
      levels.ERROR
    )

    return ""
  end

  state.executable = selected

  return selected
end

---@return string
local function prompt_core_file()
  local selected = fn.input(
    "Core dump: ",
    project_root(),
    "file"
  )

  if selected == "" then
    return ""
  end

  selected = normalize(
    fn.expand(selected)
  )

  if not is_file(selected) then
    notify(
      ("core file does not exist: %s"):format(
        selected
      ),
      levels.ERROR
    )

    return ""
  end

  return selected
end

---@return string
local function prompt_trace_directory()
  local selected = fn.input(
    "rr trace directory: ",
    project_root(),
    "dir"
  )

  if selected == "" then
    return ""
  end

  selected = normalize(
    fn.expand(selected)
  )

  if not is_directory(selected) then
    notify(
      ("trace directory does not exist: %s"):format(
        selected
      ),
      levels.ERROR
    )

    return ""
  end

  return selected
end

---@return string
local function prompt_remote_host()
  local value = fn.input(
    "Remote Delve host: ",
    "127.0.0.1"
  )

  if value == "" then
    return "127.0.0.1"
  end

  return value
end

---@return integer
local function prompt_remote_port()
  local value = fn.input(
    "Remote Delve port: ",
    "2345"
  )

  local port = tonumber(value)

  if
    port == nil
    or port < 1
    or port > 65535
  then
    notify(
      ("invalid Delve port: %s"):format(
        value
      ),
      levels.ERROR
    )

    return 2345
  end

  return math.floor(port)
end

---@return table[]
local function prompt_substitute_path()
  local from = fn.input(
    "Local source root: ",
    project_root(),
    "dir"
  )

  if from == "" then
    return {}
  end

  local to = fn.input(
    "Remote source root: "
  )

  if to == "" then
    return {}
  end

  return {
    {
      from = normalize(
        fn.expand(from)
      ),

      to = to,
    },
  }
end

---@return string
local function dlv_command()
  return resolve_dlv()
    or "dlv"
end

local function select_dlv()
  local selected = fn.input(
    "Delve executable: ",
    resolve_dlv() or "",
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

  state.dlv = selected

  if
    type(M.adapter) == "table"
    and type(M.adapter.executable) == "table"
  then
    M.adapter.executable.command = selected
  end

  notify(
    ("Delve executable: %s"):format(
      selected
    )
  )
end

local function select_go()
  local selected = fn.input(
    "Go executable: ",
    resolve_go() or "",
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

  state.go_executable = selected

  notify(
    ("Go executable: %s"):format(
      selected
    )
  )
end

local function clear_cache()
  state.dlv = nil
  state.executable = nil
  state.go_executable = nil
  state.root = nil

  notify(
    "Go DAP discovery cache cleared"
  )
end

local function status()
  local dlv = resolve_dlv()
  local go = resolve_go()

  notify(
    table.concat({
      "root: "
        .. project_root(),

      "Go: "
        .. (go or "not found"),

      "Go version: "
        .. (go_version() or "unknown"),

      "Delve: "
        .. (dlv or "not found"),

      "Delve version:\n"
        .. (dlv_version() or "unknown"),

      "cached executable: "
        .. (state.executable or "none"),

      "transport: tcp://127.0.0.1:<ephemeral>",
    }, "\n"),
    (
      dlv ~= nil
      and go ~= nil
    )
        and levels.INFO
      or levels.WARN
  )
end

--
-- `dlv dap` is a standalone, headless TCP DAP server. Using 127.0.0.1
-- avoids exposing the debugger outside the local host.
--
---@type table
M.adapter = {
  name = "go-delve",

  type = "server",

  host = "127.0.0.1",

  port = "${port}",

  executable = {
    command = dlv_command(),

    args = {
      "dap",

      "--listen",
      "127.0.0.1:${port}",
    },
  },
}

---@type table[]
local configurations = {
  --
  -- Delve debug mode builds the current package with optimizations disabled
  -- and starts the resulting program under the debugger.
  --
  {
    name = "Go: Debug Current Package",

    type = "go-delve",

    request = "launch",

    mode = "debug",

    program = current_package,

    cwd = cwd,

    dlvCwd = cwd,

    stopOnEntry = false,

    backend = "default",

    showGlobalVariables = true,

    hideSystemGoroutines = true,

    stackTraceDepth = 100,

    maxStringLen = 4096,

    maxArrayValues = 256,
  },

  {
    name = "Go: Debug Current Package with Arguments",

    type = "go-delve",

    request = "launch",

    mode = "debug",

    program = current_package,

    cwd = cwd,

    dlvCwd = cwd,

    args = prompt_args,

    stopOnEntry = false,

    backend = "default",

    showGlobalVariables = true,

    hideSystemGoroutines = true,

    stackTraceDepth = 100,

    maxStringLen = 4096,

    maxArrayValues = 256,
  },

  {
    name = "Go: Debug Current Package with Build Flags",

    type = "go-delve",

    request = "launch",

    mode = "debug",

    program = current_package,

    cwd = cwd,

    dlvCwd = cwd,

    buildFlags = prompt_build_flags,

    args = prompt_args,

    stopOnEntry = false,

    backend = "default",

    showGlobalVariables = true,

    hideSystemGoroutines = true,
  },

  {
    name = "Go: Debug Current Package with Environment",

    type = "go-delve",

    request = "launch",

    mode = "debug",

    program = current_package,

    cwd = cwd,

    dlvCwd = cwd,

    env = prompt_environment,

    args = prompt_args,

    stopOnEntry = false,

    showGlobalVariables = true,

    hideSystemGoroutines = true,
  },

  --
  -- A Go source file is accepted by Delve as the program path in debug/test
  -- modes, so this is useful for isolated main packages.
  --
  {
    name = "Go: Debug Current File",

    type = "go-delve",

    request = "launch",

    mode = "debug",

    program = current_file,

    cwd = cwd,

    dlvCwd = cwd,

    stopOnEntry = false,

    showGlobalVariables = true,

    hideSystemGoroutines = true,
  },

  --
  -- Test mode is native Delve functionality and compiles the package's test
  -- binary with debugging enabled.
  --
  {
    name = "Go: Test Current Package",

    type = "go-delve",

    request = "launch",

    mode = "test",

    program = current_package,

    cwd = cwd,

    dlvCwd = cwd,

    args = {
      "-test.v",
    },

    stopOnEntry = false,

    showGlobalVariables = true,

    hideSystemGoroutines = true,
  },

  {
    name = "Go: Test Current Package with Arguments",

    type = "go-delve",

    request = "launch",

    mode = "test",

    program = current_package,

    cwd = cwd,

    dlvCwd = cwd,

    args = prompt_test_args,

    buildFlags = prompt_build_flags,

    stopOnEntry = false,

    showGlobalVariables = true,

    hideSystemGoroutines = true,
  },

  --
  -- Exec mode skips compilation and debugs an existing Go binary.
  --
  {
    name = "Go: Debug Existing Executable",

    type = "go-delve",

    request = "launch",

    mode = "exec",

    program = prompt_executable,

    cwd = cwd,

    args = prompt_args,

    stopOnEntry = false,

    showGlobalVariables = true,

    hideSystemGoroutines = true,
  },

  {
    name = "Go: Debug Existing Executable (Stop on Entry)",

    type = "go-delve",

    request = "launch",

    mode = "exec",

    program = prompt_executable,

    cwd = cwd,

    args = prompt_args,

    stopOnEntry = true,

    showGlobalVariables = true,

    hideSystemGoroutines = true,
  },

  --
  -- Local attach is handled directly by the DAP server.
  --
  {
    name = "Go: Attach PID",

    type = "go-delve",

    request = "attach",

    mode = "local",

    processId = prompt_pid,

    stopOnEntry = false,

    showGlobalVariables = true,

    hideSystemGoroutines = true,
  },

  {
    name = "Go: Wait for Process",

    type = "go-delve",

    request = "attach",

    mode = "local",

    waitFor = prompt_process_prefix,

    stopOnEntry = false,

    showGlobalVariables = true,

    hideSystemGoroutines = true,
  },

  --
  -- Remote mode connects the DAP client to an already-running headless Delve
  -- server. `substitutePath` is useful for containers, SSH hosts and other
  -- environments where source paths differ.
  --
  {
    name = "Go: Remote Delve",

    type = "go-delve-remote",

    request = "attach",

    mode = "remote",

    substitutePath = prompt_substitute_path,

    showGlobalVariables = true,

    hideSystemGoroutines = true,
  },

  --
  -- Linux core-file debugging.
  --
  {
    name = "Go: Core Dump",

    type = "go-delve",

    request = "launch",

    mode = "core",

    program = prompt_executable,

    coreFilePath = prompt_core_file,

    cwd = cwd,

    showGlobalVariables = true,

    hideSystemGoroutines = true,
  },

  --
  -- Delve can replay traces created by Mozilla rr.
  --
  {
    name = "Go: Replay rr Trace",

    type = "go-delve",

    request = "launch",

    mode = "replay",

    traceDirPath = prompt_trace_directory,

    cwd = cwd,

    stopOnEntry = false,

    showGlobalVariables = true,

    hideSystemGoroutines = true,
  },
}

---@type table<string, table>
M.adapters = {
  ["go-delve"] = M.adapter,

  --
  -- Unlike local `dlv dap`, this adapter does not spawn Delve. It connects
  -- directly to a DAP-capable Delve server already running elsewhere.
  --
  ["go-delve-remote"] = {
    name = "go-delve-remote",

    type = "server",

    host = prompt_remote_host,

    port = prompt_remote_port,
  },
}

---@type table<string, table[]>
M.configurations = {
  go = configurations,
}

---@type table<string, DebugCommand>
M.commands = {
  GoDebugClear = {
    callback = function()
      clear_cache()
    end,

    desc = "Clear Go debug discovery cache",
  },

  GoDebugDlv = {
    callback = function()
      select_dlv()
    end,

    desc = "Select Delve executable",
  },

  GoDebugGo = {
    callback = function()
      select_go()
    end,

    desc = "Select Go executable",
  },

  GoDebugStatus = {
    callback = function()
      status()
    end,

    desc = "Show Go debug status",
  },
}

---@type table<string, DebugMapping>
M.mappings = {
  go_debug_dlv = {
    lhs = "<leader>dGd",

    mode = "n",

    rhs = function()
      select_dlv()
    end,

    desc = "Debug Go: Select Delve",
  },

  go_debug_go = {
    lhs = "<leader>dGg",

    mode = "n",

    rhs = function()
      select_go()
    end,

    desc = "Debug Go: Select Go",
  },

  go_debug_status = {
    lhs = "<leader>dGs",

    mode = "n",

    rhs = function()
      status()
    end,

    desc = "Debug Go: Status",
  },
}

---@param opts? table
function M.setup(opts)
  opts = opts or {}

  state.root =
    nonempty_string(opts.root)
        and fs.normalize(opts.root)
      or project_root()

  local dlv = resolve_dlv()
  local go = resolve_go()

  if dlv ~= nil then
    M.adapter.executable.command = dlv
  end

  if go == nil then
    vim.schedule(function()
      notify(
        table.concat({
          "Go toolchain was not found.",
          "",
          "Install Go or set:",
          "  NVIM_GO_EXECUTABLE=/path/to/go",
        }, "\n"),
        levels.ERROR
      )
    end)
  end

  if dlv == nil then
    vim.schedule(function()
      notify(
        table.concat({
          "Delve was not found.",
          "",
          "Install `dlv` or set:",
          "  NVIM_DLV_EXECUTABLE=/path/to/dlv",
        }, "\n"),
        levels.ERROR
      )
    end)
  end
end

---@return string?
function M.dlv()
  return resolve_dlv()
end

---@return string?
function M.go()
  return resolve_go()
end

---@return string
function M.root()
  return project_root()
end

---@return boolean
function M.available()
  return resolve_go() ~= nil
    and resolve_dlv() ~= nil
end

return M