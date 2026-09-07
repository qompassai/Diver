-- #################################################################
-- /qompassai/Diver/lua/utils/games/unreal/config.lua
-- Qompass AI Unreal Config
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
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
-- Reuses the same engine-root override env vars as lua/dap/unreal.lua
-- so a single NVIM_UNREAL_ENGINE_ROOT covers both build tooling here
-- and native (lldb-dap/GDB DAP) debugging there.
local M = {}

M.engine_env_names = {
  'NVIM_UNREAL_ENGINE_ROOT',
  'UNREAL_ENGINE_ROOT',
  'UE_ENGINE_ROOT',
  'UE_ROOT',
}

M.project_env_name = 'NVIM_UNREAL_PROJECT'
M.output_filetype = 'unreal-output'
M.group_order = { 'Editor', 'Build', 'Package', 'Project' }
M.build_configurations = { 'DebugGame', 'Development', 'Debug', 'Shipping', 'Test' }
M.target_kinds = { 'Editor', 'Game', 'Client', 'Server' }

function M.default_platform()
  if vim.fn.has('win32') == 1 or vim.fn.has('win64') == 1 then
    return 'Win64'
  end
  if vim.fn.has('mac') == 1 or vim.fn.has('macunix') == 1 then
    return 'Mac'
  end
  return 'Linux'
end

function M.engine_root_candidates()
  local home = vim.fn.expand('~')
  return {
    home .. '/UnrealEngine',
    home .. '/UnrealEngine-5',
    home .. '/.local/share/UnrealEngine',
    '/opt/UnrealEngine',
    '/opt/unreal-engine',
  }
end

function M.editor_binary(engine_root)
  if vim.fn.has('win32') == 1 or vim.fn.has('win64') == 1 then
    return engine_root .. '/Engine/Binaries/Win64/UnrealEditor.exe'
  end
  if vim.fn.has('mac') == 1 or vim.fn.has('macunix') == 1 then
    return engine_root .. '/Engine/Binaries/Mac/UnrealEditor.app/Contents/MacOS/UnrealEditor'
  end
  return engine_root .. '/Engine/Binaries/Linux/UnrealEditor'
end

function M.build_script(engine_root)
  if vim.fn.has('win32') == 1 or vim.fn.has('win64') == 1 then
    return engine_root .. '/Engine/Build/BatchFiles/Build.bat'
  end
  if vim.fn.has('mac') == 1 or vim.fn.has('macunix') == 1 then
    return engine_root .. '/Engine/Build/BatchFiles/Mac/Build.sh'
  end
  return engine_root .. '/Engine/Build/BatchFiles/Linux/Build.sh'
end

function M.generate_project_files_script(engine_root)
  if vim.fn.has('win32') == 1 or vim.fn.has('win64') == 1 then
    return engine_root .. '/Engine/Build/BatchFiles/GenerateProjectFiles.bat'
  end
  if vim.fn.has('mac') == 1 or vim.fn.has('macunix') == 1 then
    return engine_root .. '/Engine/Build/BatchFiles/Mac/GenerateProjectFiles.sh'
  end
  return engine_root .. '/Engine/Build/BatchFiles/Linux/GenerateProjectFiles.sh'
end

function M.run_uat_script(engine_root)
  if vim.fn.has('win32') == 1 or vim.fn.has('win64') == 1 then
    return engine_root .. '/Engine/Build/BatchFiles/RunUAT.bat'
  end
  return engine_root .. '/Engine/Build/BatchFiles/RunUAT.sh'
end

return M
