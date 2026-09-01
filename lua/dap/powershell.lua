-- #################################################################
-- ~/.config/nvim/lua/dap/powershell.lua
-- Qompass AI Diver Native PowerShell Debug Adapter Configuration
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
---@source https://github.com/PowerShell/PowerShellEditorServices
---@source https://github.com/PowerShell/vscode-powershell

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local levels = vim.log.levels
local uv = vim.uv

local M = {}

local SOURCE = "powershell-dap"

---@type string[]
local ROOT_MARKERS = {
  ".psd1",
  ".psm1",
  "PSScriptAnalyzerSettings.psd1",
  "psakefile.ps1",
  "build.ps1",
  "build.psd1",
  "module.psd1",
  ".git",
}

---@type string[]
local PSES_ROOTS = {
  fs.joinpath(
    fn.expand("~"),
    ".local",
    "share",
    "powershell-editor-services"
  ),

  fs.joinpath(
    fn.expand("~"),
    ".local",
    "share",
    "PowerShellEditorServices"
  ),

  "/usr/lib/powershell-editor-services",

  "/usr/lib/PowerShellEditorServices",

  "/usr/share/powershell-editor-services",

  "/usr/share/PowerShellEditorServices",

  "/opt/powershell-editor-services",

  "/opt/PowerShellEditorServices",
}

---@type string[]
local VSCODE_EXTENSION_ROOTS = {
  fs.joinpath(
    fn.expand("~"),
    ".vscode",
    "extensions"
  ),

  fs.joinpath(
    fn.expand("~"),
    ".vscode-oss",
    "extensions"
  ),
}

---@class PowerShellDapState
---@field bundle string?
---@field pwsh string?
---@field root string?
---@field session_dir string?
local state = {
  bundle = nil,
  pwsh = nil,
  root = nil,
  session_dir = nil,
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
    local root = fs.root(
      current,
      ROOT_MARKERS
    )

    if
      type(root) == "string"
      and root ~= ""
    then
      return fs.normalize(root)
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

---@return string?
local function resolve_pwsh()
  if
    state.pwsh ~= nil
    and fn.executable(state.pwsh) == 1
  then
    return state.pwsh
  end

  local configured =
    vim.env.NVIM_PWSH_EXECUTABLE

  if nonempty_string(configured) then
    local path = normalize(
      fn.expand(configured)
    )

    if fn.executable(path) == 1 then
      state.pwsh = path

      return path
    end

    notify(
      ("NVIM_PWSH_EXECUTABLE is not executable: %s"):format(
        path
      ),
      levels.WARN
    )
  end

  local path = executable_path("pwsh")

  if path ~= nil then
    state.pwsh = path

    return path
  end

  return nil
end

---@param root string
---@return string?
local function start_script_from_root(root)
  local candidates = {
    fs.joinpath(
      root,
      "PowerShellEditorServices",
      "Start-EditorServices.ps1"
    ),

    fs.joinpath(
      root,
      "Start-EditorServices.ps1"
    ),

    fs.joinpath(
      root,
      "modules",
      "PowerShellEditorServices",
      "Start-EditorServices.ps1"
    ),
  }

  for _, candidate in ipairs(candidates) do
    if is_file(candidate) then
      return fs.normalize(candidate)
    end
  end

  return nil
end

---@param extension_root string
---@return string?
local function bundle_from_vscode_root(
  extension_root
)
  if not is_directory(extension_root) then
    return nil
  end

  local handle = uv.fs_scandir(
    extension_root
  )

  if handle == nil then
    return nil
  end

  ---@type string[]
  local candidates = {}

  while true do
    local name, kind =
      uv.fs_scandir_next(handle)

    if name == nil then
      break
    end

    if
      kind == "directory"
      and name:match(
        "^ms%-vscode%.powershell%-"
      )
    then
      candidates[#candidates + 1] =
        fs.joinpath(
          extension_root,
          name,
          "modules"
        )
    end
  end

  table.sort(
    candidates,
    function(left, right)
      return left > right
    end
  )

  for _, candidate in ipairs(candidates) do
    if
      start_script_from_root(candidate)
      ~= nil
    then
      return fs.normalize(candidate)
    end
  end

  return nil
end

---@return string?
local function resolve_bundle()
  if
    state.bundle ~= nil
    and start_script_from_root(
      state.bundle
    ) ~= nil
  then
    return state.bundle
  end

  local configured =
    vim.env.NVIM_PSES_BUNDLE
      or vim.env.POWERSHELL_EDITOR_SERVICES_PATH

  if nonempty_string(configured) then
    local root = normalize(
      fn.expand(configured)
    )

    if
      start_script_from_root(root)
      ~= nil
    then
      state.bundle = root

      return root
    end

    notify(
      ("configured PSES bundle is invalid: %s"):format(
        root
      ),
      levels.WARN
    )
  end

  for _, root in ipairs(PSES_ROOTS) do
    if
      start_script_from_root(root)
      ~= nil
    then
      state.bundle = fs.normalize(root)

      return state.bundle
    end
  end

  for _, root in ipairs(
    VSCODE_EXTENSION_ROOTS
  ) do
    local bundle =
      bundle_from_vscode_root(root)

    if bundle ~= nil then
      state.bundle = bundle

      return bundle
    end
  end

  return nil
end

---@return string
local function session_directory()
  if
    state.session_dir ~= nil
    and is_directory(state.session_dir)
  then
    return state.session_dir
  end

  local base = fs.joinpath(
    fn.stdpath("cache"),
    "dap",
    "powershell"
  )

  fn.mkdir(
    base,
    "p",
    "0700"
  )

  local directory = fs.joinpath(
    base,
    (
      "%d-%d"
    ):format(
      uv.os_getpid(),
      math.floor(
        uv.hrtime() / 1000000
      )
    )
  )

  fn.mkdir(
    directory,
    "p",
    "0700"
  )

  state.session_dir =
    fs.normalize(directory)

  return state.session_dir
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

---@return string[]
local function prompt_script_args()
  local input = fn.input(
    "PowerShell script arguments: "
  )

  if input == "" then
    return {}
  end

  return fn.shellsplit(input)
end

---@return integer
local function prompt_runspace_id()
  local value = fn.input(
    "PowerShell runspace ID: ",
    "1"
  )

  local id = tonumber(value)

  if
    id == nil
    or id < 1
  then
    notify(
      ("invalid runspace ID: %s"):format(
        value
      ),
      levels.ERROR
    )

    return 1
  end

  return math.floor(id)
end

---@return table[]
local function powershell_processes()
  local result = vim.system(
    {
      "ps",
      "-eo",
      "pid=,comm=,args=",
    },
    {
      text = true,
    }
  ):wait()

  if result.code ~= 0 then
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
        lower_command == "pwsh"
        or lower_command == "powershell"
        or lower_command == "powershell.exe"
        or lower_arguments:find(
          "pwsh",
          1,
          true
        ) ~= nil
      then
        processes[#processes + 1] = {
          pid = tonumber(pid),

          command = command,

          arguments = arguments or "",
        }
      end
    end
  end

  return processes
end

---@return integer
local function select_process()
  local processes =
    powershell_processes()

  if #processes == 0 then
    notify(
      "no PowerShell host processes found",
      levels.WARN
    )

    return 0
  end

  local choices = {
    "Select PowerShell host:",
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

---@return integer
local function prompt_process_id()
  local value = fn.input(
    "PowerShell process ID: "
  )

  local pid = tonumber(value)

  if
    pid == nil
    or pid < 1
  then
    notify(
      ("invalid PID: %s"):format(
        value
      ),
      levels.ERROR
    )

    return 0
  end

  return math.floor(pid)
end

---@return string[]
local function adapter_args()
  local bundle = resolve_bundle()

  if bundle == nil then
    return {}
  end

  local start_script =
    start_script_from_root(bundle)

  if start_script == nil then
    return {}
  end

  local temporary =
    session_directory()

  return {
    "-NoLogo",

    "-NoProfile",

    "-NonInteractive",

    "-OutputFormat",
    "Text",

    "-File",
    start_script,

    "-BundledModulesPath",
    bundle,

    "-LogPath",
    fs.joinpath(
      temporary,
      "powershell-dap.log"
    ),

    "-SessionDetailsPath",
    fs.joinpath(
      temporary,
      "session.json"
    ),

    "-HostName",
    "Neovim",

    "-HostProfileId",
    "Neovim.DAP",

    "-HostVersion",
    "0.13.0",

    "-LogLevel",
    "Warning",

    --
    -- PSES supports DAP directly over stdio when these two switches are
    -- combined. No named-pipe broker or VS Code extension host is needed.
    --
    "-DebugServiceOnly",

    "-Stdio",
  }
end

---@return boolean
local function health()
  local pwsh = resolve_pwsh()
  local bundle = resolve_bundle()

  local start_script

  if bundle ~= nil then
    start_script =
      start_script_from_root(bundle)
  end

  notify(
    table.concat({
      "root: "
        .. project_root(),

      "pwsh: "
        .. (pwsh or "not found"),

      "PSES bundle: "
        .. (bundle or "not found"),

      "Start-EditorServices.ps1: "
        .. (
          start_script
            or "not found"
        ),

      "transport: stdio",

      "mode: DebugServiceOnly",

      "session directory: "
        .. session_directory(),
    }, "\n"),
    (
      pwsh ~= nil
      and start_script ~= nil
    )
        and levels.INFO
      or levels.WARN
  )

  return pwsh ~= nil
    and start_script ~= nil
end

local function select_pwsh()
  local selected = fn.input(
    "PowerShell executable: ",
    resolve_pwsh() or "",
    "file"
  )

  if selected == "" then
    return
  end

  selected = normalize(
    fn.expand(selected)
  )

  if fn.executable(selected) ~= 1 then
    notify(
      ("not executable: %s"):format(
        selected
      ),
      levels.ERROR
    )

    return
  end

  state.pwsh = selected

  if
    type(M.adapter) == "table"
  then
    M.adapter.command = selected
  end

  notify(
    ("PowerShell executable: %s"):format(
      selected
    )
  )
end

local function select_bundle()
  local selected = fn.input(
    "PowerShell Editor Services bundle: ",
    resolve_bundle() or "",
    "dir"
  )

  if selected == "" then
    return
  end

  selected = normalize(
    fn.expand(selected)
  )

  if
    start_script_from_root(selected)
    == nil
  then
    notify(
      (
        "Start-EditorServices.ps1 was not found under: %s"
      ):format(selected),
      levels.ERROR
    )

    return
  end

  state.bundle = selected

  if
    type(M.adapter) == "table"
  then
    M.adapter.args =
      adapter_args()
  end

  notify(
    ("PSES bundle: %s"):format(
      selected
    )
  )
end

local function clear_cache()
  state.bundle = nil
  state.pwsh = nil
  state.root = nil
  state.session_dir = nil

  notify(
    "PowerShell DAP discovery cache cleared"
  )
end

--
-- PowerShell Editor Services provides an editor-independent DAP debugging
-- service. Modern PSES can expose only that service directly over stdio.
--
---@type table
M.adapter = {
  name = "PowerShell",

  type = "executable",

  command = resolve_pwsh()
    or "pwsh",

  args = adapter_args(),

  options = {
    source_filetype = "ps1",
  },
}

---@type table[]
local configurations = {
  {
    name = "PowerShell: Current File",

    type = "PowerShell",

    request = "launch",

    script = current_file,

    args = {},

    cwd = cwd,

    createTemporaryIntegratedConsole =
      false,
  },

  {
    name = "PowerShell: Current File with Arguments",

    type = "PowerShell",

    request = "launch",

    script = current_file,

    args = prompt_script_args,

    cwd = cwd,

    createTemporaryIntegratedConsole =
      false,
  },

  {
    name = "PowerShell: Current File (Temporary Console)",

    type = "PowerShell",

    request = "launch",

    script = current_file,

    args = {},

    cwd = cwd,

    createTemporaryIntegratedConsole =
      true,
  },

  {
    name = "PowerShell: Interactive Session",

    type = "PowerShell",

    request = "launch",

    cwd = cwd,
  },

  {
    name = "PowerShell: Attach to Chosen Host Process",

    type = "PowerShell",

    request = "attach",

    processId = select_process,

    runspaceId = 1,
  },

  {
    name = "PowerShell: Attach PID",

    type = "PowerShell",

    request = "attach",

    processId = prompt_process_id,

    runspaceId = 1,
  },

  {
    name = "PowerShell: Attach PID and Runspace",

    type = "PowerShell",

    request = "attach",

    processId = prompt_process_id,

    runspaceId = prompt_runspace_id,
  },
}

---@type table<string, table[]>
M.configurations = {
  ps1 = configurations,

  powershell = configurations,
}

---@type table<string, DebugCommand>
M.commands = {
  PowerShellDebugBundle = {
    callback = function()
      select_bundle()
    end,

    desc = "Select PowerShell Editor Services bundle",
  },

  PowerShellDebugClear = {
    callback = function()
      clear_cache()
    end,

    desc = "Clear PowerShell DAP discovery cache",
  },

  PowerShellDebugHealth = {
    callback = function()
      health()
    end,

    desc = "Check PowerShell DAP configuration",
  },

  PowerShellDebugHost = {
    callback = function()
      local pid = select_process()

      if pid > 0 then
        notify(
          ("selected PowerShell PID: %d"):format(
            pid
          )
        )
      end
    end,

    desc = "Choose PowerShell host process",
  },

  PowerShellDebugPwsh = {
    callback = function()
      select_pwsh()
    end,

    desc = "Select PowerShell executable",
  },
}

---@type table<string, DebugMapping>
M.mappings = {
  powershell_debug_bundle = {
    lhs = "<leader>dPb",

    mode = "n",

    rhs = function()
      select_bundle()
    end,

    desc = "Debug PowerShell: PSES bundle",
  },

  powershell_debug_health = {
    lhs = "<leader>dPh",

    mode = "n",

    rhs = function()
      health()
    end,

    desc = "Debug PowerShell: Health",
  },

  powershell_debug_process = {
    lhs = "<leader>dPp",

    mode = "n",

    rhs = function()
      local pid = select_process()

      if pid > 0 then
        notify(
          ("PowerShell host PID: %d"):format(
            pid
          )
        )
      end
    end,

    desc = "Debug PowerShell: Choose process",
  },

  powershell_debug_pwsh = {
    lhs = "<leader>dPs",

    mode = "n",

    rhs = function()
      select_pwsh()
    end,

    desc = "Debug PowerShell: Select pwsh",
  },
}

---@param opts? table
function M.setup(opts)
  opts = opts or {}

  state.root =
    nonempty_string(opts.root)
        and fs.normalize(opts.root)
      or project_root()

  local pwsh = resolve_pwsh()
  local bundle = resolve_bundle()

  if pwsh ~= nil then
    M.adapter.command = pwsh
  end

  if bundle ~= nil then
    M.adapter.args =
      adapter_args()
  end

  if pwsh == nil then
    vim.schedule(function()
      notify(
        table.concat({
          "PowerShell 7+ was not found.",
          "",
          "Install `pwsh` or set:",
          "  NVIM_PWSH_EXECUTABLE=/path/to/pwsh",
        }, "\n"),
        levels.ERROR
      )
    end)
  end

  if bundle == nil then
    vim.schedule(function()
      notify(
        table.concat({
          "PowerShell Editor Services was not found.",
          "",
          "Set either:",
          "  NVIM_PSES_BUNDLE=/path/to/PSES",
          "  POWERSHELL_EDITOR_SERVICES_PATH=/path/to/PSES",
          "",
          "The directory must contain:",
          "  PowerShellEditorServices/Start-EditorServices.ps1",
        }, "\n"),
        levels.WARN
      )
    end)
  end
end

---@return string?
function M.pwsh()
  return resolve_pwsh()
end

---@return string?
function M.bundle()
  return resolve_bundle()
end

---@return string
function M.root()
  return project_root()
end

---@return boolean
function M.available()
  return resolve_pwsh() ~= nil
    and resolve_bundle() ~= nil
end

return M