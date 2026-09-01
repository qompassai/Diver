-- #################################################################
-- ~/.config/nvim/lua/dap/nix.lua
-- Qompass AI Diver Native Nix / Flake Debug Adapter Configuration
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
---@source https://github.com/DieracDelta/DAWN
---@source https://nlnet.nl/project/NixDebugAdaptor/
---@source https://nix.dev/concepts/flakes.html

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local levels = vim.log.levels
local uv = vim.uv

local M = {}

local SOURCE = "nix-dap"

---@type string[]
local ROOT_MARKERS = {
  "flake.nix",
  "flake.lock",
  "default.nix",
  "shell.nix",
  "configuration.nix",
  "home.nix",
  ".envrc",
  ".git",
}

---@type string[]
local ADAPTER_EXECUTABLES = {
  "nix-debug-adapter",
  "dawn",
}

---@class NixDapState
---@field adapter string?
---@field nix string?
---@field root string?
local state = {
  adapter = nil,
  nix = nil,
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
local function resolve_nix()
  if
    state.nix ~= nil
    and executable(state.nix)
  then
    return state.nix
  end

  local configured =
    vim.env.NVIM_NIX_EXECUTABLE

  if nonempty_string(configured) then
    local candidate = normalize(
      fn.expand(configured)
    )

    if executable(candidate) then
      state.nix = candidate

      return candidate
    end

    notify(
      ("NVIM_NIX_EXECUTABLE is not executable: %s"):format(
        candidate
      ),
      levels.WARN
    )
  end

  local candidate =
    executable_path("nix")

  if candidate ~= nil then
    state.nix = candidate

    return candidate
  end

  return nil
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
    vim.env.NVIM_DAWN_EXECUTABLE
      or vim.env.NVIM_NIX_DAP

  if nonempty_string(configured) then
    local candidate = normalize(
      fn.expand(configured)
    )

    if executable(candidate) then
      state.adapter = candidate

      return candidate
    end

    notify(
      ("configured DAWN adapter is not executable: %s"):format(
        candidate
      ),
      levels.WARN
    )
  end

  for _, name in ipairs(
    ADAPTER_EXECUTABLES
  ) do
    local candidate =
      executable_path(name)

    if candidate ~= nil then
      state.adapter = candidate

      return candidate
    end
  end

  return nil
end

---@return string?
local function nix_version()
  local nix = resolve_nix()

  if nix == nil then
    return nil
  end

  local result = system({
    nix,
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

  return value
end

---@return boolean
local function is_flake()
  return is_file(
    fs.joinpath(
      project_root(),
      "flake.nix"
    )
  )
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
local function flake_file()
  local candidate = fs.joinpath(
    project_root(),
    "flake.nix"
  )

  if is_file(candidate) then
    return fs.normalize(candidate)
  end

  notify(
    "flake.nix was not found in the current project",
    levels.ERROR
  )

  return current_file()
end

---@return string
local function default_nix_file()
  local candidate = fs.joinpath(
    project_root(),
    "default.nix"
  )

  if is_file(candidate) then
    return fs.normalize(candidate)
  end

  return current_file()
end

---@return string
local function shell_nix_file()
  local candidate = fs.joinpath(
    project_root(),
    "shell.nix"
  )

  if is_file(candidate) then
    return fs.normalize(candidate)
  end

  return current_file()
end

---@return string
local function configuration_nix_file()
  local candidate = fs.joinpath(
    project_root(),
    "configuration.nix"
  )

  if is_file(candidate) then
    return fs.normalize(candidate)
  end

  return current_file()
end

---@return string
local function home_nix_file()
  local candidate = fs.joinpath(
    project_root(),
    "home.nix"
  )

  if is_file(candidate) then
    return fs.normalize(candidate)
  end

  return current_file()
end

local function select_adapter()
  local selected = fn.input(
    "DAWN executable: ",
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
    ("DAWN adapter: %s"):format(
      selected
    )
  )
end

local function select_nix()
  local selected = fn.input(
    "Nix executable: ",
    resolve_nix() or "",
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

  state.nix = selected

  notify(
    ("Nix executable: %s"):format(
      selected
    )
  )
end

---@param arguments string[]
---@param title string
local function run_nix(
  arguments,
  title
)
  local nix = resolve_nix()

  if nix == nil then
    notify(
      "nix executable was not found",
      levels.ERROR
    )

    return
  end

  local command = {
    nix,
  }

  vim.list_extend(
    command,
    arguments
  )

  vim.cmd(
    "botright new"
  )

  local bufnr =
    api.nvim_get_current_buf()

  vim.bo[bufnr].bufhidden =
    "wipe"

  vim.bo[bufnr].filetype =
    "nixdebug"

  local job = fn.termopen(
    command,
    {
      cwd = project_root(),

      on_exit = function(_, code)
        vim.schedule(function()
          notify(
            ("%s exited with status %d"):format(
              title,
              code
            ),
            code == 0
                and levels.INFO
              or levels.WARN
          )
        end)
      end,
    }
  )

  if job <= 0 then
    notify(
      ("failed to start %s"):format(
        title
      ),
      levels.ERROR
    )

    return
  end

  vim.cmd(
    "startinsert"
  )
end

local function flake_check()
  if not is_flake() then
    notify(
      "current project has no flake.nix",
      levels.ERROR
    )

    return
  end

  run_nix(
    {
      "flake",
      "check",
      "--show-trace",
    },
    "nix flake check"
  )
end

local function flake_show()
  if not is_flake() then
    notify(
      "current project has no flake.nix",
      levels.ERROR
    )

    return
  end

  run_nix(
    {
      "flake",
      "show",
      "--show-trace",
    },
    "nix flake show"
  )
end

local function flake_metadata()
  if not is_flake() then
    notify(
      "current project has no flake.nix",
      levels.ERROR
    )

    return
  end

  run_nix(
    {
      "flake",
      "metadata",
      "--json",
    },
    "nix flake metadata"
  )
end

local function flake_build()
  if not is_flake() then
    notify(
      "current project has no flake.nix",
      levels.ERROR
    )

    return
  end

  local attribute = fn.input(
    "Flake output: ",
    ".#"
  )

  if attribute == "" then
    return
  end

  run_nix(
    {
      "build",
      attribute,
      "--show-trace",
      "--print-build-logs",
    },
    "nix build"
  )
end

local function flake_eval()
  if not is_flake() then
    notify(
      "current project has no flake.nix",
      levels.ERROR
    )

    return
  end

  local attribute = fn.input(
    "Flake attribute: ",
    ".#"
  )

  if attribute == "" then
    return
  end

  run_nix(
    {
      "eval",
      attribute,
      "--show-trace",
    },
    "nix eval"
  )
end

local function flake_repl()
  if not is_flake() then
    notify(
      "current project has no flake.nix",
      levels.ERROR
    )

    return
  end

  run_nix(
    {
      "repl",
      ".",
    },
    "nix repl"
  )
end

local function eval_current_file()
  local current = filename()

  if current == "" then
    notify(
      "current buffer has no filename",
      levels.ERROR
    )

    return
  end

  run_nix(
    {
      "eval",
      "--file",
      current,
      "--show-trace",
    },
    "nix eval"
  )
end

local function instantiate_current_file()
  local current = filename()

  if current == "" then
    notify(
      "current buffer has no filename",
      levels.ERROR
    )

    return
  end

  run_nix(
    {
      "eval",
      "--file",
      current,
      "--show-trace",
      "--raw",
    },
    "nix eval"
  )
end

local function clear_cache()
  state.adapter = nil
  state.nix = nil
  state.root = nil

  notify(
    "Nix DAP discovery cache cleared"
  )
end

local function status()
  local adapter = resolve_adapter()
  local nix = resolve_nix()

  notify(
    table.concat({
      "root: "
        .. project_root(),

      "Nix: "
        .. (nix or "not found"),

      "Nix version: "
        .. (
          nix_version()
            or "unknown"
        ),

      "flake: "
        .. (
          is_flake()
              and "yes"
            or "no"
        ),

      "flake.nix: "
        .. fs.joinpath(
          project_root(),
          "flake.nix"
        ),

      "DAWN: "
        .. (
          adapter
            or "not found"
        ),

      "DAWN maturity: WIP",

      "DAP type: nix",

      "DAP request: launch",
    }, "\n"),
    adapter ~= nil
        and levels.INFO
      or levels.WARN
  )
end

--
-- DAWN's currently documented editor contract is intentionally minimal:
--
--   adapter type: executable
--   DAP type:     nix
--   request:      launch
--   program:      Nix source file
--
-- Do not invent unsupported DAWN-specific configuration fields until the
-- adapter documents them.
--
---@type table
M.adapter = {
  name = "nix",

  type = "executable",

  command =
    resolve_adapter()
      or "nix-debug-adapter",

  args = {},

  options = {
    source_filetype = "nix",
  },
}

---@type table[]
local configurations = {
  {
    name = "Nix: Debug Current File",

    type = "nix",

    request = "launch",

    program =
      current_file,
  },

  {
    name = "Nix: Debug flake.nix",

    type = "nix",

    request = "launch",

    program =
      flake_file,
  },

  {
    name = "Nix: Debug default.nix",

    type = "nix",

    request = "launch",

    program =
      default_nix_file,
  },

  {
    name = "Nix: Debug shell.nix",

    type = "nix",

    request = "launch",

    program =
      shell_nix_file,
  },

  {
    name = "Nix: Debug configuration.nix",

    type = "nix",

    request = "launch",

    program =
      configuration_nix_file,
  },

  {
    name = "Nix: Debug home.nix",

    type = "nix",

    request = "launch",

    program =
      home_nix_file,
  },
}

---@type table<string, table[]>
M.configurations = {
  nix = configurations,
}

---@type table<string, DebugCommand>
M.commands = {
  NixDebugAdapter = {
    callback = function()
      select_adapter()
    end,

    desc =
      "Select DAWN Nix debug adapter",
  },

  NixDebugClear = {
    callback = function()
      clear_cache()
    end,

    desc =
      "Clear Nix DAP discovery cache",
  },

  NixDebugEval = {
    callback = function()
      eval_current_file()
    end,

    desc =
      "Evaluate current Nix file",
  },

  NixDebugFlakeBuild = {
    callback = function()
      flake_build()
    end,

    desc =
      "Build Nix flake output",
  },

  NixDebugFlakeCheck = {
    callback = function()
      flake_check()
    end,

    desc =
      "Check current Nix flake",
  },

  NixDebugFlakeEval = {
    callback = function()
      flake_eval()
    end,

    desc =
      "Evaluate Nix flake output",
  },

  NixDebugFlakeMetadata = {
    callback = function()
      flake_metadata()
    end,

    desc =
      "Show Nix flake metadata",
  },

  NixDebugFlakeRepl = {
    callback = function()
      flake_repl()
    end,

    desc =
      "Open Nix REPL for current flake",
  },

  NixDebugFlakeShow = {
    callback = function()
      flake_show()
    end,

    desc =
      "Show Nix flake outputs",
  },

  NixDebugNix = {
    callback = function()
      select_nix()
    end,

    desc =
      "Select Nix executable",
  },

  NixDebugStatus = {
    callback = function()
      status()
    end,

    desc =
      "Show Nix debugger status",
  },
}

---@type table<string, DebugMapping>
M.mappings = {
  nix_debug_adapter = {
    lhs = "<leader>dNa",

    mode = "n",

    rhs = function()
      select_adapter()
    end,

    desc =
      "Debug Nix: Select DAWN",
  },

  nix_debug_eval = {
    lhs = "<leader>dNe",

    mode = "n",

    rhs = function()
      eval_current_file()
    end,

    desc =
      "Debug Nix: Evaluate file",
  },

  nix_debug_flake_check = {
    lhs = "<leader>dNc",

    mode = "n",

    rhs = function()
      flake_check()
    end,

    desc =
      "Debug Nix: Flake check",
  },

  nix_debug_flake_repl = {
    lhs = "<leader>dNr",

    mode = "n",

    rhs = function()
      flake_repl()
    end,

    desc =
      "Debug Nix: Flake REPL",
  },

  nix_debug_flake_show = {
    lhs = "<leader>dNf",

    mode = "n",

    rhs = function()
      flake_show()
    end,

    desc =
      "Debug Nix: Flake outputs",
  },

  nix_debug_status = {
    lhs = "<leader>dNs",

    mode = "n",

    rhs = function()
      status()
    end,

    desc =
      "Debug Nix: Status",
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
    M.adapter.command =
      adapter
  end

  if resolve_nix() == nil then
    vim.schedule(function()
      notify(
        table.concat({
          "Nix was not found.",

          "",

          "Install `nix` or set:",

          "  NVIM_NIX_EXECUTABLE=/path/to/nix",
        }, "\n"),
        levels.WARN
      )
    end)
  end

  if adapter == nil then
    vim.schedule(function()
      notify(
        table.concat({
          "DAWN / nix-debug-adapter was not found.",

          "",

          "Set one of:",

          "  NVIM_DAWN_EXECUTABLE=/path/to/nix-debug-adapter",

          "  NVIM_NIX_DAP=/path/to/nix-debug-adapter",

          "",

          "DAWN is currently WIP, so Nix inspection commands",
          "remain available even if the DAP adapter is absent.",
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
function M.nix()
  return resolve_nix()
end

---@return string
function M.root()
  return project_root()
end

---@return boolean
function M.is_flake()
  return is_flake()
end

---@return boolean
function M.available()
  return resolve_adapter() ~= nil
end

return M