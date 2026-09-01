-- #################################################################
-- ~/.config/nvim/lua/dap/rust.lua
-- Native Rust Debug Adapter Configuration
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
---@source https://lldb.llvm.org/use/lldbdap.html

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local levels = vim.log.levels
local uv = vim.uv

local M = {}

local ADAPTER_NAME = 'lldb-dap'

---@type string[]
local ROOT_MARKERS = {
  'Cargo.toml',
  'rust-project.json',
  '.git',
}

---@param path string
---@return boolean
local function exists(path)
  return uv.fs_stat(path) ~= nil
end

---@param command string
---@return boolean
local function is_executable(command)
  return fn.executable(command) == 1
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
  local target_bufnr = bufnr or api.nvim_get_current_buf()

  return normalize(api.nvim_buf_get_name(target_bufnr))
end

---@param bufnr? integer
---@return string
local function root(bufnr)
  local current = filename(bufnr)

  if current == '' then
    return normalize(fn.getcwd())
  end

  local detected = fs.root(current, ROOT_MARKERS)

  if type(detected) == 'string' and detected ~= '' then
    return normalize(detected)
  end

  local parent = fs.dirname(current)

  if type(parent) == 'string' and parent ~= '' then
    return normalize(parent)
  end

  return normalize(fn.getcwd())
end

---@return string?
local function lldb_dap()
  local candidates = {
    'lldb-dap',
    'lldb-vscode',
  }

  for index = 1, #candidates do
    local candidate = candidates[index]

    if is_executable(candidate) then
      return candidate
    end
  end

  return nil
end

---@return string?
local function cargo()
  if is_executable('cargo') then
    return 'cargo'
  end

  return nil
end

---@return string?
local function rustc()
  if is_executable('rustc') then
    return 'rustc'
  end

  return nil
end

---@return string?
local function rustc_sysroot()
  local command = rustc()

  if command == nil then
    return nil
  end

  local result = vim
    .system({
      command,
      '--print',
      'sysroot',
    }, {
      text = true,
    })
    :wait()

  if result.code ~= 0 or type(result.stdout) ~= 'string' then
    return nil
  end

  local value = vim.trim(result.stdout)

  if value == '' then
    return nil
  end

  return normalize(value)
end

---@return string[]
local function rust_lldb_commands()
  local sysroot = rustc_sysroot()

  if sysroot == nil then
    return {}
  end

  local lookup = fs.joinpath(sysroot, 'lib', 'rustlib', 'etc', 'lldb_lookup.py')

  local command_file = fs.joinpath(sysroot, 'lib', 'rustlib', 'etc', 'lldb_commands')

  ---@type string[]
  local result = {}

  if exists(lookup) then
    result[#result + 1] = string.format('command script import %q', lookup)
  end

  if not exists(command_file) then
    return result
  end

  local file = io.open(command_file, 'r')

  if file == nil then
    return result
  end

  for line in file:lines() do
    if line ~= '' and not line:match('^%s*#') then
      result[#result + 1] = line
    end
  end

  file:close()

  return result
end

---@param prompt string
---@param default? string
---@return string?
local function input_path(prompt, default)
  local value = fn.input(prompt, default or '', 'file')

  if type(value) ~= 'string' or value == '' then
    return nil
  end

  return normalize(value)
end

---@param workspace string
---@return string
local function default_target_dir(workspace)
  local target = fs.joinpath(workspace, 'target', 'debug')

  if exists(target) then
    return target
  end

  return workspace
end

---@return string?
local function pick_program()
  local workspace = root()

  return input_path('Rust executable: ', default_target_dir(workspace) .. '/')
end

---@return integer?
local function pick_pid()
  local value = fn.input('PID: ')

  if value == '' then
    return nil
  end

  local parsed = tonumber(value)

  if parsed == nil then
    return nil
  end

  local pid = math.floor(parsed)

  if pid <= 0 then
    return nil
  end

  return pid
end

---@param workspace string
---@return string?
local function cargo_manifest(workspace)
  local manifest = fs.joinpath(workspace, 'Cargo.toml')

  if exists(manifest) then
    return manifest
  end

  return nil
end

---@param output string
---@return string?
local function parse_cargo_executable(output)
  local executable_path

  for line in output:gmatch('[^\r\n]+') do
    local ok, decoded = pcall(vim.json.decode, line)

    if
      ok
      and type(decoded) == 'table'
      and decoded.reason == 'compiler-artifact'
      and type(decoded.executable) == 'string'
      and decoded.executable ~= ''
    then
      executable_path = decoded.executable
    end
  end

  if executable_path == nil then
    return nil
  end

  return normalize(executable_path)
end

---@return string?
local function build_debug_target()
  local cargo_executable = cargo()

  if cargo_executable == nil then
    vim.notify('[debug] cargo is not available', levels.ERROR)

    return nil
  end

  local workspace = root()

  local argv = {
    cargo_executable,
    'build',
    '--message-format=json',
  }

  local manifest = cargo_manifest(workspace)

  if manifest ~= nil then
    argv[#argv + 1] = '--manifest-path'

    argv[#argv + 1] = manifest
  end

  local result = vim
    .system(argv, {
      cwd = workspace,
      text = true,
    })
    :wait()

  if result.code ~= 0 then
    local stderr = type(result.stderr) == 'string' and vim.trim(result.stderr) or ''

    if stderr ~= '' then
      vim.notify(string.format('[debug] cargo build failed: %s', stderr), levels.ERROR)
    else
      vim.notify('[debug] cargo build failed', levels.ERROR)
    end

    return nil
  end

  if type(result.stdout) ~= 'string' or result.stdout == '' then
    return nil
  end

  return parse_cargo_executable(result.stdout)
end

---@return table<string, string>
local function environment()
  ---@type table<string, string>
  local result = {}

  local rust_backtrace = vim.env.RUST_BACKTRACE

  if type(rust_backtrace) == 'string' and rust_backtrace ~= '' then
    result.RUST_BACKTRACE = rust_backtrace
  else
    result.RUST_BACKTRACE = '1'
  end

  local rust_log = vim.env.RUST_LOG

  if type(rust_log) == 'string' and rust_log ~= '' then
    result.RUST_LOG = rust_log
  end

  return result
end

---@return string[]
local function program_arguments()
  local input = fn.input('Arguments: ')

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

---@return string?
local function core_file()
  return input_path('Core file: ', root() .. '/')
end

---@return integer?
local function remote_port()
  local value = fn.input('GDB remote port: ', '1234')

  if value == '' then
    return nil
  end

  local parsed = tonumber(value)

  if parsed == nil then
    return nil
  end

  local port = math.floor(parsed)

  if port < 1 or port > 65535 then
    return nil
  end

  return port
end

---@return string
local function remote_host()
  local value = fn.input('GDB remote host: ', '127.0.0.1')

  if value == '' then
    return '127.0.0.1'
  end

  return value
end

M.adapter = {
  command = lldb_dap() or 'lldb-dap',

  name = ADAPTER_NAME,

  type = 'executable',
}

M.filetypes = {
  'rust',
}

M.configurations = {
  rust = {
    {
      args = program_arguments,

      console = 'integratedTerminal',

      cwd = root,

      env = environment,

      initCommands = rust_lldb_commands,

      name = 'Rust: Cargo build + launch',

      program = build_debug_target,

      request = 'launch',

      stopOnEntry = false,

      type = ADAPTER_NAME,
    },

    {
      args = program_arguments,

      console = 'integratedTerminal',

      cwd = root,

      env = environment,

      initCommands = rust_lldb_commands,

      name = 'Rust: Launch executable',

      program = pick_program,

      request = 'launch',

      stopOnEntry = false,

      type = ADAPTER_NAME,
    },

    {
      cwd = root,

      initCommands = rust_lldb_commands,

      name = 'Rust: Attach to PID',

      pid = pick_pid,

      program = pick_program,

      request = 'attach',

      type = ADAPTER_NAME,
    },

    {
      cwd = root,

      initCommands = rust_lldb_commands,

      name = 'Rust: Attach by executable',

      program = pick_program,

      request = 'attach',

      type = ADAPTER_NAME,

      waitFor = true,
    },

    {
      coreFile = core_file,

      cwd = root,

      initCommands = rust_lldb_commands,

      name = 'Rust: Open core dump',

      program = pick_program,

      request = 'attach',

      type = ADAPTER_NAME,
    },

    {
      cwd = root,

      ['gdb-remote-host'] = remote_host,

      ['gdb-remote-port'] = remote_port,

      initCommands = rust_lldb_commands,

      name = 'Rust: GDB remote',

      program = pick_program,

      request = 'attach',

      type = ADAPTER_NAME,
    },
  },
}

M.commands = {
  RustDebugBuild = {
    callback = function()
      local program = build_debug_target()

      if program == nil then
        return
      end

      vim.notify(string.format('[debug] built %s', program), levels.INFO)
    end,

    desc = 'Build Rust debug target',
  },

  RustDebugProgram = {
    callback = function()
      local program = pick_program()

      if program == nil then
        return
      end

      vim.notify(program, levels.INFO)
    end,

    desc = 'Select Rust debug executable',
  },

  RustDebugSysroot = {
    callback = function()
      local sysroot = rustc_sysroot()

      if sysroot == nil then
        vim.notify('[debug] Rust sysroot unavailable', levels.WARN)

        return
      end

      vim.notify(sysroot, levels.INFO)
    end,

    desc = 'Show Rust compiler sysroot',
  },
}

function M.setup()
  local adapter = lldb_dap()

  if adapter == nil then
    vim.notify('[debug] lldb-dap is not installed', levels.WARN)

    return
  end

  M.adapter.command = adapter
end

return M
