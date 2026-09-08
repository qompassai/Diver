-- #################################################################
-- /qompassai/Diver/lua/dap/lua.lua
-- Qompass AI Diver Native Lua Debug Adapter Configuration
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI, All rights reserved
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

local api = vim.api
local env = vim.env
local fn = vim.fn
local fs = vim.fs
local levels = vim.log.levels
local uv = vim.uv

local M = {}

local ADAPTER_NAME = 'lua-debug'
local NOTIFY_PREFIX = '[lua-debug] '
local PROCESS_TIMEOUT = 5000
local VALIDATION_TIMEOUT = 5000

---@type string[]
local ROOT_MARKERS = {
  '.git',
  '.luacheckrc',
  '.luarc.json',
  '.luarc.jsonc',
  '.stylua.toml',
  'selene.toml',
  'stylua.toml',
}

---@type string[]
local LUA_EXECUTABLES = {
  'lua5.4',
  'lua5.3',
  'lua5.2',
  'lua5.1',
  'lua',
  'luajit',
}

---@type string[]
local LUA_DEBUG_ADAPTERS = {
  'lua-debug',
  'lua-debug-adapter',
}

---@type table<string, boolean>
local DEBUGGABLE_PROCESS_NAMES = {
  lua = true,
  ['lua5.1'] = true,
  ['lua5.2'] = true,
  ['lua5.3'] = true,
  ['lua5.4'] = true,
  luajit = true,
  nvim = true,
}

---@class QompassLuaDebugProcess
---@field command string
---@field executable string
---@field pid integer

---@alias QompassLuaValidationCallback fun(ok: boolean, message: string)
---@alias QompassLuaSystemCallback fun(result: vim.SystemCompleted?, error_message: string?)

---@type table<string, vim.SystemObj>
local active_systems = {}

---@type QompassLuaDebugProcess?
local selected_process = nil

---@param message string
---@param level? integer
local function notify(message, level)
  vim.notify(NOTIFY_PREFIX .. message, level or levels.INFO)
end

---@param path string
---@return boolean
local function is_file(path)
  local stat = uv.fs_stat(path)

  return stat ~= nil and stat.type == 'file'
end

---@param command string
---@return boolean
local function executable(command)
  if command == '' then
    return false
  end

  if command:find('/', 1, true) ~= nil then
    return is_file(command) and uv.fs_access(command, 'X') == true
  end

  return fn.executable(command) == 1
end

---@param command string
---@return string?
local function executable_path(command)
  if not executable(command) then
    return nil
  end

  if command:find('/', 1, true) ~= nil then
    return fs.normalize(command)
  end

  local path = fn.exepath(command)

  if path == '' then
    return command
  end

  return fs.normalize(path)
end

---@param path string
---@return string
local function normalize(path)
  if path == '' then
    return ''
  end

  return fs.normalize(fn.fnamemodify(path, ':p'))
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

  if current_filename == '' then
    return normalize(fn.getcwd())
  end

  local detected_root = fs.root(current_filename, ROOT_MARKERS)

  if type(detected_root) == 'string' and detected_root ~= '' then
    return normalize(detected_root)
  end

  return normalize(fs.dirname(current_filename) or fn.getcwd())
end

---@param candidates string[]
---@return string?
local function first_executable(candidates)
  for index = 1, #candidates do
    local candidate = candidates[index]

    if executable(candidate) then
      return candidate
    end
  end

  return nil
end

---@return string?
local function lua_executable()
  local configured = env.LUA

  if type(configured) == 'string' and configured ~= '' and executable(configured) then
    return configured
  end

  return first_executable(LUA_EXECUTABLES)
end

---@return string?
local function lua_debug_adapter()
  local configured = env.LUA_DEBUG_ADAPTER

  if type(configured) == 'string' and configured ~= '' and executable(configured) then
    return configured
  end

  return first_executable(LUA_DEBUG_ADAPTERS)
end

---@param prompt string
---@return string?
local function prompt_program(prompt)
  local selected_path = fn.input(prompt, root() .. '/', 'file')

  if selected_path == '' then
    return nil
  end

  selected_path = normalize(selected_path)

  if not is_file(selected_path) then
    notify('Lua program does not exist: ' .. selected_path, levels.ERROR)

    return nil
  end

  return selected_path
end

---@return string?
local function current_program()
  local current_file = filename()

  if current_file ~= '' and is_file(current_file) then
    return current_file
  end

  return prompt_program('Lua program: ')
end

---@return string?
local function pick_program()
  return prompt_program('Lua program: ')
end

---@return string[]
local function program_arguments()
  local input = vim.trim(fn.input('Arguments: '))

  if input == '' then
    return {}
  end

  ---@type string[]
  local arguments = {}

  for argument in input:gmatch('%S+') do
    arguments[#arguments + 1] = argument
  end

  return arguments
end

---@return table<string, string>
local function environment()
  ---@type table<string, string>
  local variables = {}

  local lua_path = env.LUA_PATH

  if type(lua_path) == 'string' and lua_path ~= '' then
    variables.LUA_PATH = lua_path
  end

  local lua_cpath = env.LUA_CPATH

  if type(lua_cpath) == 'string' and lua_cpath ~= '' then
    variables.LUA_CPATH = lua_cpath
  end

  return variables
end

---@return integer?
local function prompt_process_id()
  local input = vim.trim(fn.input('Lua process PID: '))

  if input == '' then
    return nil
  end

  if input:match('^%d+$') == nil then
    notify('Invalid process ID', levels.WARN)

    return nil
  end

  local pid = fn.str2nr(input, 10)

  if pid <= 0 then
    notify('Process ID must be greater than zero', levels.WARN)

    return nil
  end

  return pid
end

---@return integer?
local function process_id()
  if selected_process ~= nil then
    return selected_process.pid
  end

  return prompt_process_id()
end

---@return string
local function workspace()
  return root()
end

---@return string?
local function runtime()
  local runtime_executable = lua_executable()

  if runtime_executable == nil then
    notify('Lua interpreter not found', levels.ERROR)

    return nil
  end

  return runtime_executable
end

---@return string?
local function neovim_runtime()
  local path = fn.exepath('nvim')

  if path == '' then
    notify('Neovim executable not found', levels.ERROR)

    return nil
  end

  return normalize(path)
end

---@return string?
local function neovim_config()
  local config_path = fn.stdpath('config')

  if type(config_path) ~= 'string' or config_path == '' then
    return nil
  end

  return normalize(config_path)
end

---@return string[]
local function neovim_config_arguments()
  local config_path = neovim_config()

  if config_path == nil then
    return {
      '--headless',
    }
  end

  local init_path = fs.joinpath(config_path, 'init.lua')

  if not is_file(init_path) then
    return {
      '--headless',
    }
  end

  return {
    '--headless',
    '-u',
    init_path,
  }
end

---@param line string
---@return QompassLuaDebugProcess?
local function parse_process(line)
  local pid_text, process_name, command = line:match('^%s*(%d+)%s+(%S+)%s+(.+)$')

  if pid_text == nil or process_name == nil or command == nil then
    return nil
  end

  local pid = fn.str2nr(pid_text, 10)

  if pid <= 0 or pid == uv.os_getpid() then
    return nil
  end

  local basename = fs.basename(process_name)

  if basename ~= nil and basename ~= '' then
    process_name = basename
  end

  if not DEBUGGABLE_PROCESS_NAMES[process_name] then
    return nil
  end

  ---@type QompassLuaDebugProcess
  local process = {
    command = command,
    executable = process_name,
    pid = pid,
  }

  return process
end

---@param name string
local function cancel_system(name)
  local process = active_systems[name]

  if process == nil then
    return
  end

  active_systems[name] = nil

  if not process:is_closing() then
    process:kill('sigterm')
  end
end

local function cancel_systems()
  ---@type string[]
  local names = {}

  for name in pairs(active_systems) do
    names[#names + 1] = name
  end

  for index = 1, #names do
    cancel_system(names[index])
  end
end

---@param name string
---@param command string[]
---@param timeout integer
---@param callback QompassLuaSystemCallback
local function run_system(name, command, timeout, callback)
  cancel_system(name)

  ---@type vim.SystemObj?
  local process

  local ok, process_or_error = pcall(vim.system, command, {
    text = true,
    timeout = timeout,
  }, function(result)
    vim.schedule(function()
      if active_systems[name] ~= process then
        return
      end

      active_systems[name] = nil
      callback(result, nil)
    end)
  end)

  if not ok then
    vim.schedule(function()
      callback(nil, tostring(process_or_error))
    end)

    return
  end

  ---@cast process_or_error vim.SystemObj
  process = process_or_error
  active_systems[name] = process
end

---@param result vim.SystemCompleted
---@param command string
---@return string
local function system_error(result, command)
  local stderr = vim.trim(result.stderr or '')

  if stderr ~= '' then
    return stderr
  end

  if result.code == 124 then
    return ('%s timed out'):format(command)
  end

  return ('%s exited with code %d'):format(command, result.code)
end

---@param callback fun(processes: QompassLuaDebugProcess[]?, error_message: string?)
local function discover_processes(callback)
  run_system('process-discovery', {
    'ps',
    '-eo',
    'pid=,comm=,args=',
  }, PROCESS_TIMEOUT, function(result, spawn_error)
    if result == nil then
      callback(nil, spawn_error or 'Unable to start ps')

      return
    end

    if result.code ~= 0 then
      callback(nil, system_error(result, 'ps'))

      return
    end

    ---@type QompassLuaDebugProcess[]
    local processes = {}

    for line in (result.stdout or ''):gmatch('[^\r\n]+') do
      local process = parse_process(line)

      if process ~= nil then
        processes[#processes + 1] = process
      end
    end

    table.sort(processes, function(left, right)
      if left.executable == right.executable then
        return left.pid < right.pid
      end

      return left.executable < right.executable
    end)

    callback(processes, nil)
  end)
end

---@param callback QompassLuaValidationCallback
local function validate_adapter(callback)
  local adapter = lua_debug_adapter()

  if adapter == nil then
    callback(false, 'Lua debug adapter not found')

    return
  end

  run_system('adapter-validation', {
    adapter,
    '--help',
  }, VALIDATION_TIMEOUT, function(result, spawn_error)
    if result == nil then
      callback(false, spawn_error or ('Unable to start %s'):format(adapter))

      return
    end

    if result.code ~= 0 and result.code ~= 1 then
      callback(false, system_error(result, adapter))

      return
    end

    callback(true, executable_path(adapter) or adapter)
  end)
end

---@param callback QompassLuaValidationCallback
local function validate_runtime(callback)
  local lua = lua_executable()

  if lua == nil then
    callback(false, 'Lua interpreter not found')

    return
  end

  run_system('runtime-validation', {
    lua,
    '-v',
  }, VALIDATION_TIMEOUT, function(result, spawn_error)
    if result == nil then
      callback(false, spawn_error or ('Unable to start %s'):format(lua))

      return
    end

    if result.code ~= 0 then
      callback(false, system_error(result, lua))

      return
    end

    local version = vim.trim(result.stdout or '')

    if version == '' then
      version = vim.trim(result.stderr or '')
    end

    if version == '' then
      version = executable_path(lua) or lua
    end

    callback(true, version)
  end)
end

local function show_adapter()
  local adapter = lua_debug_adapter()

  if adapter == nil then
    notify('Lua debug adapter not found', levels.WARN)

    return
  end

  notify(executable_path(adapter) or adapter)
end

local function show_runtime()
  local lua = lua_executable()

  if lua == nil then
    notify('Lua interpreter not found', levels.WARN)

    return
  end

  notify(executable_path(lua) or lua)
end

local function choose_process()
  discover_processes(function(processes, error_message)
    if processes == nil then
      notify(error_message or 'Lua process discovery failed', levels.ERROR)

      return
    end

    if #processes == 0 then
      notify('No debuggable Lua or Neovim processes found', levels.INFO)

      return
    end

    vim.ui.select(processes, {
      prompt = 'Lua debug process:',
      format_item = function(item)
        return ('%d  [%s]  %s'):format(item.pid, item.executable, item.command)
      end,
    }, function(item)
      if item == nil then
        notify('No Lua or Neovim process selected', levels.INFO)

        return
      end

      selected_process = item

      notify(('Selected PID %d: %s'):format(item.pid, item.command))
    end)
  end)
end

local function clear_process()
  if selected_process == nil then
    notify('No selected Lua process', levels.INFO)

    return
  end

  local pid = selected_process.pid

  selected_process = nil

  notify(('Cleared selected PID %d'):format(pid))
end

local function show_process()
  if selected_process == nil then
    notify('No selected Lua process', levels.INFO)

    return
  end

  notify(('%d  [%s]  %s'):format(selected_process.pid, selected_process.executable, selected_process.command))
end

local function check_adapter()
  validate_adapter(function(ok, message)
    if not ok then
      notify(message, levels.WARN)

      return
    end

    notify('Adapter OK: ' .. message)
  end)
end

local function check_runtime()
  validate_runtime(function(ok, message)
    if not ok then
      notify(message, levels.WARN)

      return
    end

    notify('Runtime OK: ' .. message)
  end)
end

local function check_environment()
  local adapter_done = false
  local adapter_ok = false
  local adapter_message = 'not checked'
  local runtime_done = false
  local runtime_ok = false
  local runtime_message = 'not checked'

  local function report()
    if not adapter_done or not runtime_done then
      return
    end

    local level = adapter_ok and runtime_ok and levels.INFO or levels.WARN

    notify(
      table.concat({
        ('adapter: %s (%s)'):format(adapter_ok and 'OK' or 'FAIL', adapter_message),
        ('runtime: %s (%s)'):format(runtime_ok and 'OK' or 'FAIL', runtime_message),
      }, '\n'),
      level
    )
  end

  validate_adapter(function(ok, message)
    adapter_done = true
    adapter_ok = ok
    adapter_message = message
    report()
  end)

  validate_runtime(function(ok, message)
    runtime_done = true
    runtime_ok = ok
    runtime_message = message
    report()
  end)
end

M.adapter = {
  command = lua_debug_adapter() or 'lua-debug',
  name = ADAPTER_NAME,
  type = 'executable',
}

M.configurations = {
  lua = {
    {
      args = program_arguments,
      cwd = workspace,
      env = environment,
      lua = runtime,
      name = 'Lua: Launch current file',
      program = current_program,
      request = 'launch',
      stopOnEntry = false,
      type = ADAPTER_NAME,
    },
    {
      args = program_arguments,
      cwd = workspace,
      env = environment,
      lua = runtime,
      name = 'Lua: Launch selected file',
      program = pick_program,
      request = 'launch',
      stopOnEntry = false,
      type = ADAPTER_NAME,
    },
    {
      cwd = workspace,
      env = environment,
      name = 'Lua: Attach to process',
      processId = process_id,
      request = 'attach',
      type = ADAPTER_NAME,
    },
    {
      args = {
        '--clean',
        '--headless',
        '-u',
        'NONE',
      },
      cwd = workspace,
      env = environment,
      lua = neovim_runtime,
      name = 'Lua: Launch clean Neovim',
      program = current_program,
      request = 'launch',
      stopOnEntry = false,
      type = ADAPTER_NAME,
    },
    {
      args = neovim_config_arguments,
      cwd = workspace,
      env = environment,
      lua = neovim_runtime,
      name = 'Lua: Launch Neovim config',
      program = current_program,
      request = 'launch',
      stopOnEntry = false,
      type = ADAPTER_NAME,
    },
  },
}

M.filetypes = {
  'lua',
}

M.commands = {
  LuaDebugAdapter = {
    callback = show_adapter,
    desc = 'Show Lua debug adapter',
  },
  LuaDebugCheck = {
    callback = check_environment,
    desc = 'Validate Lua debug environment',
  },
  LuaDebugCheckAdapter = {
    callback = check_adapter,
    desc = 'Validate Lua debug adapter',
  },
  LuaDebugCheckRuntime = {
    callback = check_runtime,
    desc = 'Validate Lua runtime',
  },
  LuaDebugProcess = {
    callback = choose_process,
    desc = 'Select Lua debug process',
  },
  LuaDebugProcessClear = {
    callback = clear_process,
    desc = 'Clear selected Lua debug process',
  },
  LuaDebugProcessShow = {
    callback = show_process,
    desc = 'Show selected Lua debug process',
  },
  LuaDebugProgram = {
    callback = function()
      local program = pick_program()

      if program ~= nil then
        notify(program)
      end
    end,
    desc = 'Select Lua debug program',
  },
  LuaDebugRoot = {
    callback = function()
      notify(root())
    end,
    desc = 'Show Lua debug root',
  },
  LuaDebugRuntime = {
    callback = show_runtime,
    desc = 'Show Lua runtime',
  },
}

function M.setup()
  local adapter = lua_debug_adapter()

  if adapter == nil then
    notify('lua-debug is not available', levels.WARN)
  else
    M.adapter.command = adapter
  end

  if lua_executable() == nil then
    notify('Lua interpreter is not available', levels.WARN)
  end
end
function M.teardown()
  cancel_systems()

  selected_process = nil
end
return M

