-- #################################################################
-- /qompassai/lua/dap/bash.lua
-- Native Bash Debug Adapter Configuration
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
---@source https://github.com/rogalmic/vscode-bash-debug
---@source https://bashdb.sourceforge.net/

local api = vim.api
local env = vim.env
local fn = vim.fn
local fs = vim.fs
local json = vim.json
local levels = vim.log.levels
local uv = vim.uv

local M = {}

local ADAPTER_NAME = 'bashdb'
local NOTIFY_PREFIX = '[bash-debug] '

---@type string[]
local ROOT_MARKERS = {
  '.git',
  '.hg',
  '.jj',
  '.svn',
  'Justfile',
  'Makefile',
  'Taskfile.yaml',
  'Taskfile.yml',
}

---@class BashDebugAdapterSpec
---@field args string[]
---@field command string
---@field source string

---@param message string
---@param level? integer
local function notify(message, level)
  vim.notify(NOTIFY_PREFIX .. message, level or levels.INFO)
end

---@param value any
---@return string?
local function nonempty_string(value)
  if type(value) ~= 'string' or value == '' then
    return nil
  end

  return value
end

---@param path string
---@return boolean
local function exists(path)
  return uv.fs_stat(path) ~= nil
end

---@param path string
---@return boolean
local function is_directory(path)
  local stat = uv.fs_stat(path)

  return stat ~= nil and stat.type == 'directory'
end

---@param path string
---@return boolean
local function is_file(path)
  local stat = uv.fs_stat(path)

  return stat ~= nil and stat.type == 'file'
end

---@param command string
---@return boolean
local function is_executable(command)
  return command ~= '' and fn.executable(command) == 1
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
  if not is_executable(command) then
    return nil
  end

  local path = fn.exepath(command)

  if type(path) == 'string' and path ~= '' then
    return normalize(path)
  end

  return command
end

---@param bufnr? integer
---@return string
local function filename(bufnr)
  local target_bufnr = bufnr or api.nvim_get_current_buf()

  return normalize(api.nvim_buf_get_name(target_bufnr))
end

---@param start string
---@return string
local function detect_root(start)
  if start == '' then
    return normalize(fn.getcwd())
  end

  local detected = fs.root(start, ROOT_MARKERS)

  if type(detected) == 'string' and detected ~= '' then
    return normalize(detected)
  end

  local base = is_directory(start) and start or fs.dirname(start)

  if type(base) == 'string' and base ~= '' then
    return normalize(base)
  end

  return normalize(fn.getcwd())
end

---@param bufnr? integer
---@return string
local function root(bufnr)
  return detect_root(filename(bufnr))
end

---@param paths string[]
---@return string?
local function first_file(paths)
  for index = 1, #paths do
    local candidate = paths[index]

    if is_file(candidate) then
      return normalize(candidate)
    end
  end

  return nil
end

---@param paths string[]
---@return string?
local function first_directory(paths)
  for index = 1, #paths do
    local candidate = paths[index]

    if is_directory(candidate) then
      return normalize(candidate)
    end
  end

  return nil
end

---@param paths string[]
---@return string?
local function first_executable(paths)
  for index = 1, #paths do
    local candidate = paths[index]

    if is_executable(candidate) then
      local resolved = executable_path(candidate)

      if resolved ~= nil then
        return resolved
      end
    end
  end

  return nil
end

---@param pattern string
---@return string?
local function newest_file(pattern)
  local matches = fn.glob(pattern, false, true)

  if type(matches) ~= 'table' or #matches == 0 then
    return nil
  end

  table.sort(matches, function(left, right)
    return left > right
  end)

  for index = 1, #matches do
    local candidate = matches[index]

    if type(candidate) == 'string' and is_file(candidate) then
      return normalize(candidate)
    end
  end

  return nil
end

---@return string
local function mason_package_dir()
  return fs.joinpath(fn.stdpath('data'), 'mason', 'packages', 'bash-debug-adapter')
end

---@return string?
local function bash()
  local configured = nonempty_string(env.BASH_DEBUG_BASH)

  if configured ~= nil and is_executable(configured) then
    return executable_path(configured)
  end

  return executable_path('bash')
end

---@return string?
local function cat()
  return executable_path('cat')
end

---@return string?
local function mkfifo()
  return executable_path('mkfifo')
end

---@return string?
local function pkill()
  return executable_path('pkill')
end

---@return string?
local function node()
  local configured = nonempty_string(env.BASH_DEBUG_NODE)

  if configured ~= nil and is_executable(configured) then
    return executable_path(configured)
  end

  return executable_path('node')
end

---@return string?
local function adapter_javascript()
  local configured = nonempty_string(env.BASH_DEBUG_ADAPTER_JS)

  if configured ~= nil and is_file(configured) then
    return normalize(configured)
  end

  local home = nonempty_string(env.HOME) or fn.expand('~')
  local package_dir = mason_package_dir()

  local direct = first_file({
    fs.joinpath(package_dir, 'extension', 'out', 'bashDebug.js'),
    fs.joinpath(package_dir, 'out', 'bashDebug.js'),
    fs.joinpath(home, '.local', 'share', 'bash-debug-adapter', 'out', 'bashDebug.js'),
    fs.joinpath(home, '.local', 'src', 'vscode-bash-debug', 'out', 'bashDebug.js'),
  })

  if direct ~= nil then
    return direct
  end

  local globs = {
    fs.joinpath(home, '.vscode', 'extensions', 'rogalmic.bash-debug-*', 'out', 'bashDebug.js'),
    fs.joinpath(home, '.vscode-oss', 'extensions', 'rogalmic.bash-debug-*', 'out', 'bashDebug.js'),
    fs.joinpath(home, '.vscode-server', 'extensions', 'rogalmic.bash-debug-*', 'out', 'bashDebug.js'),
    fs.joinpath(home, '.local', 'share', 'code-server', 'extensions', 'rogalmic.bash-debug-*', 'out', 'bashDebug.js'),
  }

  for index = 1, #globs do
    local candidate = newest_file(globs[index])

    if candidate ~= nil then
      return candidate
    end
  end

  return nil
end

---@return BashDebugAdapterSpec?
local function adapter_spec()
  local configured = nonempty_string(env.BASH_DEBUG_ADAPTER)

  if configured ~= nil and is_executable(configured) then
    local command = executable_path(configured)

    if command ~= nil then
      return {
        args = {},
        command = command,
        source = 'BASH_DEBUG_ADAPTER',
      }
    end
  end

  local data = fn.stdpath('data')
  local wrapper = first_executable({
    fs.joinpath(data, 'mason', 'bin', 'bash-debug-adapter'),
    fs.joinpath(mason_package_dir(), 'bash-debug-adapter'),
    'bash-debug-adapter',
  })

  if wrapper ~= nil then
    return {
      args = {},
      command = wrapper,
      source = 'wrapper',
    }
  end

  local javascript = adapter_javascript()
  local node_command = node()

  if javascript ~= nil and node_command ~= nil then
    return {
      args = {
        javascript,
      },
      command = node_command,
      source = javascript,
    }
  end

  return nil
end

---@return string?
local function bundled_bashdb()
  local package_dir = mason_package_dir()
  local javascript = adapter_javascript()

  local candidates = {
    fs.joinpath(package_dir, 'extension', 'bashdb_dir', 'bashdb'),
    fs.joinpath(package_dir, 'bashdb_dir', 'bashdb'),
  }

  if javascript ~= nil then
    local out_dir = fs.dirname(javascript)
    local extension_dir = type(out_dir) == 'string' and fs.dirname(out_dir) or nil

    if type(extension_dir) == 'string' and extension_dir ~= '' then
      candidates[#candidates + 1] = fs.joinpath(extension_dir, 'bashdb_dir', 'bashdb')
    end
  end

  return first_file(candidates)
end

---@return string?
local function bashdb()
  local configured = nonempty_string(env.BASHDB)

  if configured ~= nil and exists(configured) then
    return normalize(configured)
  end

  local bundled = bundled_bashdb()

  if bundled ~= nil then
    return bundled
  end

  return executable_path('bashdb')
end

---@return string?
local function bashdb_lib()
  local configured = nonempty_string(env.BASHDB_LIB)

  if configured ~= nil and is_directory(configured) then
    return normalize(configured)
  end

  local debugger = bundled_bashdb()

  if debugger ~= nil then
    local directory = fs.dirname(debugger)

    if type(directory) == 'string' and is_directory(directory) and is_directory(fs.joinpath(directory, 'command')) then
      return normalize(directory)
    end
  end

  return first_directory({
    '/usr/share/bashdb',
    '/usr/local/share/bashdb',
  })
end

---@return boolean
local function current_buffer_is_modified()
  return api.nvim_get_option_value('modified', {
    buf = api.nvim_get_current_buf(),
  }) == true
end

---@param path string
---@return boolean
local function readable_file(path)
  return path ~= '' and fn.filereadable(path) == 1
end

---@param path string
---@return boolean
local function syntax_check(path)
  local shell = bash()

  if shell == nil then
    notify('bash is not available', levels.ERROR)

    return false
  end

  local directory = fs.dirname(path)
  local cwd = type(directory) == 'string' and directory ~= '' and normalize(directory) or root()

  local result = vim
    .system({
      shell,
      '-n',
      path,
    }, {
      cwd = cwd,
      text = true,
    })
    :wait()

  if result.code == 0 then
    return true
  end

  local detail = type(result.stderr) == 'string' and vim.trim(result.stderr) or ''

  if detail == '' then
    detail = type(result.stdout) == 'string' and vim.trim(result.stdout) or ''
  end

  if detail == '' then
    detail = string.format('bash -n exited with status %d', result.code)
  end

  notify(detail, levels.ERROR)

  return false
end

---@param path string
---@return string?
local function validate_program(path)
  if path == '' then
    notify('script path is empty', levels.ERROR)

    return nil
  end

  local program = normalize(path)

  if not readable_file(program) then
    notify('file is not readable: ' .. program, levels.ERROR)

    return nil
  end

  if not syntax_check(program) then
    return nil
  end

  return program
end

---@return string?
local function current_program()
  local program = filename()

  if program == '' then
    notify('current buffer has no file name', levels.ERROR)

    return nil
  end

  if current_buffer_is_modified() then
    notify('save the current buffer before debugging', levels.WARN)

    return nil
  end

  return validate_program(program)
end

---@return string?
local function pick_program()
  local workspace = root()

  local value = fn.input('Bash script: ', workspace .. '/', 'file')

  if type(value) ~= 'string' or value == '' then
    return nil
  end

  return validate_program(value)
end

---@param input string
---@return string[]?
local function split_arguments(input)
  ---@type string[]
  local arguments = {}

  ---@type string[]
  local current = {}

  local quote
  local escaped = false
  local started = false
  local index = 1

  while index <= #input do
    local character = input:sub(index, index)

    if escaped then
      current[#current + 1] = character
      escaped = false
      started = true
    elseif character == '\\' and quote ~= "'" then
      escaped = true
      started = true
    elseif quote ~= nil then
      if character == quote then
        quote = nil
      else
        current[#current + 1] = character
      end

      started = true
    elseif character == "'" or character == '"' then
      quote = character
      started = true
    elseif character:match('%s') ~= nil then
      if started then
        arguments[#arguments + 1] = table.concat(current)
        current = {}
        started = false
      end
    else
      current[#current + 1] = character
      started = true
    end

    index = index + 1
  end

  if escaped then
    current[#current + 1] = '\\'
  end

  if quote ~= nil then
    notify('unterminated quote in argument list', levels.ERROR)

    return nil
  end

  if started then
    arguments[#arguments + 1] = table.concat(current)
  end

  return arguments
end

---@return string[]
local function program_arguments()
  local input = fn.input('Arguments: ')

  if input == '' then
    return {}
  end

  return split_arguments(input) or {}
end

---@return table<string, string>
local function environment()
  local configured = nonempty_string(env.BASH_DEBUG_ENV)

  if configured == nil then
    return {}
  end

  local ok, decoded = pcall(json.decode, configured)

  if not ok or type(decoded) ~= 'table' then
    notify('BASH_DEBUG_ENV must be a JSON object', levels.WARN)

    return {}
  end

  ---@type table<string, string>
  local result = {}

  for key, value in pairs(decoded) do
    if type(key) == 'string' and type(value) == 'string' then
      result[key] = value
    end
  end

  return result
end

---@return string
local function terminal_kind()
  local configured = nonempty_string(env.BASH_DEBUG_TERMINAL)

  if configured == 'integrated' or configured == 'external' or configured == 'debugConsole' then
    return configured
  end

  return 'integrated'
end

---@return boolean
local function trace_enabled()
  local configured = nonempty_string(env.BASH_DEBUG_TRACE)

  if configured == nil then
    return false
  end

  configured = configured:lower()

  return configured == '1' or configured == 'true' or configured == 'yes' or configured == 'on'
end

---@return table
local function launch_defaults()
  return {
    args = program_arguments,
    cwd = root,
    env = environment,
    pathBash = bash() or '/usr/bin/bash',
    pathBashdb = bashdb(),
    pathBashdbLib = bashdb_lib(),
    pathCat = cat() or '/usr/bin/cat',
    pathMkfifo = mkfifo() or '/usr/bin/mkfifo',
    pathPkill = pkill() or '/usr/bin/pkill',
    request = 'launch',
    showDebugOutput = true,
    terminalKind = terminal_kind(),
    trace = trace_enabled(),
    type = ADAPTER_NAME,
  }
end

---@param program function
---@param name string
---@return table
local function launch_configuration(program, name)
  local config = launch_defaults()

  config.name = name
  config.program = program

  return config
end

---@return table<string, string>
local function dependency_status()
  local adapter = adapter_spec()
  local adapter_value = 'missing'

  if adapter ~= nil then
    adapter_value = adapter.command

    if #adapter.args > 0 then
      adapter_value = adapter_value .. ' ' .. table.concat(adapter.args, ' ')
    end
  end

  return {
    adapter = adapter_value,
    bash = bash() or 'missing',
    bashdb = bashdb() or 'missing',
    bashdb_lib = bashdb_lib() or 'missing',
    cat = cat() or 'missing',
    mkfifo = mkfifo() or 'missing',
    pkill = pkill() or 'missing',
  }
end

local initial_adapter = adapter_spec()

M.adapter = {
  args = initial_adapter ~= nil and initial_adapter.args or {},
  command = initial_adapter ~= nil and initial_adapter.command or 'bash-debug-adapter',
  name = ADAPTER_NAME,
  type = 'executable',
}

M.filetypes = {
  'bash',
  'sh',
}

M.configurations = {
  bash = {
    launch_configuration(current_program, 'Bash: Launch current file'),
    launch_configuration(pick_program, 'Bash: Launch selected script'),
  },

  sh = {
    launch_configuration(current_program, 'Bash: Launch current file'),
    launch_configuration(pick_program, 'Bash: Launch selected script'),
  },
}

M.commands = {
  BashDebugAdapter = {
    callback = function()
      local adapter = adapter_spec()

      if adapter == nil then
        notify('Bash DAP adapter is not available', levels.WARN)

        return
      end

      local value = adapter.command

      if #adapter.args > 0 then
        value = value .. ' ' .. table.concat(adapter.args, ' ')
      end

      notify(value)
    end,

    desc = 'Show Bash debug adapter command',
  },

  BashDebugCheck = {
    callback = function()
      local program = filename()

      if program == '' or not readable_file(program) then
        notify('current buffer is not a readable file', levels.ERROR)

        return
      end

      if current_buffer_is_modified() then
        notify('save the current buffer before checking', levels.WARN)

        return
      end

      if syntax_check(program) then
        notify('syntax check passed')
      end
    end,

    desc = 'Run bash syntax check on current file',
  },

  BashDebugDependencies = {
    callback = function()
      local status = dependency_status()

      notify(table.concat({
        'adapter: ' .. status.adapter,
        'bash: ' .. status.bash,
        'bashdb: ' .. status.bashdb,
        'bashdb lib: ' .. status.bashdb_lib,
        'cat: ' .. status.cat,
        'mkfifo: ' .. status.mkfifo,
        'pkill: ' .. status.pkill,
      }, '\n'))
    end,

    desc = 'Show Bash debugger dependency paths',
  },

  BashDebugProgram = {
    callback = function()
      local program = pick_program()

      if program ~= nil then
        notify(program)
      end
    end,

    desc = 'Select and validate Bash debug script',
  },

  BashDebugRoot = {
    callback = function()
      notify(root())
    end,

    desc = 'Show Bash debug project root',
  },
}

function M.setup()
  local adapter = adapter_spec()

  if adapter == nil then
    return
  end

  M.adapter.command = adapter.command
  M.adapter.args = adapter.args
end

return M
