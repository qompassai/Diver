-- #################################################################
-- ~/.config/nvim/lua/dap/lua.lua
-- Native Lua Debug Adapter Configuration
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################

local api = vim.api
local env = vim.env
local fn = vim.fn
local fs = vim.fs
local levels = vim.log.levels
local uv = vim.uv

local M = {}

local ADAPTER_NAME = "lua-debug"
local NOTIFY_PREFIX = "[lua-debug] "

---@type string[]
local ROOT_MARKERS = {
  ".git",
  ".luacheckrc",
  ".luarc.json",
  ".luarc.jsonc",
  ".stylua.toml",
  "selene.toml",
  "stylua.toml",
}

---@param message string
---@param level? integer
local function notify(message, level)
  vim.notify(NOTIFY_PREFIX .. message, level or levels.INFO)
end

---@param path string
---@return boolean
local function exists(path)
  return uv.fs_stat(path) ~= nil
end

---@param command string
---@return boolean
local function executable(command)
  return fn.executable(command) == 1
end

---@param path string
---@return string
local function normalize(path)
  if path == "" then
    return ""
  end

  return fs.normalize(fn.fnamemodify(path, ":p"))
end

---@param bufnr? integer
---@return string
local function filename(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()

  return normalize(api.nvim_buf_get_name(bufnr))
end

---@param bufnr? integer
---@return string
local function root(bufnr)
  local current_filename = filename(bufnr)

  if current_filename == "" then
    return fn.getcwd()
  end

  local detected_root = fs.root(current_filename, ROOT_MARKERS)

  if type(detected_root) == "string" and detected_root ~= "" then
    return normalize(detected_root)
  end

  return normalize(fs.dirname(current_filename) or fn.getcwd())
end

---@return string?
local function lua_executable()
  local configured = env.LUA

  if type(configured) == "string" and configured ~= "" and executable(configured) then
    return configured
  end

  local candidates = {
    "lua5.4",
    "lua5.3",
    "lua5.2",
    "lua5.1",
    "lua",
    "luajit",
  }

  for index = 1, #candidates do
    local candidate = candidates[index]

    if executable(candidate) then
      return candidate
    end
  end

  return nil
end

---@return string?
local function lua_debug_adapter()
  local configured = env.LUA_DEBUG_ADAPTER

  if type(configured) == "string" and configured ~= "" and executable(configured) then
    return configured
  end

  local candidates = {
    "lua-debug",
    "lua-debug-adapter",
  }

  for index = 1, #candidates do
    local candidate = candidates[index]

    if executable(candidate) then
      return candidate
    end
  end

  return nil
end

---@return string?
local function current_program()
  local current_file = filename()

  if current_file ~= "" and exists(current_file) then
    return current_file
  end

  local selected_path = fn.input("Lua program: ", root() .. "/", "file")

  if selected_path == "" then
    return nil
  end

  selected_path = normalize(selected_path)

  if not exists(selected_path) then
    notify("Lua program does not exist: " .. selected_path, levels.ERROR)

    return nil
  end

  return selected_path
end

---@return string?
local function pick_program()
  local selected_path = fn.input("Lua program: ", root() .. "/", "file")

  if selected_path == "" then
    return nil
  end

  selected_path = normalize(selected_path)

  if not exists(selected_path) then
    notify("Lua program does not exist: " .. selected_path, levels.ERROR)

    return nil
  end

  return selected_path
end

---@return string[]
local function program_arguments()
  local input = fn.input("Arguments: ")

  if input == "" then
    return {}
  end

  ---@type string[]
  local arguments = {}

  --
  -- Deliberately avoid invoking a shell.
  --
  -- This handles straightforward whitespace-delimited arguments. Arguments
  -- containing spaces should be specified directly in a project-specific
  -- configuration rather than shell-quoted here.
  --
  for argument in input:gmatch("%S+") do
    arguments[#arguments + 1] = argument
  end

  return arguments
end

---@return table<string, string>
local function environment()
  ---@type table<string, string>
  local variables = {}

  local lua_path = env.LUA_PATH

  if type(lua_path) == "string" and lua_path ~= "" then
    variables.LUA_PATH = lua_path
  end

  local lua_cpath = env.LUA_CPATH

  if type(lua_cpath) == "string" and lua_cpath ~= "" then
    variables.LUA_CPATH = lua_cpath
  end

  return variables
end

---@return integer?
local function process_id()
  local input = fn.input("Lua process PID: ")

  if input == "" then
    return nil
  end

  local pid = tonumber(input)

  if pid == nil then
    notify("Invalid process ID", levels.WARN)

    return nil
  end

  pid = math.floor(pid)

  if pid <= 0 then
    notify("Process ID must be greater than zero", levels.WARN)

    return nil
  end

  return pid
end

---@return string
local function workspace()
  return root()
end

---@return string?
local function runtime()
  local runtime_executable = lua_executable()

  if runtime_executable == nil then
    notify("Lua interpreter not found", levels.ERROR)

    return nil
  end

  return runtime_executable
end

---@return string?
local function neovim_runtime()
  local nvim_path = fn.exepath("nvim")

  if nvim_path == "" then
    notify("Neovim executable not found", levels.ERROR)

    return nil
  end

  return normalize(nvim_path)
end

---@return string?
local function neovim_config()
  local config_path = fn.stdpath("config")

  if type(config_path) ~= "string" or config_path == "" then
    return nil
  end

  return normalize(config_path)
end

---@return string[]
local function neovim_config_arguments()
  local config_path = neovim_config()

  if config_path == nil then
    return {
      "--headless",
    }
  end

  local init_path = fs.joinpath(config_path, "init.lua")

  if not exists(init_path) then
    return {
      "--headless",
    }
  end

  return {
    "--headless",
    "-u",
    init_path,
  }
end

M.adapter = {
  command = lua_debug_adapter() or "lua-debug",

  name = ADAPTER_NAME,

  type = "executable",
}

M.configurations = {
  lua = {
    {
      args = program_arguments,

      cwd = workspace,

      env = environment,

      lua = runtime,

      name = "Lua: Launch current file",

      program = current_program,

      request = "launch",

      stopOnEntry = false,

      type = ADAPTER_NAME,
    },

    {
      args = program_arguments,

      cwd = workspace,

      env = environment,

      lua = runtime,

      name = "Lua: Launch selected file",

      program = pick_program,

      request = "launch",

      stopOnEntry = false,

      type = ADAPTER_NAME,
    },

    {
      cwd = workspace,

      env = environment,

      name = "Lua: Attach to process",

      processId = process_id,

      request = "attach",

      type = ADAPTER_NAME,
    },

    {
      args = {
        "--clean",
        "--headless",
        "-u",
        "NONE",
      },

      cwd = workspace,

      env = environment,

      lua = neovim_runtime,

      name = "Lua: Launch clean Neovim",

      program = current_program,

      request = "launch",

      stopOnEntry = false,

      type = ADAPTER_NAME,
    },

    {
      args = neovim_config_arguments,

      cwd = workspace,

      env = environment,

      lua = neovim_runtime,

      name = "Lua: Launch Neovim config",

      program = current_program,

      request = "launch",

      stopOnEntry = false,

      type = ADAPTER_NAME,
    },
  },
}

M.filetypes = {
  "lua",
}

M.commands = {
  LuaDebugAdapter = {
    callback = function()
      local adapter = lua_debug_adapter()

      if adapter == nil then
        notify("Lua debug adapter not found", levels.WARN)

        return
      end

      local adapter_path = fn.exepath(adapter)

      notify(adapter_path ~= "" and adapter_path or adapter)
    end,

    desc = "Show Lua debug adapter",
  },

  LuaDebugProgram = {
    callback = function()
      local program = pick_program()

      if program ~= nil then
        notify(program)
      end
    end,

    desc = "Select Lua debug program",
  },

  LuaDebugRoot = {
    callback = function()
      notify(root())
    end,

    desc = "Show Lua debug root",
  },

  LuaDebugRuntime = {
    callback = function()
      local runtime_executable = lua_executable()

      if runtime_executable == nil then
        notify("Lua interpreter not found", levels.WARN)

        return
      end

      local runtime_path = fn.exepath(runtime_executable)

      notify(runtime_path ~= "" and runtime_path or runtime_executable)
    end,

    desc = "Show Lua runtime",
  },
}

---@param _opts? table
function M.setup(_opts)
  local adapter = lua_debug_adapter()

  if adapter == nil then
    notify("lua-debug is not available", levels.WARN)
  else
    M.adapter.command = adapter
  end

  if lua_executable() == nil then
    notify("Lua interpreter is not available", levels.WARN)
  end
end

return M
