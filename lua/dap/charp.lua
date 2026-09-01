-- #################################################################
-- ~/.config/nvim/lua/dap/csharp.lua
-- Qompass AI Diver Native C# / Razor Debug Adapter Configuration
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
---@source https://github.com/Samsung/netcoredbg
---@source https://learn.microsoft.com/dotnet/core/tools/

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local levels = vim.log.levels
local uv = vim.uv

local M = {}

local SOURCE = "csharp-dap"

---@type string[]
local ROOT_MARKERS = {
  "Directory.Build.props",
  "Directory.Build.targets",
  "Directory.Packages.props",
  "global.json",
  ".slnx",
  ".sln",
  ".git",
}

---@type string[]
local BUILD_CONFIGURATIONS = {
  "Debug",
  "Release",
}

---@class CSharpDapState
---@field dll string?
---@field dotnet string?
---@field netcoredbg string?
---@field project string?
---@field root string?
local state = {
  dll = nil,
  dotnet = nil,
  netcoredbg = nil,
  project = nil,
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

---@param directory string
---@param suffix string
---@return string?
local function first_file_with_suffix(
  directory,
  suffix
)
  if not is_directory(directory) then
    return nil
  end

  for name, kind in fs.dir(directory) do
    if
      kind == "file"
      and name:sub(-#suffix) == suffix
    then
      return fs.normalize(
        fs.joinpath(
          directory,
          name
        )
      )
    end
  end

  return nil
end

---@param start string
---@param suffix string
---@return string?
local function find_upward_file(
  start,
  suffix
)
  local directory = start

  while nonempty_string(directory) do
    local found = first_file_with_suffix(
      directory,
      suffix
    )

    if found ~= nil then
      return found
    end

    local parent = fs.dirname(directory)

    if
      parent == nil
      or parent == directory
    then
      break
    end

    directory = parent
  end

  return nil
end

---@return string?
local function resolve_netcoredbg()
  if
    state.netcoredbg ~= nil
    and executable(state.netcoredbg)
  then
    return state.netcoredbg
  end

  local configured =
    vim.env.NVIM_NETCOREDBG

  if nonempty_string(configured) then
    local candidate = normalize(
      fn.expand(configured)
    )

    if executable(candidate) then
      state.netcoredbg = candidate

      return candidate
    end

    notify(
      ("NVIM_NETCOREDBG is not executable: %s"):format(
        candidate
      ),
      levels.WARN
    )
  end

  local candidate =
    executable_path("netcoredbg")

  if candidate ~= nil then
    state.netcoredbg = candidate

    return candidate
  end

  return nil
end

---@return string?
local function resolve_dotnet()
  if
    state.dotnet ~= nil
    and executable(state.dotnet)
  then
    return state.dotnet
  end

  local configured =
    vim.env.NVIM_DOTNET_EXECUTABLE

  if nonempty_string(configured) then
    local candidate = normalize(
      fn.expand(configured)
    )

    if executable(candidate) then
      state.dotnet = candidate

      return candidate
    end

    notify(
      ("NVIM_DOTNET_EXECUTABLE is not executable: %s"):format(
        candidate
      ),
      levels.WARN
    )
  end

  local candidate =
    executable_path("dotnet")

  if candidate ~= nil then
    state.dotnet = candidate

    return candidate
  end

  return nil
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

---@param executable_name string
---@return string?
local function tool_version(executable_name)
  local path = executable_path(
    executable_name
  )

  if path == nil then
    return nil
  end

  local result = system({
    path,
    "--version",
  })

  if
    result == nil
    or result.code ~= 0
  then
    return nil
  end

  local output = vim.trim(
    result.stdout or ""
  )

  if output == "" then
    output = vim.trim(
      result.stderr or ""
    )
  end

  if output == "" then
    return nil
  end

  return output:match("[^\r\n]+")
end

---@return string?
local function current_project()
  local root = project_root()

  if
    state.root == root
    and state.project ~= nil
    and is_file(state.project)
  then
    return state.project
  end

  local current = filename()
  local start = current ~= ""
      and fs.dirname(current)
    or root

  if start ~= nil then
    local project =
      find_upward_file(
        start,
        ".csproj"
      )

    if project ~= nil then
      state.root = root
      state.project = project

      return project
    end
  end

  local root_project =
    first_file_with_suffix(
      root,
      ".csproj"
    )

  if root_project ~= nil then
    state.root = root
    state.project = root_project

    return root_project
  end

  return nil
end

---@return string
local function project_directory()
  local project =
    current_project()

  if project ~= nil then
    return fs.dirname(project)
      or project_root()
  end

  return project_root()
end

---@return string
local function project_name()
  local project =
    current_project()

  if project == nil then
    return ""
  end

  return fs.basename(project):gsub(
    "%.csproj$",
    ""
  )
end

---@param root string
---@param result string[]
---@param depth integer
local function collect_dlls(
  root,
  result,
  depth
)
  if
    depth > 8
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
        name ~= "obj"
        and name ~= "ref"
        and name ~= "refint"
      then
        collect_dlls(
          path,
          result,
          depth + 1
        )
      end
    elseif
      kind == "file"
      and name:sub(-4) == ".dll"
    then
      result[#result + 1] =
        fs.normalize(path)
    end
  end
end

---@return string[]
local function dll_candidates()
  local bin = fs.joinpath(
    project_directory(),
    "bin"
  )

  if not is_directory(bin) then
    return {}
  end

  ---@type string[]
  local result = {}

  collect_dlls(
    bin,
    result,
    0
  )

  local expected =
    project_name() .. ".dll"

  table.sort(
    result,
    function(left, right)
      local left_name =
        fs.basename(left)

      local right_name =
        fs.basename(right)

      if
        left_name == expected
        and right_name ~= expected
      then
        return true
      end

      if
        right_name == expected
        and left_name ~= expected
      then
        return false
      end

      local left_debug =
        left:find(
          "/Debug/",
          1,
          true
        ) ~= nil

      local right_debug =
        right:find(
          "/Debug/",
          1,
          true
        ) ~= nil

      if left_debug ~= right_debug then
        return left_debug
      end

      return left < right
    end
  )

  return result
end

---@return string?
local function choose_dll()
  if
    state.dll ~= nil
    and is_file(state.dll)
  then
    return state.dll
  end

  local candidates =
    dll_candidates()

  if #candidates == 1 then
    state.dll = candidates[1]

    return state.dll
  end

  if #candidates > 1 then
    local choices = {
      "Choose .NET assembly:",
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

    local selected =
      fn.inputlist(choices)

    if
      selected >= 1
      and selected <= #candidates
    then
      state.dll =
        candidates[selected]

      return state.dll
    end
  end

  local selected = fn.input(
    ".NET assembly: ",
    fs.joinpath(
      project_directory(),
      "bin",
      "Debug",
      ""
    ),
    "file"
  )

  if selected == "" then
    return nil
  end

  selected = normalize(
    fn.expand(selected)
  )

  if not is_file(selected) then
    notify(
      ("assembly does not exist: %s"):format(
        selected
      ),
      levels.ERROR
    )

    return nil
  end

  state.dll = selected

  return selected
end

---@return string
local function debug_program()
  return choose_dll()
    or ""
end

---@return string[]
local function prompt_args()
  local input = fn.input(
    "Program arguments: "
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
    local key, value = item:match(
      "^([%a_][%w_]*)=(.*)$"
    )

    if key ~= nil then
      result[key] = value
    else
      notify(
        (
          "ignoring invalid environment assignment: %s"
        ):format(item),
        levels.WARN
      )
    end
  end

  return result
end

---@return string
local function prompt_configuration()
  local choices = {
    "Build configuration:",
  }

  for index, configuration in ipairs(
    BUILD_CONFIGURATIONS
  ) do
    choices[#choices + 1] =
      ("%d. %s"):format(
        index,
        configuration
      )
  end

  local selected =
    fn.inputlist(choices)

  if
    selected >= 1
    and selected <= #BUILD_CONFIGURATIONS
  then
    return BUILD_CONFIGURATIONS[selected]
  end

  return "Debug"
end

---@param configuration? string
---@return boolean
local function build_project(configuration)
  local dotnet =
    resolve_dotnet()

  if dotnet == nil then
    notify(
      "dotnet was not found",
      levels.ERROR
    )

    return false
  end

  local project =
    current_project()

  if project == nil then
    notify(
      "no .csproj was found for the current buffer",
      levels.ERROR
    )

    return false
  end

  configuration = configuration
    or "Debug"

  local result = system(
    {
      dotnet,
      "build",
      project,
      "--configuration",
      configuration,
      "--nologo",
    },
    fs.dirname(project)
  )

  if result == nil then
    notify(
      "failed to invoke dotnet build",
      levels.ERROR
    )

    return false
  end

  if result.code ~= 0 then
    local output = vim.trim(
      result.stderr
        or result.stdout
        or "dotnet build failed"
    )

    notify(
      output ~= ""
          and output
        or "dotnet build failed",
      levels.ERROR
    )

    return false
  end

  state.dll = nil

  return true
end

---@return string
local function build_then_program()
  if not build_project("Debug") then
    return ""
  end

  return debug_program()
end

---@return integer
local function prompt_pid()
  local input = fn.input(
    ".NET process PID: "
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

---@return table[]
local function dotnet_processes()
  local result = system({
    "ps",
    "-eo",
    "pid=,comm=,args=",
  })

  if
    result == nil
    or result.code ~= 0
  then
    return {}
  end

  ---@type table[]
  local processes = {}

  for line in (
    result.stdout or ""
  ):gmatch("[^\r\n]+") do
    local pid,
      command,
      arguments = line:match(
      "^%s*(%d+)%s+(%S+)%s*(.*)$"
    )

    if
      pid ~= nil
      and command ~= nil
    then
      local lower_command =
        command:lower()

      local lower_arguments =
        (arguments or ""):lower()

      if
        lower_command == "dotnet"
        or lower_arguments:find(
          "dotnet",
          1,
          true
        ) ~= nil
      then
        processes[#processes + 1] = {
          arguments = arguments or "",
          command = command,
          pid = tonumber(pid),
        }
      end
    end
  end

  return processes
end

---@return integer
local function choose_dotnet_process()
  local processes =
    dotnet_processes()

  if #processes == 0 then
    notify(
      "no CoreCLR/dotnet processes found",
      levels.WARN
    )

    return 0
  end

  local choices = {
    "Choose .NET process:",
  }

  for index, process in ipairs(
    processes
  ) do
    choices[#choices + 1] =
      ("%d. PID %-7d %s %s"):format(
        index,
        process.pid,
        process.command,
        process.arguments
      )
  end

  local selected =
    fn.inputlist(choices)

  if
    selected < 1
    or selected > #processes
  then
    return 0
  end

  return processes[selected].pid
end

local function select_netcoredbg()
  local selected = fn.input(
    "NetCoreDbg executable: ",
    resolve_netcoredbg() or "",
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

  state.netcoredbg = selected

  if type(M.adapter) == "table" then
    M.adapter.command = selected
  end

  notify(
    ("NetCoreDbg: %s"):format(
      selected
    )
  )
end

local function select_dotnet()
  local selected = fn.input(
    "dotnet executable: ",
    resolve_dotnet() or "",
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

  state.dotnet = selected

  notify(
    ("dotnet: %s"):format(
      selected
    )
  )
end

local function clear_cache()
  state.dll = nil
  state.dotnet = nil
  state.netcoredbg = nil
  state.project = nil
  state.root = nil

  notify(
    "C# DAP discovery cache cleared"
  )
end

local function status()
  notify(
    table.concat({
      "root: "
        .. project_root(),

      "project: "
        .. (
          current_project()
            or "none"
        ),

      "dotnet: "
        .. (
          resolve_dotnet()
            or "not found"
        ),

      "dotnet version: "
        .. (
          tool_version("dotnet")
            or "unknown"
        ),

      "netcoredbg: "
        .. (
          resolve_netcoredbg()
            or "not found"
        ),

      "cached assembly: "
        .. (
          state.dll
            or "none"
        ),

      "runtime: CoreCLR",
    }, "\n")
  )
end

--
-- NetCoreDbg exposes VS Code DAP over stdin/stdout with:
--
--   netcoredbg --interpreter=vscode
--
---@type table
M.adapter = {
  name = "coreclr",

  type = "executable",

  command = resolve_netcoredbg()
    or "netcoredbg",

  args = {
    "--interpreter=vscode",
  },

  options = {
    source_filetype = "cs",
  },
}

---@type table[]
local configurations = {
  {
    name = ".NET: Build Debug + Launch",

    type = "coreclr",

    request = "launch",

    program = build_then_program,

    cwd = project_directory,

    args = {},

    env = {},

    stopAtEntry = false,

    console = "integratedTerminal",
  },

  {
    name = ".NET: Launch Built Assembly",

    type = "coreclr",

    request = "launch",

    program = debug_program,

    cwd = project_directory,

    args = {},

    env = {},

    stopAtEntry = false,

    console = "integratedTerminal",
  },

  {
    name = ".NET: Launch with Arguments",

    type = "coreclr",

    request = "launch",

    program = debug_program,

    cwd = project_directory,

    args = prompt_args,

    env = prompt_environment,

    stopAtEntry = false,

    console = "integratedTerminal",
  },

  {
    name = ".NET: Stop at Entry",

    type = "coreclr",

    request = "launch",

    program = debug_program,

    cwd = project_directory,

    args = {},

    env = {},

    stopAtEntry = true,

    console = "integratedTerminal",
  },

  {
    name = ".NET: Attach Chosen CoreCLR Process",

    type = "coreclr",

    request = "attach",

    processId = choose_dotnet_process,
  },

  {
    name = ".NET: Attach PID",

    type = "coreclr",

    request = "attach",

    processId = prompt_pid,
  },
}

--
-- Razor executes inside the associated ASP.NET Core host process, so it uses
-- the same CoreCLR adapter/configuration set as C#.
--
---@type table<string, table[]>
M.configurations = {
  cs = configurations,

  razor = configurations,
}

---@type table<string, DebugCommand>
M.commands = {
  CSharpDebugBuild = {
    callback = function()
      build_project(
        prompt_configuration()
      )
    end,

    desc = "Build current C# project",
  },

  CSharpDebugClear = {
    callback = function()
      clear_cache()
    end,

    desc = "Clear C# debugger discovery cache",
  },

  CSharpDebugDotnet = {
    callback = function()
      select_dotnet()
    end,

    desc = "Select dotnet executable",
  },

  CSharpDebugNetCoreDbg = {
    callback = function()
      select_netcoredbg()
    end,

    desc = "Select NetCoreDbg executable",
  },

  CSharpDebugStatus = {
    callback = function()
      status()
    end,

    desc = "Show C# debugger status",
  },
}

---@type table<string, DebugMapping>
M.mappings = {
  csharp_debug_build = {
    lhs = "<leader>dCb",

    mode = "n",

    rhs = function()
      build_project(
        prompt_configuration()
      )
    end,

    desc = "Debug C#: Build",
  },

  csharp_debug_dotnet = {
    lhs = "<leader>dCd",

    mode = "n",

    rhs = function()
      select_dotnet()
    end,

    desc = "Debug C#: Select dotnet",
  },

  csharp_debug_netcoredbg = {
    lhs = "<leader>dCn",

    mode = "n",

    rhs = function()
      select_netcoredbg()
    end,

    desc = "Debug C#: Select NetCoreDbg",
  },

  csharp_debug_status = {
    lhs = "<leader>dCs",

    mode = "n",

    rhs = function()
      status()
    end,

    desc = "Debug C#: Status",
  },
}

---@param opts? table
function M.setup(opts)
  opts = opts or {}

  state.root =
    nonempty_string(opts.root)
        and fs.normalize(opts.root)
      or project_root()

  local debugger =
    resolve_netcoredbg()

  local dotnet =
    resolve_dotnet()

  if debugger ~= nil then
    M.adapter.command =
      debugger
  end

  if debugger == nil then
    vim.schedule(function()
      notify(
        table.concat({
          "NetCoreDbg was not found.",
          "",
          "Install `netcoredbg` or set:",
          "  NVIM_NETCOREDBG=/path/to/netcoredbg",
        }, "\n"),
        levels.ERROR
      )
    end)
  end

  if dotnet == nil then
    vim.schedule(function()
      notify(
        table.concat({
          ".NET SDK/runtime was not found.",
          "",
          "Install `dotnet` or set:",
          "  NVIM_DOTNET_EXECUTABLE=/path/to/dotnet",
        }, "\n"),
        levels.WARN
      )
    end)
  end
end

---@return string?
function M.netcoredbg()
  return resolve_netcoredbg()
end

---@return string?
function M.dotnet()
  return resolve_dotnet()
end

---@return string
function M.root()
  return project_root()
end

---@return string?
function M.project()
  return current_project()
end

---@return boolean
function M.available()
  return resolve_netcoredbg() ~= nil
    and resolve_dotnet() ~= nil
end

return M