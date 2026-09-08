-- #################################################################
-- /qompassai/Diver/lua/dap/unreal.lua
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
---@source https://lldb.llvm.org/use/lldbdap.html
---@source https://sourceware.org/gdb/current/onlinedocs/gdb.html/Debugger-Adapter-Protocol.html

local api = vim.api
local env = vim.env
local fn = vim.fn
local fs = vim.fs
local levels = vim.log.levels
local uv = vim.uv

local M = {}

local SOURCE = 'unreal-dap'
local PROBE_TIMEOUT = 5000
local PROCESS_TIMEOUT = 5000
local NOTIFICATION_LIMIT = 4096

---@type string[]
local ROOT_MARKERS = {
  'Config',
  'Content',
  'Source',
  'Plugins',
  '.git',
}

---@type string[]
local ENGINE_ENVIRONMENT_VARIABLES = {
  'NVIM_UNREAL_ENGINE_ROOT',
  'UNREAL_ENGINE_ROOT',
  'UE_ENGINE_ROOT',
  'UE_ROOT',
}

local USER_HOME = fn.expand('~')

---@type string[]
local ENGINE_ROOT_CANDIDATES = {
  fs.joinpath(USER_HOME, 'UnrealEngine'),
  fs.joinpath(USER_HOME, 'UnrealEngine-5'),
  fs.joinpath(USER_HOME, 'UnrealEngine-5.8'),
  fs.joinpath(USER_HOME, '.local', 'share', 'UnrealEngine'),
  '/opt/UnrealEngine',
  '/opt/unreal-engine',
}

---@type string[]
local BUILD_CONFIGURATIONS = {
  'DebugGame',
  'Development',
  'Debug',
}

---@type string[]
local TARGET_KINDS = {
  'Editor',
  'Game',
  'Client',
  'Server',
}

---@alias UnrealDapAdapter 'lldb'|'gdb'
---@alias UnrealDapAdapterType 'unreal-lldb'|'unreal-gdb'

---@class UnrealDapOptions
---@field adapter? UnrealDapAdapter
---@field engine_root? string
---@field project? string
---@field root? string

---@class UnrealDapProcess
---@field arguments string
---@field command string
---@field pid integer

---@class UnrealDapState
---@field adapter UnrealDapAdapter
---@field editor? string
---@field engine_root? string
---@field executable? string
---@field gdb_dap_available? boolean
---@field project_root? string
---@field uproject? string

---@type UnrealDapState
local state = {
  adapter = 'lldb',
}

---@param message string
---@param level? integer
local function notify(message, level)
  vim.notify(('[%s] %s'):format(SOURCE, message), level or levels.INFO)
end

---@param path string
---@return boolean
local function is_file(path)
  if path == '' then
    return false
  end

  local stat = uv.fs_stat(path)

  return stat ~= nil and stat.type == 'file'
end

---@param path string
---@return boolean
local function is_directory(path)
  if path == '' then
    return false
  end

  local stat = uv.fs_stat(path)

  return stat ~= nil and stat.type == 'directory'
end

---@param path string
---@return string
local function normalize(path)
  if path == '' then
    return ''
  end

  return fs.normalize(fn.fnamemodify(path, ':p'))
end

---@param path string
---@return boolean
local function path_is_executable(path)
  return is_file(path) and uv.fs_access(path, 'X') == true
end

---@param command string
---@return string?
local function executable_path(command)
  if command == '' then
    return nil
  end

  if command:find('/', 1, true) ~= nil then
    local path = normalize(fn.expand(command))

    return path_is_executable(path) and path or nil
  end

  if fn.executable(command) ~= 1 then
    return nil
  end

  local path = fn.exepath(command)

  if path == '' then
    return command
  end

  return fs.normalize(path)
end

---@param value string
---@return string?
local function resolve_executable(value)
  if value == '' then
    return nil
  end

  return executable_path(fn.expand(value))
end

---@param bufnr? integer
---@return string
local function filename(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()

  if not api.nvim_buf_is_valid(bufnr) then
    return ''
  end

  local name = api.nvim_buf_get_name(bufnr)

  return name == '' and '' or normalize(name)
end

---@param command string[]
---@param cwd? string
---@param timeout? integer
---@return vim.SystemCompleted?, string?
local function system(command, cwd, timeout)
  ---@type vim.SystemOpts
  local options = {
    text = true,
  }

  if cwd ~= nil and cwd ~= '' then
    options.cwd = cwd
  end

  if timeout ~= nil then
    options.timeout = timeout
  end

  local started, process_or_error = pcall(vim.system, command, options)

  if not started then
    return nil, tostring(process_or_error)
  end

  ---@cast process_or_error vim.SystemObj
  local completed, result_or_error = pcall(process_or_error.wait, process_or_error)

  if not completed then
    return nil, tostring(result_or_error)
  end

  ---@cast result_or_error vim.SystemCompleted
  return result_or_error, nil
end

---@param result vim.SystemCompleted
---@param fallback string
---@return string
local function result_message(result, fallback)
  local stderr = vim.trim(result.stderr or '')

  if stderr ~= '' then
    return stderr
  end

  local stdout = vim.trim(result.stdout or '')

  if stdout ~= '' then
    return stdout
  end

  return fallback
end

---@param message string
---@return string
local function notification_tail(message)
  if #message <= NOTIFICATION_LIMIT then
    return message
  end

  return '[output truncated]\n' .. message:sub(-NOTIFICATION_LIMIT)
end

---@param name string
---@return boolean
local function is_uproject_name(name)
  return name:sub(-9) == '.uproject'
end

---@param directory string
---@return string?
local function uproject_in_directory(directory)
  if not is_directory(directory) then
    return nil
  end

  ---@type string[]
  local projects = {}

  for name, kind in fs.dir(directory) do
    if kind == 'file' and is_uproject_name(name) then
      projects[#projects + 1] = fs.normalize(fs.joinpath(directory, name))
    end
  end

  table.sort(projects)

  return projects[1]
end

---@param value string
---@return string?
local function resolve_project_candidate(value)
  local candidate = normalize(fn.expand(value))

  if is_file(candidate) and is_uproject_name(candidate) then
    return candidate
  end

  return uproject_in_directory(candidate)
end

---@param start string
---@return string?
local function find_uproject_upward(start)
  local directory = start

  while directory ~= '' do
    local project = uproject_in_directory(directory)

    if project ~= nil then
      return project
    end

    local parent = fs.dirname(directory)

    if parent == nil or parent == directory then
      break
    end

    directory = parent
  end

  return nil
end

---@param bufnr? integer
---@return string?
local function resolve_uproject(bufnr)
  if state.uproject ~= nil and is_file(state.uproject) then
    return state.uproject
  end

  local configured = env.NVIM_UNREAL_PROJECT

  if type(configured) == 'string' and configured ~= '' then
    local project = resolve_project_candidate(configured)

    if project ~= nil then
      state.uproject = project
      state.project_root = fs.dirname(project)

      return project
    end
  end

  if state.project_root ~= nil then
    local project = uproject_in_directory(state.project_root)

    if project ~= nil then
      state.uproject = project

      return project
    end
  end

  local current = filename(bufnr)

  if current ~= '' then
    local start = fs.dirname(current)

    if start ~= nil then
      local project = find_uproject_upward(start)

      if project ~= nil then
        state.uproject = project
        state.project_root = fs.dirname(project)

        return project
      end
    end
  end

  local project = find_uproject_upward(normalize(fn.getcwd()))

  if project ~= nil then
    state.uproject = project
    state.project_root = fs.dirname(project)
  end

  return project
end

---@param bufnr? integer
---@return string
local function project_root(bufnr)
  local project = resolve_uproject(bufnr)

  if project ~= nil then
    local directory = fs.dirname(project)

    if directory ~= nil then
      state.project_root = fs.normalize(directory)

      return state.project_root
    end
  end

  if state.project_root ~= nil and is_directory(state.project_root) then
    return state.project_root
  end

  local current = filename(bufnr)

  if current ~= '' then
    local detected = fs.root(current, ROOT_MARKERS)

    if detected ~= nil and detected ~= '' then
      state.project_root = fs.normalize(detected)

      return state.project_root
    end

    local parent = fs.dirname(current)

    if parent ~= nil then
      return fs.normalize(parent)
    end
  end

  return normalize(fn.getcwd())
end

---@return boolean
local function is_unreal_project()
  return resolve_uproject() ~= nil
end

---@return string
local function project_name()
  local project = resolve_uproject()

  if project == nil then
    return ''
  end

  local basename = fs.basename(project)

  if basename == nil then
    return ''
  end

  return basename:gsub('%.uproject$', '')
end

---@param root string
---@return string
local function engine_editor_path(root)
  return fs.joinpath(root, 'Engine', 'Binaries', 'Linux', 'UnrealEditor')
end

---@param root string
---@return string
local function engine_build_path(root)
  return fs.joinpath(root, 'Engine', 'Build', 'BatchFiles', 'Linux', 'Build.sh')
end

---@param root string
---@return boolean
local function valid_engine_root(root)
  if not is_directory(fs.joinpath(root, 'Engine')) then
    return false
  end

  return is_file(engine_build_path(root)) or is_file(engine_editor_path(root))
end

---@return string?
local function scan_home_engines()
  if not is_directory(USER_HOME) then
    return nil
  end

  ---@type string[]
  local candidates = {}

  for name, kind in fs.dir(USER_HOME) do
    if kind == 'directory' and (name:match('^UnrealEngine') or name:match('^UE_5')) then
      local candidate = fs.joinpath(USER_HOME, name)

      if valid_engine_root(candidate) then
        candidates[#candidates + 1] = fs.normalize(candidate)
      end
    end
  end

  table.sort(candidates, function(left, right)
    return left > right
  end)

  return candidates[1]
end

---@return string?
local function resolve_engine_root()
  if state.engine_root ~= nil and valid_engine_root(state.engine_root) then
    return state.engine_root
  end

  for index = 1, #ENGINE_ENVIRONMENT_VARIABLES do
    local configured = env[ENGINE_ENVIRONMENT_VARIABLES[index]]

    if type(configured) == 'string' and configured ~= '' then
      local candidate = normalize(fn.expand(configured))

      if valid_engine_root(candidate) then
        state.engine_root = candidate

        return candidate
      end
    end
  end

  for index = 1, #ENGINE_ROOT_CANDIDATES do
    local candidate = normalize(ENGINE_ROOT_CANDIDATES[index])

    if valid_engine_root(candidate) then
      state.engine_root = candidate

      return candidate
    end
  end

  local candidate = scan_home_engines()

  if candidate ~= nil then
    state.engine_root = candidate
  end

  return candidate
end

---@return string?
local function resolve_editor()
  if state.editor ~= nil and path_is_executable(state.editor) then
    return state.editor
  end

  local configured = env.NVIM_UNREAL_EDITOR

  if type(configured) == 'string' and configured ~= '' then
    local candidate = resolve_executable(configured)

    if candidate ~= nil then
      state.editor = candidate

      return candidate
    end
  end

  local root = resolve_engine_root()

  if root ~= nil then
    local candidate = engine_editor_path(root)

    if path_is_executable(candidate) then
      state.editor = fs.normalize(candidate)

      return state.editor
    end
  end
  local candidate = executable_path('UnrealEditor')
  if candidate ~= nil then
    state.editor = candidate
  end

  return candidate
end

---@return string?
local function resolve_build_script()
  local root = resolve_engine_root()

  if root == nil then
    return nil
  end

  local candidate = engine_build_path(root)

  return path_is_executable(candidate) and fs.normalize(candidate) or nil
end

---@return string?
local function lldb_dap()
  local configured = env.NVIM_UNREAL_LLDB_DAP

  if type(configured) ~= 'string' or configured == '' then
    configured = env.NVIM_LLDB_DAP
  end

  if type(configured) == 'string' and configured ~= '' then
    local candidate = resolve_executable(configured)

    if candidate ~= nil then
      return candidate
    end
  end
  return executable_path('lldb-dap')
end
---@return string?
local function gdb()
  local configured = env.NVIM_UNREAL_GDB_DAP
  if type(configured) ~= 'string' or configured == '' then
    configured = env.NVIM_GDB_DAP
  end
  if type(configured) == 'string' and configured ~= '' then
    local candidate = resolve_executable(configured)

    if candidate ~= nil then
      return candidate
    end
  end

  return executable_path('gdb')
end

---@return boolean
local function gdb_supports_dap()
  if state.gdb_dap_available ~= nil then
    return state.gdb_dap_available
  end

  local binary = gdb()

  if binary == nil then
    state.gdb_dap_available = false

    return false
  end

  local result = system({
    binary,
    '--quiet',
    '--nx',
    '--batch',
    '--interpreter=dap',
  }, nil, PROBE_TIMEOUT)

  state.gdb_dap_available = result ~= nil and result.code == 0

  return state.gdb_dap_available
end

---@return UnrealDapAdapterType
local function active_adapter_type()
  if state.adapter == 'lldb' and lldb_dap() ~= nil then
    return 'unreal-lldb'
  end

  if state.adapter == 'gdb' and gdb_supports_dap() then
    return 'unreal-gdb'
  end

  if lldb_dap() ~= nil then
    state.adapter = 'lldb'

    return 'unreal-lldb'
  end

  if gdb_supports_dap() then
    state.adapter = 'gdb'

    return 'unreal-gdb'
  end

  notify('neither lldb-dap nor GDB DAP is available', levels.ERROR)

  return 'unreal-lldb'
end

local function select_adapter()
  local selection = fn.inputlist({
    'Unreal native debugger:',
    '1. LLDB DAP',
    '2. GDB DAP',
  })

  if selection == 1 then
    if lldb_dap() == nil then
      notify('lldb-dap is unavailable', levels.ERROR)

      return
    end

    state.adapter = 'lldb'
    notify('Unreal debugger: LLDB DAP')

    return
  end

  if selection == 2 then
    if not gdb_supports_dap() then
      notify('GDB DAP is unavailable', levels.ERROR)

      return
    end

    state.adapter = 'gdb'
    notify('Unreal debugger: GDB DAP')
  end
end

---@return string
local function cwd()
  return project_root()
end

---@param prompt string
---@return string[]
local function prompt_arguments(prompt)
  local input = vim.trim(fn.input(prompt))

  if input == '' then
    return {}
  end

  local ok, arguments_or_error = pcall(fn.shellsplit, input)

  if not ok then
    notify(('invalid arguments: %s'):format(tostring(arguments_or_error)), levels.ERROR)

    return {}
  end

  ---@cast arguments_or_error string[]
  return arguments_or_error
end

---@return string[]
local function prompt_program_args()
  return prompt_arguments('Unreal arguments: ')
end

---@return table<string, string>
local function inherited_environment()
  ---@type table<string, string>
  local variables = {}

  for key, value in pairs(fn.environ()) do
    if type(key) == 'string' and type(value) == 'string' then
      variables[key] = value
    end
  end

  return variables
end

---@return table<string, string>
local function prompt_environment()
  local variables = inherited_environment()
  local assignments = prompt_arguments('Environment KEY=VALUE pairs: ')

  for index = 1, #assignments do
    local item = assignments[index]
    local key, value = item:match('^([%a_][%w_]*)=(.*)$')

    if key ~= nil and value ~= nil then
      variables[key] = value
    else
      notify(('ignoring invalid environment assignment: %s'):format(item), levels.WARN)
    end
  end

  return variables
end

---@return integer
local function prompt_pid()
  local input = vim.trim(fn.input('Unreal process PID: '))

  if input == '' then
    return 0
  end

  if input:match('^%d+$') == nil then
    notify(('invalid PID: %s'):format(input), levels.ERROR)

    return 0
  end

  local pid = fn.str2nr(input, 10)

  if pid < 1 then
    notify(('invalid PID: %s'):format(input), levels.ERROR)

    return 0
  end

  return pid
end

---@return UnrealDapProcess[]
local function unreal_processes()
  local result, error_message = system({
    'ps',
    '-eo',
    'pid=,comm=,args=',
  }, nil, PROCESS_TIMEOUT)

  if result == nil then
    notify(error_message or 'failed to inspect processes', levels.ERROR)

    return {}
  end

  if result.code ~= 0 then
    notify(result_message(result, 'process discovery failed'), levels.ERROR)

    return {}
  end

  ---@type UnrealDapProcess[]
  local processes = {}

  for line in (result.stdout or ''):gmatch('[^\r\n]+') do
    local pid_text, command, arguments = line:match('^%s*(%d+)%s+(%S+)%s*(.*)$')
    if pid_text ~= nil and command ~= nil then
      local lower_command = command:lower()
      local process_arguments = arguments or ''
      local lower_arguments = process_arguments:lower()

      if
        lower_command:find('unreal', 1, true) ~= nil
        or lower_arguments:find('unrealeditor', 1, true) ~= nil
        or lower_arguments:find('.uproject', 1, true) ~= nil
      then
        processes[#processes + 1] = {
          arguments = process_arguments,
          command = fs.basename(command) or command,
          pid = fn.str2nr(pid_text, 10),
        }
      end
    end
  end

  table.sort(processes, function(left, right)
    if left.command == right.command then
      return left.pid < right.pid
    end

    return left.command < right.command
  end)

  return processes
end

---@return integer
local function choose_unreal_process()
  local processes = unreal_processes()

  if #processes == 0 then
    notify('no Unreal Editor or game process found', levels.WARN)

    return 0
  end

  ---@type string[]
  local choices = {
    'Choose Unreal process:',
  }

  for index = 1, #processes do
    local process = processes[index]

    choices[#choices + 1] = ('%d. PID %-7d %s %s'):format(index, process.pid, process.command, process.arguments)
  end

  local selected = fn.inputlist(choices)

  if selected < 1 or selected > #processes then
    return 0
  end

  return processes[selected].pid
end

---@return string
local function prompt_configuration()
  ---@type string[]
  local choices = {
    'Unreal build configuration:',
  }

  for index = 1, #BUILD_CONFIGURATIONS do
    choices[#choices + 1] = ('%d. %s'):format(index, BUILD_CONFIGURATIONS[index])
  end

  local selected = fn.inputlist(choices)

  return BUILD_CONFIGURATIONS[selected] or 'DebugGame'
end

---@return string
local function prompt_target_kind()
  ---@type string[]
  local choices = {
    'Unreal target:',
  }
  for index = 1, #TARGET_KINDS do
    choices[#choices + 1] = ('%d. %s'):format(index, TARGET_KINDS[index])
  end

  local selected = fn.inputlist(choices)

  return TARGET_KINDS[selected] or 'Editor'
end

---@param configuration string
---@param target_kind string
---@return boolean
local function build_project(configuration, target_kind)
  local build = resolve_build_script()
  local project = resolve_uproject()

  if build == nil then
    notify('executable Unreal Build.sh was not found', levels.ERROR)

    return false
  end

  if project == nil then
    notify('no .uproject was found', levels.ERROR)

    return false
  end

  local name = project_name()

  if name == '' then
    notify('unable to determine Unreal project name', levels.ERROR)

    return false
  end

  local target = target_kind == 'Game' and name or name .. target_kind
  local command = {
    build,
    target,
    'Linux',
    configuration,
    project,
    '-WaitMutex',
  }
  notify(('building %s Linux %s'):format(target, configuration))

  local result, error_message = system(command, project_root())

  if result == nil then
    notify(error_message or 'failed to invoke Unreal Build Tool', levels.ERROR)

    return false
  end

  if result.code ~= 0 then
    local message = result_message(result, ('Unreal build exited with code %d'):format(result.code))

    notify(notification_tail(message), levels.ERROR)

    return false
  end
  state.executable = nil
  notify(('%s Linux %s built successfully'):format(target, configuration))
  return true
end
local function build_debug_game_editor()
  build_project('DebugGame', 'Editor')
end
local function build_debug_editor()
  build_project('Debug', 'Editor')
end
local function build_interactive()
  build_project(prompt_configuration(), prompt_target_kind())
end

---@return string
local function editor_program()
  local editor = resolve_editor()

  if editor == nil then
    notify('UnrealEditor was not found', levels.ERROR)

    return ''
  end

  return editor
end
---@param extra_args? string[]
---@return string[]
local function make_editor_arguments(extra_args)
  local project = resolve_uproject()
  if project == nil then
    notify('no .uproject was found', levels.ERROR)

    return {}
  end
  local arguments = {
    project,
  }
  if extra_args ~= nil then
    vim.list_extend(arguments, extra_args)
  end
  return arguments
end

---@return string[]
local function editor_arguments()
  return make_editor_arguments({
    '-log',
  })
end

---@return string[]
local function editor_debug_arguments()
  return make_editor_arguments({
    '-debug',
    '-log',
  })
end

---@return string[]
local function editor_game_arguments()
  return make_editor_arguments({
    '-game',
    '-log',
  })
end

---@return string[]
local function gameplay_debugger_arguments()
  return make_editor_arguments({
    '-game',
    '-log',
    '-ExecCmds=EnableGDT',
  })
end

---@return string[]
local function gameplay_debugger_camera_arguments()
  return make_editor_arguments({
    '-game',
    '-log',
    '-ExecCmds=EnableGDT,ToggleDebugCamera',
  })
end

---@return string[]
local function editor_custom_arguments()
  local arguments = make_editor_arguments()

  vim.list_extend(arguments, prompt_program_args())

  return arguments
end

---@return string
local function choose_game_binary()
  if state.executable ~= nil and path_is_executable(state.executable) then
    return state.executable
  end

  local root = project_root()
  local name = project_name()
  local binary_directory = fs.joinpath(root, 'Binaries', 'Linux')

  if name ~= '' then
    local candidates = {
      fs.joinpath(binary_directory, name),
      fs.joinpath(binary_directory, name .. '-Linux-DebugGame'),
      fs.joinpath(binary_directory, name .. '-Linux-Development'),
      fs.joinpath(binary_directory, name .. '-Linux-Debug'),
    }

    for index = 1, #candidates do
      if path_is_executable(candidates[index]) then
        state.executable = fs.normalize(candidates[index])

        return state.executable
      end
    end
  end

  local selected = fn.input('Unreal game executable: ', binary_directory .. '/', 'file')

  if selected == '' then
    return ''
  end

  selected = normalize(fn.expand(selected))

  if not path_is_executable(selected) then
    notify(('not an executable: %s'):format(selected), levels.ERROR)

    return ''
  end

  state.executable = selected

  return selected
end

---@param extra_args? string[]
local function launch_editor_detached(extra_args)
  local editor = resolve_editor()
  local project = resolve_uproject()

  if editor == nil then
    notify('UnrealEditor was not found', levels.ERROR)

    return
  end

  if project == nil then
    notify('no .uproject was found', levels.ERROR)

    return
  end

  local command = {
    editor,
    project,
  }

  if extra_args ~= nil then
    vim.list_extend(command, extra_args)
  end

  local job_id = fn.jobstart(command, {
    cwd = project_root(),
    detach = true,
  })
  if job_id <= 0 then
    notify('failed to launch Unreal Editor', levels.ERROR)

    return
  end

  notify(('Unreal Editor launched as job %d'):format(job_id))
end

local function launch_editor()
  launch_editor_detached({
    '-log',
  })
end

local function launch_gameplay_debugger()
  launch_editor_detached({
    '-game',
    '-log',
    '-ExecCmds=EnableGDT',
  })
end

local function launch_debug_camera()
  launch_editor_detached({
    '-game',
    '-log',
    '-ExecCmds=EnableGDT,ToggleDebugCamera',
  })
end

local function open_logs()
  local directory = fs.joinpath(project_root(), 'Saved', 'Logs')

  if not is_directory(directory) then
    notify('Unreal Saved/Logs directory does not exist', levels.WARN)

    return
  end

  vim.cmd('edit ' .. fn.fnameescape(directory))
end

local function select_engine_root()
  local selected = fn.input('Unreal Engine root: ', resolve_engine_root() or '', 'dir')

  if selected == '' then
    return
  end

  selected = normalize(fn.expand(selected))

  if not valid_engine_root(selected) then
    notify(('not a valid Unreal Engine root: %s'):format(selected), levels.ERROR)

    return
  end

  state.engine_root = selected
  state.editor = nil

  notify(('Unreal Engine root: %s'):format(selected))
end

local function select_project()
  local selected = fn.input('Unreal .uproject: ', resolve_uproject() or '', 'file')

  if selected == '' then
    return
  end

  local project = resolve_project_candidate(selected)

  if project == nil then
    notify(('not an Unreal .uproject: %s'):format(selected), levels.ERROR)

    return
  end

  state.uproject = project
  state.project_root = fs.dirname(project)
  state.executable = nil

  notify(('Unreal project: %s'):format(project))
end

local function clear_cache()
  state.editor = nil
  state.engine_root = nil
  state.executable = nil
  state.gdb_dap_available = nil
  state.project_root = nil
  state.uproject = nil
  notify('Unreal debugger discovery cache cleared')
end
local function status()
  local project = resolve_uproject()
  local name = project_name()
  local engine = resolve_engine_root()
  local editor = resolve_editor()
  notify(table.concat({
    'project root: ' .. project_root(),
    '.uproject: ' .. (project or 'not found'),
    'project name: ' .. (name ~= '' and name or 'unknown'),
    'engine root: ' .. (engine or 'not found'),
    'UnrealEditor: ' .. (editor or 'not found'),
    'build script: ' .. (resolve_build_script() or 'not found'),
    'active debugger: ' .. state.adapter,
    'lldb-dap: ' .. (lldb_dap() or 'not found'),
    'GDB DAP: ' .. (gdb_supports_dap() and 'available' or 'unavailable'),
    'Gameplay Debugger: runtime overlay',
    'Gameplay Debugger activation: apostrophe / EnableGDT',
  }, '\n'))
end

-- Unreal's Gameplay Debugger is a runtime overlay, not a DAP implementation.
-- Native C++ debugging is provided by lldb-dap or GDB's native DAP interpreter.
---@type table<string, table>
M.adapters = {
  ['unreal-lldb'] = {
    command = lldb_dap() or 'lldb-dap',
    name = 'unreal-lldb',
    options = {
      source_filetype = 'cpp',
    },
    type = 'executable',
  },
  ['unreal-gdb'] = {
    args = {
      '--quiet',
      '--nx',
      '--interpreter=dap',
    },
    command = gdb() or 'gdb',
    name = 'unreal-gdb',
    options = {
      source_filetype = 'cpp',
    },
    type = 'executable',
  },
}

---@type table[]
local configurations = {
  {
    args = editor_arguments,
    console = 'integratedTerminal',
    cwd = cwd,
    name = 'Unreal: Editor',
    program = editor_program,
    request = 'launch',
    stopOnEntry = false,
    type = active_adapter_type,
  },
  {
    args = editor_debug_arguments,
    console = 'integratedTerminal',
    cwd = cwd,
    name = 'Unreal: Editor Debug Modules',
    program = editor_program,
    request = 'launch',
    stopOnEntry = false,
    type = active_adapter_type,
  },
  {
    args = editor_custom_arguments,
    console = 'integratedTerminal',
    cwd = cwd,
    env = prompt_environment,
    name = 'Unreal: Editor with Arguments',
    program = editor_program,
    request = 'launch',
    stopOnEntry = false,
    type = active_adapter_type,
  },
  {
    args = editor_game_arguments,
    console = 'integratedTerminal',
    cwd = cwd,
    name = 'Unreal: Game through Editor',
    program = editor_program,
    request = 'launch',
    stopOnEntry = false,
    type = active_adapter_type,
  },
  {
    args = gameplay_debugger_arguments,
    console = 'integratedTerminal',
    cwd = cwd,
    name = 'Unreal: Game + Gameplay Debugger',
    program = editor_program,
    request = 'launch',
    stopOnEntry = false,
    type = active_adapter_type,
  },
  {
    args = gameplay_debugger_camera_arguments,
    console = 'integratedTerminal',
    cwd = cwd,
    name = 'Unreal: Game + Gameplay Debugger + Debug Camera',
    program = editor_program,
    request = 'launch',
    stopOnEntry = false,
    type = active_adapter_type,
  },
  {
    args = prompt_program_args,
    console = 'integratedTerminal',
    cwd = cwd,
    env = prompt_environment,
    name = 'Unreal: Standalone Game Binary',
    program = choose_game_binary,
    request = 'launch',
    stopOnEntry = false,
    type = active_adapter_type,
  },
  {
    name = 'Unreal: Attach Editor/Game',
    pid = choose_unreal_process,
    request = 'attach',
    type = active_adapter_type,
  },
  {
    name = 'Unreal: Attach PID',
    pid = prompt_pid,
    request = 'attach',
    type = active_adapter_type,
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
    callback = select_adapter,
    desc = 'Select Unreal native debugger',
  },
  UnrealDebugBuild = {
    callback = build_interactive,
    desc = 'Build Unreal project',
  },
  UnrealDebugBuildDebug = {
    callback = build_debug_editor,
    desc = 'Build Unreal Editor Debug',
  },
  UnrealDebugBuildGame = {
    callback = build_debug_game_editor,
    desc = 'Build Unreal Editor DebugGame',
  },
  UnrealDebugClear = {
    callback = clear_cache,
    desc = 'Clear Unreal DAP discovery cache',
  },
  UnrealDebugEngine = {
    callback = select_engine_root,
    desc = 'Select Unreal Engine root',
  },
  UnrealDebugGameplay = {
    callback = launch_gameplay_debugger,
    desc = 'Launch Unreal game with Gameplay Debugger',
  },
  UnrealDebugGameplayCamera = {
    callback = launch_debug_camera,
    desc = 'Launch Gameplay Debugger and Debug Camera',
  },
  UnrealDebugLaunch = {
    callback = launch_editor,
    desc = 'Launch Unreal Editor',
  },
  UnrealDebugLogs = {
    callback = open_logs,
    desc = 'Open Unreal project logs',
  },
  UnrealDebugProject = {
    callback = select_project,
    desc = 'Select Unreal project',
  },
  UnrealDebugStatus = {
    callback = status,
    desc = 'Show Unreal debugger status',
  },
}

---@type table<string, DebugMapping>
M.mappings = {
  unreal_debug_adapter = {
    desc = 'Debug Unreal: Select adapter',
    lhs = '<leader>dUa',
    mode = 'n',
    rhs = select_adapter,
  },
  unreal_debug_build = {
    desc = 'Debug Unreal: Build',
    lhs = '<leader>dUb',
    mode = 'n',
    rhs = build_interactive,
  },
  unreal_debug_gameplay = {
    desc = 'Debug Unreal: Gameplay Debugger',
    lhs = '<leader>dUg',
    mode = 'n',
    rhs = launch_gameplay_debugger,
  },
  unreal_debug_launch = {
    desc = 'Debug Unreal: Launch Editor',
    lhs = '<leader>dUl',
    mode = 'n',
    rhs = launch_editor,
  },
  unreal_debug_status = {
    desc = 'Debug Unreal: Status',
    lhs = '<leader>dUs',
    mode = 'n',
    rhs = status,
  },
}

---@param opts? UnrealDapOptions
function M.setup(opts)
  opts = opts or {}

  if opts.adapter ~= nil then
    if opts.adapter == 'lldb' or opts.adapter == 'gdb' then
      state.adapter = opts.adapter
    else
      notify(('invalid adapter: %s'):format(tostring(opts.adapter)), levels.WARN)
    end
  end

  if opts.root ~= nil then
    local root = normalize(opts.root)

    if is_directory(root) then
      state.project_root = root
    else
      notify(('invalid project root: %s'):format(root), levels.WARN)
    end
  end

  if opts.project ~= nil then
    local project = resolve_project_candidate(opts.project)

    if project ~= nil then
      state.uproject = project
      state.project_root = fs.dirname(project)
      state.executable = nil
    else
      notify(('invalid Unreal project: %s'):format(opts.project), levels.WARN)
    end
  end

  if opts.engine_root ~= nil then
    local root = normalize(opts.engine_root)

    if valid_engine_root(root) then
      state.engine_root = root
      state.editor = nil
    else
      notify(('invalid Unreal Engine root: %s'):format(root), levels.WARN)
    end
  end

  local lldb = lldb_dap()

  if lldb ~= nil then
    M.adapters['unreal-lldb'].command = lldb
  end

  local gdb_path = gdb()

  if gdb_path ~= nil then
    M.adapters['unreal-gdb'].command = gdb_path
  end

  if resolve_uproject() == nil then
    vim.schedule(function()
      notify('current workspace is not an Unreal project', levels.DEBUG)
    end)
  end

  if resolve_engine_root() == nil then
    vim.schedule(function()
      notify(
        table.concat({
          'Unreal Engine installation was not found.',
          '',
          'Set one of:',
          '  NVIM_UNREAL_ENGINE_ROOT=/path/to/UnrealEngine',
          '  UNREAL_ENGINE_ROOT=/path/to/UnrealEngine',
          '  UE_ENGINE_ROOT=/path/to/UnrealEngine',
          '  UE_ROOT=/path/to/UnrealEngine',
        }, '\n'),
        levels.WARN
      )
    end)
  end

  local gdb_dap_available = gdb_path ~= nil and gdb_supports_dap()

  if lldb == nil and not gdb_dap_available then
    vim.schedule(function()
      notify('neither lldb-dap nor GDB DAP is available', levels.ERROR)
    end)
  elseif lldb == nil then
    state.adapter = 'gdb'
  elseif state.adapter == 'gdb' and not gdb_dap_available then
    state.adapter = 'lldb'
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
---@return UnrealDapAdapter
function M.active_adapter()
  return state.adapter
end

return M