-- #################################################################
-- ~/.config/nvim/lua/dap/unreal.lua
-- Qompass AI Diver Native Unreal Engine Debug Adapter Configuration
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
---@source https://dev.epicgames.com/documentation/unreal-engine/using-the-gameplay-debugger-in-unreal-engine
---@source https://dev.epicgames.com/documentation/unreal-engine/build-configurations-reference-for-unreal-engine
---@source https://dev.epicgames.com/documentation/unreal-engine/linux-development-quickstart-for-unreal-engine
---@source https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap
---@source https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local levels = vim.log.levels
local uv = vim.uv

local M = {}

local SOURCE = "unreal-dap"

---@type string[]
local ROOT_MARKERS = {
  ".uproject",
  "Config",
  "Content",
  "Source",
  "Plugins",
  ".git",
}

---@type string[]
local ENGINE_ENVIRONMENT_VARIABLES = {
  "NVIM_UNREAL_ENGINE_ROOT",
  "UNREAL_ENGINE_ROOT",
  "UE_ENGINE_ROOT",
  "UE_ROOT",
}

---@type string[]
local ENGINE_ROOT_CANDIDATES = {
  fs.joinpath(
    fn.expand("~"),
    "UnrealEngine"
  ),

  fs.joinpath(
    fn.expand("~"),
    "UnrealEngine-5"
  ),

  fs.joinpath(
    fn.expand("~"),
    "UnrealEngine-5.8"
  ),

  fs.joinpath(
    fn.expand("~"),
    ".local",
    "share",
    "UnrealEngine"
  ),

  "/opt/UnrealEngine",

  "/opt/unreal-engine",
}

---@type string[]
local BUILD_CONFIGURATIONS = {
  "DebugGame",
  "Development",
  "Debug",
}

---@type string[]
local TARGET_KINDS = {
  "Editor",
  "Game",
  "Client",
  "Server",
}

---@class UnrealDapState
---@field adapter "lldb"|"gdb"
---@field engine_root string?
---@field editor string?
---@field executable string?
---@field project_root string?
---@field uproject string?
local state = {
  adapter = "lldb",
  editor = nil,
  engine_root = nil,
  executable = nil,
  project_root = nil,
  uproject = nil,
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

---@param directory string
---@return string?
local function uproject_in_directory(directory)
  if not is_directory(directory) then
    return nil
  end

  for name, kind in fs.dir(directory) do
    if
      kind == "file"
      and name:sub(-9) == ".uproject"
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
---@return string?
local function find_uproject_upward(start)
  local directory = start

  while
    nonempty_string(directory)
  do
    local project =
      uproject_in_directory(directory)

    if project ~= nil then
      return project
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

---@param bufnr? integer
---@return string?
local function resolve_uproject(bufnr)
  bufnr = bufnr
    or api.nvim_get_current_buf()

  if
    state.uproject ~= nil
    and is_file(state.uproject)
  then
    return state.uproject
  end

  local configured =
    vim.env.NVIM_UNREAL_PROJECT

  if nonempty_string(configured) then
    local candidate = normalize(
      fn.expand(configured)
    )

    if
      is_file(candidate)
      and candidate:sub(-9) == ".uproject"
    then
      state.uproject = candidate

      return candidate
    end
  end

  local current = filename(bufnr)

  if current ~= "" then
    local start =
      fs.dirname(current)

    if start ~= nil then
      local candidate =
        find_uproject_upward(start)

      if candidate ~= nil then
        state.uproject = candidate

        return candidate
      end
    end
  end

  local cwd = fs.normalize(
    fn.getcwd()
  )

  local candidate =
    find_uproject_upward(cwd)

  if candidate ~= nil then
    state.uproject = candidate

    return candidate
  end

  return nil
end

---@param bufnr? integer
---@return string
local function project_root(bufnr)
  local uproject =
    resolve_uproject(bufnr)

  if uproject ~= nil then
    local root =
      fs.dirname(uproject)

    if root ~= nil then
      state.project_root =
        fs.normalize(root)

      return state.project_root
    end
  end

  local current = filename(bufnr)

  if current ~= "" then
    local detected = fs.root(
      current,
      {
        ".git",
      }
    )

    if
      type(detected) == "string"
      and detected ~= ""
    then
      return fs.normalize(detected)
    end

    local parent =
      fs.dirname(current)

    if parent ~= nil then
      return fs.normalize(parent)
    end
  end

  return fs.normalize(
    fn.getcwd()
  )
end

---@return boolean
local function is_unreal_project()
  local project =
    resolve_uproject()

  if project == nil then
    return false
  end

  local root =
    fs.dirname(project)

  if root == nil then
    return false
  end

  return is_directory(
    fs.joinpath(
      root,
      "Source"
    )
  ) or is_directory(
    fs.joinpath(
      root,
      "Content"
    )
  )
end

---@return string
local function project_name()
  local project =
    resolve_uproject()

  if project == nil then
    return ""
  end

  return fs.basename(project):gsub(
    "%.uproject$",
    ""
  )
end

---@param root string
---@return boolean
local function valid_engine_root(root)
  return is_file(
    fs.joinpath(
      root,
      "Engine",
      "Binaries",
      "Linux",
      "UnrealEditor"
    )
  )
end

---@return string?
local function scan_home_engines()
  local home = fn.expand("~")

  if not is_directory(home) then
    return nil
  end

  ---@type string[]
  local candidates = {}

  for name, kind in fs.dir(home) do
    if
      kind == "directory"
      and (
        name:match("^UnrealEngine")
        or name:match("^UE_5")
      )
    then
      local candidate =
        fs.joinpath(
          home,
          name
        )

      if valid_engine_root(candidate) then
        candidates[#candidates + 1] =
          fs.normalize(candidate)
      end
    end
  end

  table.sort(
    candidates,
    function(left, right)
      return left > right
    end
  )

  return candidates[1]
end

---@return string?
local function resolve_engine_root()
  if
    state.engine_root ~= nil
    and valid_engine_root(
      state.engine_root
    )
  then
    return state.engine_root
  end

  for _, name in ipairs(
    ENGINE_ENVIRONMENT_VARIABLES
  ) do
    local configured =
      vim.env[name]

    if nonempty_string(configured) then
      local candidate = normalize(
        fn.expand(configured)
      )

      if valid_engine_root(candidate) then
        state.engine_root =
          candidate

        return candidate
      end
    end
  end

  for _, candidate in ipairs(
    ENGINE_ROOT_CANDIDATES
  ) do
    if valid_engine_root(candidate) then
      state.engine_root =
        fs.normalize(candidate)

      return state.engine_root
    end
  end

  local scanned =
    scan_home_engines()

  if scanned ~= nil then
    state.engine_root = scanned

    return scanned
  end

  return nil
end

---@return string?
local function resolve_editor()
  if
    state.editor ~= nil
    and executable(state.editor)
  then
    return state.editor
  end

  local configured =
    vim.env.NVIM_UNREAL_EDITOR

  if nonempty_string(configured) then
    local candidate = normalize(
      fn.expand(configured)
    )

    if executable(candidate) then
      state.editor = candidate

      return candidate
    end
  end

  local root =
    resolve_engine_root()

  if root == nil then
    return nil
  end

  local candidate = fs.joinpath(
    root,
    "Engine",
    "Binaries",
    "Linux",
    "UnrealEditor"
  )

  if executable(candidate) then
    state.editor =
      fs.normalize(candidate)

    return state.editor
  end

  return nil
end

---@return string?
local function resolve_build_script()
  local root =
    resolve_engine_root()

  if root == nil then
    return nil
  end

  local candidate = fs.joinpath(
    root,
    "Engine",
    "Build",
    "BatchFiles",
    "Linux",
    "Build.sh"
  )

  if is_file(candidate) then
    return fs.normalize(candidate)
  end

  return nil
end

---@return string?
local function lldb_dap()
  local configured =
    vim.env.NVIM_UNREAL_LLDB_DAP
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
local function gdb()
  local configured =
    vim.env.NVIM_UNREAL_GDB_DAP
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
  local binary = gdb()

  if binary == nil then
    return false
  end

  local result = system({
    binary,
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
    and lldb_dap() ~= nil
  then
    return "unreal-lldb"
  end

  if
    state.adapter == "gdb"
    and gdb_supports_dap()
  then
    return "unreal-gdb"
  end

  if lldb_dap() ~= nil then
    state.adapter = "lldb"

    return "unreal-lldb"
  end

  if gdb_supports_dap() then
    state.adapter = "gdb"

    return "unreal-gdb"
  end

  notify(
    "neither lldb-dap nor GDB DAP is available",
    levels.ERROR
  )

  return "unreal-lldb"
end

local function select_adapter()
  local selection = fn.inputlist({
    "Unreal native debugger:",
    "1. LLDB DAP",
    "2. GDB DAP",
  })

  if selection == 1 then
    if lldb_dap() == nil then
      notify(
        "lldb-dap is unavailable",
        levels.ERROR
      )

      return
    end

    state.adapter = "lldb"

    notify(
      "Unreal debugger: LLDB DAP"
    )
  elseif selection == 2 then
    if not gdb_supports_dap() then
      notify(
        "GDB DAP is unavailable",
        levels.ERROR
      )

      return
    end

    state.adapter = "gdb"

    notify(
      "Unreal debugger: GDB DAP"
    )
  end
end

---@return string
local function cwd()
  return project_root()
end

---@return string[]
local function prompt_program_args()
  local input = fn.input(
    "Unreal arguments: "
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

---@return integer
local function prompt_pid()
  local input = fn.input(
    "Unreal process PID: "
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
local function unreal_processes()
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
        lower_command:find(
          "unreal",
          1,
          true
        ) ~= nil
        or lower_arguments:find(
          "unrealeditor",
          1,
          true
        ) ~= nil
        or lower_arguments:find(
          ".uproject",
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
local function choose_unreal_process()
  local processes =
    unreal_processes()

  if #processes == 0 then
    notify(
      "no Unreal Editor/game process found",
      levels.WARN
    )

    return 0
  end

  local choices = {
    "Choose Unreal process:",
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

---@return string
local function prompt_configuration()
  local choices = {
    "Unreal build configuration:",
  }

  for index, name in ipairs(
    BUILD_CONFIGURATIONS
  ) do
    choices[#choices + 1] =
      ("%d. %s"):format(
        index,
        name
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

  return "DebugGame"
end

---@return string
local function prompt_target_kind()
  local choices = {
    "Unreal target:",
  }

  for index, name in ipairs(
    TARGET_KINDS
  ) do
    choices[#choices + 1] =
      ("%d. %s"):format(
        index,
        name
      )
  end

  local selected =
    fn.inputlist(choices)

  if
    selected >= 1
    and selected <= #TARGET_KINDS
  then
    return TARGET_KINDS[selected]
  end

  return "Editor"
end

---@param configuration string
---@param target_kind string
---@return boolean
local function build_project(
  configuration,
  target_kind
)
  local build =
    resolve_build_script()

  local project =
    resolve_uproject()

  if build == nil then
    notify(
      "Unreal Build.sh was not found",
      levels.ERROR
    )

    return false
  end

  if project == nil then
    notify(
      "no .uproject was found",
      levels.ERROR
    )

    return false
  end

  local name =
    project_name()

  if name == "" then
    notify(
      "unable to determine Unreal project name",
      levels.ERROR
    )

    return false
  end

  local target = name

  if target_kind ~= "Game" then
    target = target .. target_kind
  end

  local command = {
    build,
    target,
    "Linux",
    configuration,
    project,
    "-WaitMutex",
  }

  notify(
    (
      "building %s Linux %s"
    ):format(
      target,
      configuration
    )
  )

  local result = system(
    command,
    project_root()
  )

  if result == nil then
    notify(
      "failed to invoke Unreal Build Tool",
      levels.ERROR
    )

    return false
  end

  if result.code ~= 0 then
    local output = vim.trim(
      result.stderr
        or result.stdout
        or "Unreal build failed"
    )

    notify(
      output ~= ""
          and output
        or "Unreal build failed",
      levels.ERROR
    )

    return false
  end

  state.executable = nil

  return true
end

local function build_debug_game_editor()
  build_project(
    "DebugGame",
    "Editor"
  )
end

local function build_debug_editor()
  build_project(
    "Debug",
    "Editor"
  )
end

local function build_interactive()
  build_project(
    prompt_configuration(),
    prompt_target_kind()
  )
end

---@return string
local function editor_program()
  return resolve_editor()
    or ""
end

---@return string[]
local function editor_arguments()
  local project =
    resolve_uproject()

  if project == nil then
    return {}
  end

  return {
    project,
    "-log",
  }
end

---@return string[]
local function editor_debug_arguments()
  local project =
    resolve_uproject()

  if project == nil then
    return {}
  end

  return {
    project,
    "-debug",
    "-log",
  }
end

---@return string[]
local function editor_game_arguments()
  local project =
    resolve_uproject()

  if project == nil then
    return {}
  end

  return {
    project,
    "-game",
    "-log",
  }
end

---@return string[]
local function gameplay_debugger_arguments()
  local project =
    resolve_uproject()

  if project == nil then
    return {}
  end

  return {
    project,
    "-game",
    "-log",
    '-ExecCmds=EnableGDT',
  }
end

---@return string[]
local function gameplay_debugger_camera_arguments()
  local project =
    resolve_uproject()

  if project == nil then
    return {}
  end

  return {
    project,
    "-game",
    "-log",
    '-ExecCmds=EnableGDT,ToggleDebugCamera',
  }
end

---@return string
local function choose_game_binary()
  if
    state.executable ~= nil
    and executable(state.executable)
  then
    return state.executable
  end

  local root =
    project_root()

  local candidates = {
    fs.joinpath(
      root,
      "Binaries",
      "Linux",
      project_name()
    ),

    fs.joinpath(
      root,
      "Binaries",
      "Linux",
      project_name()
        .. "-Linux-DebugGame"
    ),

    fs.joinpath(
      root,
      "Binaries",
      "Linux",
      project_name()
        .. "-Linux-Debug"
    ),
  }

  for _, candidate in ipairs(candidates) do
    if executable(candidate) then
      state.executable =
        fs.normalize(candidate)

      return state.executable
    end
  end

  local selected = fn.input(
    "Unreal game executable: ",
    fs.joinpath(
      root,
      "Binaries",
      "Linux",
      ""
    ),
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
      (
        "not an executable: %s"
      ):format(selected),
      levels.ERROR
    )

    return ""
  end

  state.executable = selected

  return selected
end

local function launch_editor_detached(
  extra_args
)
  local editor =
    resolve_editor()

  local project =
    resolve_uproject()

  if editor == nil then
    notify(
      "UnrealEditor was not found",
      levels.ERROR
    )

    return
  end

  if project == nil then
    notify(
      "no .uproject was found",
      levels.ERROR
    )

    return
  end

  local command = {
    editor,
    project,
  }

  if type(extra_args) == "table" then
    vim.list_extend(
      command,
      extra_args
    )
  end

  local id = fn.jobstart(
    command,
    {
      cwd = project_root(),
      detach = true,
    }
  )

  if id <= 0 then
    notify(
      "failed to launch Unreal Editor",
      levels.ERROR
    )

    return
  end

  notify(
    "Unreal Editor launched"
  )
end

local function launch_editor()
  launch_editor_detached({
    "-log",
  })
end

local function launch_gameplay_debugger()
  launch_editor_detached({
    "-game",
    "-log",
    '-ExecCmds=EnableGDT',
  })
end

local function launch_debug_camera()
  launch_editor_detached({
    "-game",
    "-log",
    '-ExecCmds=EnableGDT,ToggleDebugCamera',
  })
end

local function open_logs()
  local directory = fs.joinpath(
    project_root(),
    "Saved",
    "Logs"
  )

  if not is_directory(directory) then
    notify(
      "Unreal Saved/Logs directory does not exist",
      levels.WARN
    )

    return
  end

  vim.cmd(
    "edit "
      .. fn.fnameescape(directory)
  )
end

local function select_engine_root()
  local selected = fn.input(
    "Unreal Engine root: ",
    resolve_engine_root() or "",
    "dir"
  )

  if selected == "" then
    return
  end

  selected = normalize(
    fn.expand(selected)
  )

  if not valid_engine_root(selected) then
    notify(
      (
        "not a valid Unreal Engine root: %s"
      ):format(selected),
      levels.ERROR
    )

    return
  end

  state.engine_root = selected
  state.editor = nil

  notify(
    ("Unreal Engine root: %s"):format(
      selected
    )
  )
end

local function select_project()
  local selected = fn.input(
    "Unreal .uproject: ",
    resolve_uproject() or "",
    "file"
  )

  if selected == "" then
    return
  end

  selected = normalize(
    fn.expand(selected)
  )

  if
    not is_file(selected)
    or selected:sub(-9) ~= ".uproject"
  then
    notify(
      (
        "not an Unreal .uproject: %s"
      ):format(selected),
      levels.ERROR
    )

    return
  end

  state.uproject = selected
  state.project_root =
    fs.dirname(selected)
  state.executable = nil

  notify(
    ("Unreal project: %s"):format(
      selected
    )
  )
end

local function clear_cache()
  state.editor = nil
  state.engine_root = nil
  state.executable = nil
  state.project_root = nil
  state.uproject = nil

  notify(
    "Unreal debugger discovery cache cleared"
  )
end

local function status()
  local project =
    resolve_uproject()

  local engine =
    resolve_engine_root()

  local editor =
    resolve_editor()

  notify(
    table.concat({
      "project root: "
        .. project_root(),

      ".uproject: "
        .. (project or "not found"),

      "project name: "
        .. (
          project_name() ~= ""
              and project_name()
            or "unknown"
        ),

      "engine root: "
        .. (engine or "not found"),

      "UnrealEditor: "
        .. (editor or "not found"),

      "build script: "
        .. (
          resolve_build_script()
            or "not found"
        ),

      "active debugger: "
        .. state.adapter,

      "lldb-dap: "
        .. (
          lldb_dap()
            or "not found"
        ),

      "GDB DAP: "
        .. (
          gdb_supports_dap()
              and "available"
            or "unavailable"
        ),

      "Gameplay Debugger: runtime overlay",

      "Gameplay Debugger activation: apostrophe / EnableGDT",
    }, "\n")
  )
end

--
-- Unreal's Gameplay Debugger is NOT a DAP implementation.
--
-- Native C++ source debugging is handled here by LLDB DAP or GDB DAP.
--
---@type table<string, table>
M.adapters = {
  ["unreal-lldb"] = {
    name = "unreal-lldb",

    type = "executable",

    command = lldb_dap()
      or "lldb-dap",

    options = {
      source_filetype = "cpp",
    },
  },

  ["unreal-gdb"] = {
    name = "unreal-gdb",

    type = "executable",

    command = gdb()
      or "gdb",

    args = {
      "-q",
      "-i=dap",
    },

    options = {
      source_filetype = "cpp",
    },
  },
}

---@type table[]
local configurations = {
  {
    name = "Unreal: Editor",

    type = active_adapter_type,

    request = "launch",

    program = editor_program,

    cwd = cwd,

    args = editor_arguments,

    env = {},

    stopOnEntry = false,

    runInTerminal = true,
  },

  {
    name = "Unreal: Editor Debug Modules",

    type = active_adapter_type,

    request = "launch",

    program = editor_program,

    cwd = cwd,

    args = editor_debug_arguments,

    env = {},

    stopOnEntry = false,

    runInTerminal = true,
  },

  {
    name = "Unreal: Editor with Arguments",

    type = active_adapter_type,

    request = "launch",

    program = editor_program,

    cwd = cwd,

    args = function()
      local project =
        resolve_uproject()

      local result = {}

      if project ~= nil then
        result[#result + 1] = project
      end

      vim.list_extend(
        result,
        prompt_program_args()
      )

      return result
    end,

    env = prompt_environment,

    stopOnEntry = false,

    runInTerminal = true,
  },

  {
    name = "Unreal: Game through Editor",

    type = active_adapter_type,

    request = "launch",

    program = editor_program,

    cwd = cwd,

    args = editor_game_arguments,

    env = {},

    stopOnEntry = false,

    runInTerminal = true,
  },

  {
    name = "Unreal: Game + Gameplay Debugger",

    type = active_adapter_type,

    request = "launch",

    program = editor_program,

    cwd = cwd,

    args = gameplay_debugger_arguments,

    env = {},

    stopOnEntry = false,

    runInTerminal = true,
  },

  {
    name = "Unreal: Game + Gameplay Debugger + Debug Camera",

    type = active_adapter_type,

    request = "launch",

    program = editor_program,

    cwd = cwd,

    args = gameplay_debugger_camera_arguments,

    env = {},

    stopOnEntry = false,

    runInTerminal = true,
  },

  {
    name = "Unreal: Standalone Game Binary",

    type = active_adapter_type,

    request = "launch",

    program = choose_game_binary,

    cwd = cwd,

    args = prompt_program_args,

    env = prompt_environment,

    stopOnEntry = false,

    runInTerminal = true,
  },

  {
    name = "Unreal: Attach Editor/Game",

    type = active_adapter_type,

    request = "attach",

    pid = choose_unreal_process,
  },

  {
    name = "Unreal: Attach PID",

    type = active_adapter_type,

    request = "attach",

    pid = prompt_pid,
  },
}

---@type table<string, table[]>
M.configurations = {
  c = configurations,

  cpp = configurations,
}

---@type table<string, DebugCommand>
M.commands = {
  UnrealDebugAdapter = {
    callback = function()
      select_adapter()
    end,

    desc = "Select Unreal native debugger",
  },

  UnrealDebugBuild = {
    callback = function()
      build_interactive()
    end,

    desc = "Build Unreal project",
  },

  UnrealDebugBuildDebug = {
    callback = function()
      build_debug_editor()
    end,

    desc = "Build Unreal Editor Debug",
  },

  UnrealDebugBuildGame = {
    callback = function()
      build_debug_game_editor()
    end,

    desc = "Build Unreal Editor DebugGame",
  },

  UnrealDebugClear = {
    callback = function()
      clear_cache()
    end,

    desc = "Clear Unreal DAP discovery cache",
  },

  UnrealDebugEngine = {
    callback = function()
      select_engine_root()
    end,

    desc = "Select Unreal Engine root",
  },

  UnrealDebugGameplay = {
    callback = function()
      launch_gameplay_debugger()
    end,

    desc = "Launch Unreal game with Gameplay Debugger",
  },

  UnrealDebugGameplayCamera = {
    callback = function()
      launch_debug_camera()
    end,

    desc = "Launch Gameplay Debugger and Debug Camera",
  },

  UnrealDebugLaunch = {
    callback = function()
      launch_editor()
    end,

    desc = "Launch Unreal Editor",
  },

  UnrealDebugLogs = {
    callback = function()
      open_logs()
    end,

    desc = "Open Unreal project logs",
  },

  UnrealDebugProject = {
    callback = function()
      select_project()
    end,

    desc = "Select Unreal project",
  },

  UnrealDebugStatus = {
    callback = function()
      status()
    end,

    desc = "Show Unreal debugger status",
  },
}

---@type table<string, DebugMapping>
M.mappings = {
  unreal_debug_adapter = {
    lhs = "<leader>dUa",

    mode = "n",

    rhs = function()
      select_adapter()
    end,

    desc = "Debug Unreal: Select adapter",
  },

  unreal_debug_build = {
    lhs = "<leader>dUb",

    mode = "n",

    rhs = function()
      build_interactive()
    end,

    desc = "Debug Unreal: Build",
  },

  unreal_debug_gameplay = {
    lhs = "<leader>dUg",

    mode = "n",

    rhs = function()
      launch_gameplay_debugger()
    end,

    desc = "Debug Unreal: Gameplay Debugger",
  },

  unreal_debug_launch = {
    lhs = "<leader>dUl",

    mode = "n",

    rhs = function()
      launch_editor()
    end,

    desc = "Debug Unreal: Launch Editor",
  },

  unreal_debug_status = {
    lhs = "<leader>dUs",

    mode = "n",

    rhs = function()
      status()
    end,

    desc = "Debug Unreal: Status",
  },
}

---@param opts? table
function M.setup(opts)
  opts = opts or {}

  state.project_root =
    nonempty_string(opts.root)
        and fs.normalize(opts.root)
      or project_root()

  local lldb =
    lldb_dap()

  if lldb ~= nil then
    M.adapters["unreal-lldb"].command =
      lldb
  end

  local gdb_path =
    gdb()

  if gdb_path ~= nil then
    M.adapters["unreal-gdb"].command =
      gdb_path
  end

  if resolve_uproject() == nil then
    vim.schedule(function()
      notify(
        "current workspace is not an Unreal project",
        levels.DEBUG
      )
    end)

    return
  end

  if resolve_engine_root() == nil then
    vim.schedule(function()
      notify(
        table.concat({
          "Unreal Engine installation was not found.",
          "",
          "Set one of:",
          "  NVIM_UNREAL_ENGINE_ROOT=/path/to/UnrealEngine",
          "  UNREAL_ENGINE_ROOT=/path/to/UnrealEngine",
          "  UE_ENGINE_ROOT=/path/to/UnrealEngine",
        }, "\n"),
        levels.WARN
      )
    end)
  end

  if
    lldb == nil
    and not gdb_supports_dap()
  then
    vim.schedule(function()
      notify(
        "neither lldb-dap nor GDB DAP is available",
        levels.ERROR
      )
    end)
  elseif lldb == nil then
    state.adapter = "gdb"
  end
end

---@return boolean
function M.is_unreal()
  return is_unreal_project()
end

---@return string?
function M.uproject()
  return resolve_uproject()
end

---@return string?
function M.engine_root()
  return resolve_engine_root()
end

---@return string?
function M.editor()
  return resolve_editor()
end

---@return string
function M.root()
  return project_root()
end

---@return "lldb"|"gdb"
function M.active_adapter()
  return state.adapter
end

return M