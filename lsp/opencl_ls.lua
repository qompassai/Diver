-- #################################################################
-- /qompassai/Diver/lsp/opencl_ls.lua
-- Qompass AI Diver Native OpenCL Language Server Configuration
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
---@source https://github.com/Galarius/opencl-language-server
---@source https://neovim.io/doc/user/lsp/
---@source https://neovim.io/doc/user/lua/
--
-- Installation (Arch Linux):
--
-- sudo pacman -S --needed clinfo ocl-icd opencl-headers
--
-- Install precisely one OpenCL ICD/runtime appropriate to the host hardware.
-- For CPU-only fallback diagnostics, install `pocl`:
--
-- sudo pacman -S --needed pocl
--
-- Verify that the ICD loader can enumerate a usable device:
--
-- clinfo -l
--

--
-- Optional environment override:
--
-- NVIM_OPENCL_LS_LOG=1
--
-- When enabled, server file logging is written to:
--
--   vim.fn.stdpath('cache') .. '/opencl-language-server.log'

local ROOT_MARKERS = {
  'compile_commands.json',
  'compile_flags.txt',
  '.clangd',
  '.git',
}

---@param value string|nil
---@return boolean
local function truthy(value)
  if value == nil then
    return false
  end

  local normalized = value:lower()

  return normalized == '1' or normalized == 'true' or normalized == 'yes' or normalized == 'on'
end

---@return boolean
local function opencl_device_available()
  if vim.fn.executable('clinfo') ~= 1 then
    return false
  end

  local output = vim.fn.system({ 'clinfo', '-l' })

  if vim.v.shell_error ~= 0 then
    return false
  end

  -- `clinfo -l` prints one `Device #...` entry per enumerated device.
  return type(output) == 'string' and output:find('Device #', 1, true) ~= nil
end

---@param bufnr integer
---@param on_dir fun(root_dir: string|nil)
local function root_dir(bufnr, on_dir)
  if not opencl_device_available() then
    vim.schedule(function()
      vim.notify_once(
        'opencl-language-server was not started: no OpenCL device was found. '
          .. 'Install a vendor OpenCL ICD/runtime and verify it with `clinfo -l`.',
        vim.log.levels.INFO,
        { title = 'OpenCL LSP' }
      )
    end)

    on_dir(nil)
    return
  end

  local filename = vim.api.nvim_buf_get_name(bufnr)

  if filename ~= '' then
    local detected = vim.fs.root(filename, ROOT_MARKERS)

    if type(detected) == 'string' and detected ~= '' then
      on_dir(vim.fs.normalize(detected))
      return
    end

    local parent = vim.fs.dirname(filename)

    if type(parent) == 'string' and parent ~= '' then
      on_dir(vim.fs.normalize(parent))
      return
    end
  end

  on_dir(vim.fn.getcwd())
end

---@return string[]
local function command()
  local args = {
    'opencl-language-server',
    '--stdio',
  }

  if truthy(vim.env.NVIM_OPENCL_LS_LOG) then
    args[#args + 1] = '--enable-file-logging'
    args[#args + 1] = '--log-file'
    args[#args + 1] = vim.fn.stdpath('cache') .. '/opencl-language-server.log'
    args[#args + 1] = '--log-level'
    args[#args + 1] = '5'
  end

  return args
end

---@type vim.lsp.Config
return {
  cmd = command,

  filetypes = {
    'opencl',
  },

  root_dir = root_dir,

  root_markers = ROOT_MARKERS,

  single_file_support = false,
}
