-- #################################################################
-- ~/.config/nvim/lua/dap/mojo.lua
-- Qompass AI Diver Native Mojo Debug Adapter Configuration
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
---@source https://mojolang.org/docs/tools/debugging/
---@source https://mojolang.org/docs/cli/debug/
---@source https://mojolang.org/docs/cli/build/
---@source https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local levels = vim.log.levels
local uv = vim.uv

local M = {}

local SOURCE = 'mojo-dap'

---@type string[]
local ROOT_MARKERS = {
  'pixi.toml',
  'pixi.lock',
  'pyproject.toml',
  'uv.lock',
  '.python-version',
  'mojoproject.toml',
  '.git',
}

---@type string[]
local MOJO_LOCAL_CANDIDATES = {
  '.venv/bin/mojo',
  '.pixi/envs/default/bin/mojo',
  '.pixi/envs/dev/bin/mojo',
  'venv/bin/mojo',
}

---@class MojoDapState
---@field mojo string?
---@field lldb_dap string?
---@field executable string?
---@field root string?
local state = {
  executable = nil,
  lldb_dap = nil,
  mojo = nil,
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
local function is_directory(path)
  if not nonempty_string(path) then
    return false
  end

  local stat = uv.fs_stat(path)

  return stat ~= nil and stat.type == 'directory'
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

  local current = filename(bufnr)

  if current ~= '' then
    local detected = fs.root(current, ROOT_MARKERS)

    if type(detected) == 'string' and detected ~= '' then
      return fs.normalize(detected)
    end

    local parent = fs.dirname(current)

    if type(parent) == 'string' and parent ~= '' then
      return fs.normalize(parent)
    end
  end

  return fs.normalize(fn.getcwd())
end

---@param command string[]
---@param cwd? string
---@return vim.SystemCompleted?
local function system(command, cwd)
  local ok, result = pcall(function()
    return vim
      .system(command, {
        cwd = cwd,
        text = true,
      })
      :wait()
  end)

  if not ok then
    return nil
  end

  return result
end

---@param path string
---@return string?
local function command_version(path)
  if not executable(path) then
    return nil
  end

  local result = system({
    path,
    '--version',
  })

  if result == nil or result.code ~= 0 then
    return nil
  end

  local output = vim.trim(result.stdout or '')

  if output == '' then
    output = vim.trim(result.stderr or '')
  end

  if output == '' then
    return nil
  end

  return output:match('[^\r\n]+')
end

---@param root string
---@return string?
local function project_mojo(root)
  for _, relative in ipairs(MOJO_LOCAL_CANDIDATES) do
    local candidate = fs.joinpath(root, relative)

    if executable(candidate) then
      return fs.normalize(candidate)
    end
  end

  local pixi_envs = fs.joinpath(root, '.pixi', 'envs')

  if is_directory(pixi_envs) then
    for name, kind in fs.dir(pixi_envs) do
      if kind == 'directory' then
        local candidate = fs.joinpath(pixi_envs, name, 'bin', 'mojo')

        if executable(candidate) then
          return fs.normalize(candidate)
        end
      end
    end
  end

  return nil
end

---@return string?
local function resolve_mojo()
  local root = project_root()

  if state.root == root and state.mojo ~= nil and executable(state.mojo) then
    return state.mojo
  end

  local configured = vim.env.NVIM_MOJO_EXECUTABLE

  if nonempty_string(configured) then
    local candidate = normalize(fn.expand(configured))

    if executable(candidate) then
      state.root = root
      state.mojo = candidate

      return candidate
    end

    notify(('NVIM_MOJO_EXECUTABLE is not executable: %s'):format(candidate), levels.WARN)
  end

  local local_mojo = project_mojo(root)

  if local_mojo ~= nil then
    state.root = root
    state.mojo = local_mojo

    return local_mojo
  end

  local path_mojo = executable_path('mojo')

  if path_mojo ~= nil then
    state.root = root
    state.mojo = path_mojo

    return path_mojo
  end

  return nil
end

---@return string?
local function resolve_lldb_dap()
  if state.lldb_dap ~= nil and executable(state.lldb_dap) then
    return state.lldb_dap
  end

  local configured = vim.env.NVIM_MOJO_LLDB_DAP or vim.env.NVIM_LLDB_DAP

  if nonempty_string(configured) then
    local candidate = normalize(fn.expand(configured))

    if executable(candidate) then
      state.lldb_dap = candidate

      return candidate
    end

    notify(('configured lldb-dap is not executable: %s'):format(candidate), levels.WARN)
  end

  local candidate = executable_path('lldb-dap')

  if candidate ~= nil then
    state.lldb_dap = candidate

    return candidate
  end

  return nil
end

---@return boolean
local function cuda_gdb_available()
  return executable_path('cuda-gdb') ~= nil
end

---@return string
local function cwd()
  local root = project_root()

  state.root = root

  return root
end

---@return string[]
local function prompt_args()
  local input = fn.input('Mojo runtime arguments: ')

  if input == '' then
    return {}
  end

  return fn.shellsplit(input)
end

---@return table<string, string>
local function prompt_environment()
  local input = fn.input('Environment KEY=VALUE pairs: ')

  if input == '' then
    return {}
  end

  ---@type table<string, string>
  local result = {}

  for _, item in ipairs(fn.shellsplit(input)) do
    local key, value = item:match('^([%a_][%w_]*)=(.*)$')

    if key ~= nil then
      result[key] = value
    else
      notify(('ignoring invalid environment assignment: %s'):format(item), levels.WARN)
    end
  end

  return result
end

---@return integer
local function prompt_pid()
  local value = fn.input('Process ID: ')

  local pid = tonumber(value)

  if pid == nil or pid < 1 then
    notify(('invalid PID: %s'):format(value), levels.ERROR)

    return 0
  end

  return math.floor(pid)
end

---@return string
local function prompt_binary()
  local default = state.executable or project_root()

  local selected = fn.input('Mojo/native executable: ', default, 'file')

  if selected == '' then
    return ''
  end

  selected = normalize(fn.expand(selected))

  if not executable(selected) then
    notify(('not an executable: %s'):format(selected), levels.ERROR)

    return ''
  end

  state.executable = selected

  return selected
end

---@return string
local function build_directory()
  local directory = fs.joinpath(fn.stdpath('cache'), 'dap', 'mojo')

  fn.mkdir(directory, 'p', '0700')

  return fs.normalize(directory)
end

---@param source string
---@return string
local function debug_binary_path(source)
  local stem = fs.basename(source):gsub('%.mojo$', '')

  local hash = fn.sha256(source):sub(1, 12)

  return fs.joinpath(build_directory(), ('%s-%s'):format(stem, hash))
end

---@param extra_flags? string[]
---@return string?
local function build_current(extra_flags)
  local mojo = resolve_mojo()
  local source = filename()

  if mojo == nil then
    notify('Mojo executable was not found', levels.ERROR)

    return nil
  end

  if source == '' then
    notify('current buffer has no filename', levels.ERROR)

    return nil
  end

  if not source:lower():match('%.mojo$') then
    notify(('current file does not look like Mojo source: %s'):format(source), levels.ERROR)

    return nil
  end

  local output = debug_binary_path(source)

  ---@type string[]
  local command = {
    mojo,
    'build',
    '-O0',
    '-g',
    '-o',
    output,
  }

  if type(extra_flags) == 'table' and #extra_flags > 0 then
    vim.list_extend(command, extra_flags)
  end

  command[#command + 1] = source

  notify(('building debug executable: %s'):format(fs.basename(source)))

  local result = system(command, project_root())

  if result == nil then
    notify('failed to invoke mojo build', levels.ERROR)

    return nil
  end

  if result.code ~= 0 then
    local message = vim.trim(result.stderr or result.stdout or 'mojo build failed')

    notify(message ~= '' and message or 'mojo build failed', levels.ERROR)

    return nil
  end

  if not executable(output) then
    notify(('Mojo build completed but output is not executable: %s'):format(output), levels.ERROR)

    return nil
  end

  state.executable = fs.normalize(output)

  return state.executable
end

---@return string
local function build_then_program()
  return build_current() or ''
end

---@return string
local function build_then_program_with_asserts()
  return build_current({
    '-D',
    'ASSERT=all',
  }) or ''
end

---@return string[]
local function cli_compile_options()
  local input = fn.input('Mojo compiler/debug options: ', '-O0 -g')

  if input == '' then
    return {}
  end

  return fn.shellsplit(input)
end

---@param cuda boolean
---@param break_on_launch? boolean
local function open_mojo_debug_terminal(cuda, break_on_launch)
  local mojo = resolve_mojo()

  if mojo == nil then
    notify('Mojo executable was not found', levels.ERROR)

    return
  end

  if cuda and not cuda_gdb_available() then
    notify('cuda-gdb is not available in PATH', levels.ERROR)

    return
  end

  local source = filename()

  if source == '' then
    notify('current buffer has no filename', levels.ERROR)

    return
  end

  ---@type string[]
  local command = {
    mojo,
    'debug',
  }

  if cuda then
    command[#command + 1] = '--cuda-gdb'

    if break_on_launch then
      command[#command + 1] = '--break-on-launch'
    end
  end

  vim.list_extend(command, cli_compile_options())

  command[#command + 1] = source

  local runtime_args = prompt_args()

  vim.list_extend(command, runtime_args)

  vim.cmd('botright new')

  local buffer = api.nvim_get_current_buf()

  vim.bo[buffer].bufhidden = 'wipe'

  local job = fn.jobstart(command, {
    cwd = project_root(),

    term = true,

    on_exit = function(_, code)
      vim.schedule(function()
        notify(('mojo debug exited with status %d'):format(code), code == 0 and levels.INFO or levels.WARN)
      end)
    end,
  })

  if job <= 0 then
    notify('failed to start mojo debug terminal', levels.ERROR)

    return
  end

  vim.cmd('startinsert')
end

local function debug_cpu_cli()
  open_mojo_debug_terminal(false, false)
end

local function debug_cuda_cli()
  open_mojo_debug_terminal(true, false)
end

local function debug_cuda_break_cli()
  open_mojo_debug_terminal(true, true)
end

local function select_mojo()
  local selected = fn.input('Mojo executable: ', resolve_mojo() or '', 'file')

  if selected == '' then
    return
  end

  selected = normalize(fn.expand(selected))

  if not executable(selected) then
    notify(('not executable: %s'):format(selected), levels.ERROR)

    return
  end

  state.root = project_root()
  state.mojo = selected

  notify(('Mojo executable: %s'):format(selected))
end

local function select_lldb_dap()
  local selected = fn.input('lldb-dap executable: ', resolve_lldb_dap() or '', 'file')

  if selected == '' then
    return
  end

  selected = normalize(fn.expand(selected))

  if not executable(selected) then
    notify(('not executable: %s'):format(selected), levels.ERROR)

    return
  end

  state.lldb_dap = selected

  if type(M.adapter) == 'table' then
    M.adapter.command = selected
  end

  notify(('lldb-dap: %s'):format(selected))
end

local function clear_cache()
  state.executable = nil
  state.lldb_dap = nil
  state.mojo = nil
  state.root = nil

  notify('Mojo DAP discovery cache cleared')
end

local function status()
  local mojo = resolve_mojo()
  local lldb = resolve_lldb_dap()
  local cuda_gdb = executable_path('cuda-gdb')

  notify(table.concat({
    'root: ' .. project_root(),

    'Mojo: ' .. (mojo or 'not found'),

    'Mojo version: ' .. (mojo ~= nil and (command_version(mojo) or 'unknown') or 'unknown'),

    'lldb-dap: ' .. (lldb or 'not found'),

    'cuda-gdb: ' .. (cuda_gdb or 'not found'),

    'native DAP: ' .. (lldb ~= nil and 'available' or 'unavailable'),

    'Mojo CPU CLI debugger: ' .. (mojo ~= nil and 'available' or 'unavailable'),

    'Mojo NVIDIA GPU debugger: ' .. (mojo ~= nil and cuda_gdb ~= nil and 'available' or 'unavailable'),

    'cached debug executable: ' .. (state.executable or 'none'),
  }, '\n'))
end

--
---@type table
M.adapter = {
  name = 'mojo-native-lldb',

  type = 'executable',

  command = resolve_lldb_dap() or 'lldb-dap',

  options = {
    source_filetype = 'mojo',
  },
}

---@type table[]
local configurations = {
  {
    name = 'Mojo: Build Debug + Launch',

    type = 'mojo-native-lldb',

    request = 'launch',

    program = build_then_program,

    cwd = cwd,

    args = {},

    env = {},

    stopOnEntry = false,

    runInTerminal = true,
  },

  {
    name = 'Mojo: Build Debug + Launch with Arguments',

    type = 'mojo-native-lldb',

    request = 'launch',

    program = build_then_program,

    cwd = cwd,

    args = prompt_args,

    env = prompt_environment,

    stopOnEntry = false,

    runInTerminal = true,
  },

  {
    name = 'Mojo: Build Debug + Assertions + Launch',

    type = 'mojo-native-lldb',

    request = 'launch',

    program = build_then_program_with_asserts,

    cwd = cwd,

    args = prompt_args,

    env = prompt_environment,

    stopOnEntry = false,

    runInTerminal = true,
  },

  {
    name = 'Mojo: Build Debug + Stop on Entry',

    type = 'mojo-native-lldb',

    request = 'launch',

    program = build_then_program,

    cwd = cwd,

    args = {},

    stopOnEntry = true,

    runInTerminal = true,
  },

  {
    name = 'Mojo: Debug Existing Binary',

    type = 'mojo-native-lldb',

    request = 'launch',

    program = prompt_binary,

    cwd = cwd,

    args = prompt_args,

    env = prompt_environment,

    stopOnEntry = false,

    runInTerminal = true,
  },

  {
    name = 'Mojo: Attach PID with LLDB DAP',

    type = 'mojo-native-lldb',

    request = 'attach',

    pid = prompt_pid,
  },
}

---@type table<string, table[]>
M.configurations = {
  mojo = configurations,
}

---@type table<string, DebugCommand>
M.commands = {
  MojoDebugBuild = {
    callback = function()
      local output = build_current()

      if output ~= nil then
        notify(('debug executable: %s'):format(output))
      end
    end,

    desc = 'Build current Mojo file with -O0 -g',
  },

  MojoDebugClear = {
    callback = function()
      clear_cache()
    end,

    desc = 'Clear Mojo debugger discovery cache',
  },

  MojoDebugCpuCli = {
    callback = function()
      debug_cpu_cli()
    end,

    desc = 'Debug current Mojo file with official Mojo LLDB CLI',
  },

  MojoDebugCudaCli = {
    callback = function()
      debug_cuda_cli()
    end,

    desc = 'Debug current Mojo file with CUDA-GDB',
  },

  MojoDebugCudaBreak = {
    callback = function()
      debug_cuda_break_cli()
    end,

    desc = 'Debug Mojo GPU and break on kernel launch',
  },

  MojoDebugLldbDap = {
    callback = function()
      select_lldb_dap()
    end,

    desc = 'Select LLDB DAP executable',
  },

  MojoDebugMojo = {
    callback = function()
      select_mojo()
    end,

    desc = 'Select Mojo executable',
  },

  MojoDebugStatus = {
    callback = function()
      status()
    end,

    desc = 'Show Mojo debugger status',
  },
}

---@type table<string, DebugMapping>
M.mappings = {
  mojo_debug_build = {
    lhs = '<leader>dMb',

    mode = 'n',

    rhs = function()
      build_current()
    end,

    desc = 'Debug Mojo: Build',
  },

  mojo_debug_cpu = {
    lhs = '<leader>dMc',

    mode = 'n',

    rhs = function()
      debug_cpu_cli()
    end,

    desc = 'Debug Mojo: Official CPU debugger',
  },

  mojo_debug_cuda = {
    lhs = '<leader>dMg',

    mode = 'n',

    rhs = function()
      debug_cuda_cli()
    end,

    desc = 'Debug Mojo: CUDA-GDB',
  },

  mojo_debug_cuda_break = {
    lhs = '<leader>dMK',

    mode = 'n',

    rhs = function()
      debug_cuda_break_cli()
    end,

    desc = 'Debug Mojo: CUDA break on kernel',
  },

  mojo_debug_status = {
    lhs = '<leader>dMs',

    mode = 'n',

    rhs = function()
      status()
    end,

    desc = 'Debug Mojo: Status',
  },

  mojo_debug_toolchain = {
    lhs = '<leader>dMt',

    mode = 'n',

    rhs = function()
      select_mojo()
    end,

    desc = 'Debug Mojo: Select toolchain',
  },
}

---@param opts? table
function M.setup(opts)
  opts = opts or {}

  state.root = nonempty_string(opts.root) and fs.normalize(opts.root) or project_root()

  local mojo = resolve_mojo()
  local lldb = resolve_lldb_dap()

  if lldb ~= nil then
    M.adapter.command = lldb
  end

  if mojo == nil then
    vim.schedule(function()
      notify(
        table.concat({
          'Mojo executable was not found.',
          '',
          'Resolution order:',
          '  NVIM_MOJO_EXECUTABLE',
          '  project .venv/bin/mojo',
          '  project .pixi/envs/*/bin/mojo',
          '  project venv/bin/mojo',
          '  PATH mojo',
        }, '\n'),
        levels.WARN
      )
    end)
  end

  if lldb == nil then
    vim.schedule(function()
      notify(
        table.concat({
          'lldb-dap was not found.',
          '',
          'Native DAP debugging of precompiled Mojo binaries',
          'requires LLVM lldb-dap.',
          '',
          'Set:',
          '  NVIM_MOJO_LLDB_DAP=/path/to/lldb-dap',
        }, '\n'),
        levels.WARN
      )
    end)
  end
end

---@return string?
function M.mojo()
  return resolve_mojo()
end

---@return string?
function M.lldb_dap()
  return resolve_lldb_dap()
end

---@return string
function M.root()
  return project_root()
end

---@return boolean
function M.dap_available()
  return resolve_lldb_dap() ~= nil
end

---@return boolean
function M.cuda_debug_available()
  return resolve_mojo() ~= nil and cuda_gdb_available()
end

return M