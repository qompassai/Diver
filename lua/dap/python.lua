-- #################################################################
-- ~/.config/nvim/lua/dap/python.lua
-- Qompass AI Diver Native Python Debug Adapter Configuration
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
---@source https://github.com/microsoft/debugpy
---@source https://github.com/microsoft/debugpy/wiki/Debug-configuration-settings
---@source https://github.com/microsoft/debugpy/wiki/Command-Line-Reference

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local levels = vim.log.levels

local M = {}

local SOURCE = 'python-dap'
local DEFAULT_ATTACH_HOST = '127.0.0.1'
local DEFAULT_ATTACH_PORT = 5678

---@type string[]
local ROOT_MARKERS = {
  'pyproject.toml',
  'uv.lock',
  'poetry.lock',
  'Pipfile',
  'requirements.txt',
  'setup.py',
  'setup.cfg',
  'tox.ini',
  '.python-version',
  '.git',
}

---@type string[]
local VENV_DIRECTORIES = {
  '.venv',
  'venv',
  '.env',
  'env',
}

---@type string[]
local PYTHON_EXECUTABLES = {
  'python3',
  'python',
}

---@class PythonDapState
---@field interpreter string?
---@field adapter_interpreter string?
---@field root string?
local state = {
  adapter_interpreter = nil,
  interpreter = nil,
  root = nil,
}

---@param message string
---@param level? integer
local function notify(message, level)
  vim.notify(('[%s] %s'):format(SOURCE, message), level or levels.INFO)
end

---@param value unknown
---@return boolean
local function nonempty_string(value)
  return type(value) == 'string' and value ~= ''
end

---@param path string
---@return boolean
local function executable(path)
  return nonempty_string(path) and fn.executable(path) == 1
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
local function buffer_filename(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()

  if not api.nvim_buf_is_valid(bufnr) then
    return ''
  end

  local name = api.nvim_buf_get_name(bufnr)

  if name == '' then
    return ''
  end

  return normalize(name)
end

---@param bufnr? integer
---@return string
local function project_root(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()

  local filename = buffer_filename(bufnr)

  if filename ~= '' then
    local detected = fs.root(filename, ROOT_MARKERS)

    if type(detected) == 'string' and detected ~= '' then
      return fs.normalize(detected)
    end

    local parent = fs.dirname(filename)

    if type(parent) == 'string' and parent ~= '' then
      return fs.normalize(parent)
    end
  end

  return fs.normalize(fn.getcwd())
end

---@param path string
---@return string
local function venv_python(path)
  return fs.joinpath(path, 'bin', 'python')
end

---@param root string
---@return string?
local function project_venv_python(root)
  for _, directory in ipairs(VENV_DIRECTORIES) do
    local candidate = venv_python(fs.joinpath(root, directory))

    if executable(candidate) then
      return fs.normalize(candidate)
    end
  end

  return nil
end

---@return string?
local function environment_python()
  local virtual_env = vim.env.VIRTUAL_ENV

  if nonempty_string(virtual_env) then
    local candidate = venv_python(virtual_env)

    if executable(candidate) then
      return fs.normalize(candidate)
    end
  end

  local conda_prefix = vim.env.CONDA_PREFIX

  if nonempty_string(conda_prefix) then
    local candidate = venv_python(conda_prefix)

    if executable(candidate) then
      return fs.normalize(candidate)
    end
  end

  return nil
end

---@return string?
local function path_python()
  for _, command in ipairs(PYTHON_EXECUTABLES) do
    local candidate = fn.exepath(command)

    if nonempty_string(candidate) and executable(candidate) then
      return fs.normalize(candidate)
    end
  end

  return nil
end

---@param root? string
---@return string?
local function resolve_project_python(root)
  root = root or project_root()

  --
  -- Explicit override always wins.
  --
  local configured = vim.env.NVIM_PYTHON_DEBUG_INTERPRETER

  if nonempty_string(configured) then
    local expanded = normalize(fn.expand(configured))

    if executable(expanded) then
      return expanded
    end

    notify(('NVIM_PYTHON_DEBUG_INTERPRETER is not executable: %s'):format(expanded), levels.WARN)
  end

  --
  -- Prefer an activated virtual environment because this most closely
  -- represents the shell from which Neovim was launched.
  --
  local activated = environment_python()

  if activated ~= nil then
    return activated
  end

  --
  -- Then prefer a project-local environment.
  --
  local local_venv = project_venv_python(root)

  if local_venv ~= nil then
    return local_venv
  end

  return path_python()
end

---@param command string[]
---@return vim.SystemCompleted?
local function system(command)
  local ok, result = pcall(function()
    return vim
      .system(command, {
        text = true,
      })
      :wait()
  end)

  if not ok then
    return nil
  end

  return result
end

---@param python string
---@return boolean
local function has_debugpy(python)
  if not executable(python) then
    return false
  end

  local result = system({
    python,
    '-c',
    'import debugpy',
  })

  return result ~= nil and result.code == 0
end

---@return string?
local function resolve_adapter_python()
  if state.adapter_interpreter ~= nil then
    return state.adapter_interpreter
  end

  --
  -- An explicit adapter interpreter is intentionally separate from the
  -- interpreter used by the program being debugged.
  --
  local configured = vim.env.NVIM_DEBUGPY_PYTHON

  if nonempty_string(configured) then
    local candidate = normalize(fn.expand(configured))

    if executable(candidate) and has_debugpy(candidate) then
      state.adapter_interpreter = candidate

      return candidate
    end

    notify(('NVIM_DEBUGPY_PYTHON does not provide debugpy: %s'):format(candidate), levels.WARN)
  end

  --
  -- First try the current/project interpreter. This keeps configuration
  -- simple when debugpy is installed in the project's development venv.
  --
  local project_python = resolve_project_python()

  if project_python ~= nil and has_debugpy(project_python) then
    state.adapter_interpreter = project_python

    return project_python
  end

  --
  -- Then inspect the normal PATH interpreters.
  --
  for _, command in ipairs(PYTHON_EXECUTABLES) do
    local candidate = fn.exepath(command)

    if nonempty_string(candidate) and executable(candidate) and has_debugpy(candidate) then
      candidate = fs.normalize(candidate)

      state.adapter_interpreter = candidate

      return candidate
    end
  end

  return nil
end

---@return string
local function adapter_python()
  local python = resolve_adapter_python()

  if python ~= nil then
    return python
  end

  --
  -- Keep the adapter structurally valid even when debugpy is missing.
  -- setup() produces a useful warning before a session is attempted.
  --
  return fn.exepath('python3') ~= '' and fn.exepath('python3') or 'python3'
end

---@return string
local function debuggee_python()
  local root = project_root()

  if state.interpreter ~= nil and state.root == root and executable(state.interpreter) then
    return state.interpreter
  end

  local python = resolve_project_python(root)

  if python == nil then
    return 'python3'
  end

  state.interpreter = python
  state.root = root

  return python
end

---@return string[]
local function debuggee_python_command()
  return {
    debuggee_python(),
  }
end

---@return string
local function debug_cwd()
  return project_root()
end

---@return string
local function current_file()
  local filename = buffer_filename()

  if filename ~= '' then
    return filename
  end

  return '${file}'
end

---@return string[]
local function prompt_args()
  local input = fn.input('Python arguments: ')

  if input == '' then
    return {}
  end

  --
  -- shellsplit handles quoted arguments but does not execute a shell.
  --
  return fn.shellsplit(input)
end

---@return string
local function prompt_module()
  return fn.input('Python module: ', '', 'file')
end

---@return integer?
local function prompt_port()
  local value = fn.input('debugpy port: ', tostring(DEFAULT_ATTACH_PORT))

  if value == '' then
    return nil
  end

  local port = tonumber(value)

  if port == nil or port < 1 or port > 65535 then
    notify(('invalid TCP port: %s'):format(value), levels.ERROR)

    return nil
  end

  return math.floor(port)
end

---@return string?
local function select_python()
  local root = project_root()

  local default = resolve_project_python(root) or fn.exepath('python3') or ''

  local selected = fn.input('Python interpreter: ', default, 'file')

  if selected == '' then
    return nil
  end

  selected = normalize(fn.expand(selected))

  if not executable(selected) then
    notify(('not an executable Python interpreter: %s'):format(selected), levels.ERROR)

    return nil
  end

  state.interpreter = selected
  state.root = root

  notify(('debug interpreter: %s'):format(selected))

  return selected
end

local function clear_selected_python()
  state.interpreter = nil
  state.root = nil

  notify('project interpreter selection cleared')
end

local function show_interpreter()
  local root = project_root()
  local debuggee = debuggee_python()
  local adapter = resolve_adapter_python()

  notify(table.concat({
    'root: ' .. root,
    'debuggee: ' .. debuggee,
    'adapter: ' .. (adapter or 'debugpy unavailable'),
  }, '\n'))
end

local function check_health()
  local python = resolve_project_python()
  local adapter = resolve_adapter_python()

  local messages = {
    'Python DAP',
    '',
    'project root: ' .. project_root(),
    'debuggee interpreter: ' .. (python or 'not found'),
    'debugpy interpreter: ' .. (adapter or 'not found'),
  }

  if adapter == nil then
    messages[#messages + 1] = ''
    messages[#messages + 1] = 'debugpy is required by the native Python DAP adapter'
  end

  notify(table.concat(messages, '\n'), adapter ~= nil and levels.INFO or levels.WARN)
end

--
-- debugpy's adapter process communicates with the DAP client over
-- stdin/stdout when launched with:
--
--   python -m debugpy.adapter
--
-- The debuggee's interpreter is configured separately in each launch
-- configuration.
--
---@type table
M.adapter = {
  name = 'debugpy',

  type = 'executable',

  command = adapter_python(),

  args = {
    '-m',
    'debugpy.adapter',
  },

  options = {
    source_filetype = 'python',
  },
}

---@type table<string, table[]>
M.configurations = {
  python = {
    {
      name = 'Python: Current File',

      type = 'debugpy',

      request = 'launch',

      program = current_file,

      cwd = debug_cwd,

      python = debuggee_python_command,

      console = 'integratedTerminal',

      justMyCode = true,

      redirectOutput = true,

      subProcess = true,
    },

    {
      name = 'Python: Current File with Arguments',

      type = 'debugpy',

      request = 'launch',

      program = current_file,

      cwd = debug_cwd,

      python = debuggee_python_command,

      args = prompt_args,

      console = 'integratedTerminal',

      justMyCode = true,

      redirectOutput = true,

      subProcess = true,
    },

    {
      name = 'Python: Module',

      type = 'debugpy',

      request = 'launch',

      module = prompt_module,

      cwd = debug_cwd,

      python = debuggee_python_command,

      console = 'integratedTerminal',

      justMyCode = true,

      redirectOutput = true,

      subProcess = true,
    },

    {
      name = 'Python: pytest Current File',

      type = 'debugpy',

      request = 'launch',

      module = 'pytest',

      args = {
        current_file,
        '-vv',
        '-s',
      },

      cwd = debug_cwd,

      python = debuggee_python_command,

      console = 'integratedTerminal',

      justMyCode = false,

      redirectOutput = true,

      subProcess = true,
    },

    {
      name = 'Python: pytest Current File - Stop First Failure',

      type = 'debugpy',

      request = 'launch',

      module = 'pytest',

      args = {
        current_file,
        '-vv',
        '-s',
        '-x',
      },

      cwd = debug_cwd,

      python = debuggee_python_command,

      console = 'integratedTerminal',

      justMyCode = false,

      redirectOutput = true,

      subProcess = true,
    },

    {
      name = 'Python: Attach localhost:5678',

      type = 'debugpy',

      request = 'attach',

      connect = {
        host = DEFAULT_ATTACH_HOST,
        port = DEFAULT_ATTACH_PORT,
      },

      justMyCode = false,
    },

    {
      name = 'Python: Attach localhost (Choose Port)',

      type = 'debugpy',

      request = 'attach',

      connect = {
        host = DEFAULT_ATTACH_HOST,
        port = prompt_port,
      },

      justMyCode = false,
    },
  },
}

---@type table<string, DebugCommand>
M.commands = {
  PythonDebugCheck = {
    callback = function()
      check_health()
    end,

    desc = 'Check Python debug adapter configuration',
  },

  PythonDebugInterpreter = {
    callback = function()
      select_python()
    end,

    desc = 'Select Python debug interpreter',
  },

  PythonDebugInterpreterClear = {
    callback = function()
      clear_selected_python()
    end,

    desc = 'Clear selected Python debug interpreter',
  },

  PythonDebugInterpreterShow = {
    callback = function()
      show_interpreter()
    end,

    desc = 'Show Python debug interpreters',
  },
}

---@type table<string, DebugMapping>
M.mappings = {
  python_debug_check = {
    lhs = '<leader>dPc',

    mode = 'n',

    rhs = function()
      check_health()
    end,

    desc = 'Debug Python: Check configuration',
  },

  python_debug_interpreter = {
    lhs = '<leader>dPi',

    mode = 'n',

    rhs = function()
      select_python()
    end,

    desc = 'Debug Python: Select interpreter',
  },

  python_debug_interpreter_show = {
    lhs = '<leader>dPs',

    mode = 'n',

    rhs = function()
      show_interpreter()
    end,

    desc = 'Debug Python: Show interpreter',
  },
}

---@param opts? table
function M.setup(opts)
  opts = opts or {}

  local adapter = resolve_adapter_python()

  if adapter == nil then
    vim.schedule(function()
      notify(
        table.concat({
          'debugpy was not found.',
          '',
          'Install debugpy into a Python interpreter or set:',
          'NVIM_DEBUGPY_PYTHON=/path/to/python',
        }, '\n'),
        levels.WARN
      )
    end)

    return
  end

  --
  -- Adapter resolution happens once at module load. Keep the adapter command
  -- synchronized in case setup() discovered a more specific interpreter.
  --
  M.adapter.command = adapter

  local root

  if nonempty_string(opts.root) then
    root = fs.normalize(opts.root)
  else
    root = project_root()
  end

  state.root = root

  local python = resolve_project_python(root)

  if python ~= nil then
    state.interpreter = python
  end
end

---@return string?
function M.interpreter()
  return resolve_project_python()
end

---@return string?
function M.adapter_interpreter()
  return resolve_adapter_python()
end

---@return string
function M.root()
  return project_root()
end

return M