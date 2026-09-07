-- #################################################################
-- /qompassai/Diver/lua/utils/games/unreal/actions.lua
-- Qompass AI Unreal Actions
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
-- Native build/package tooling for Unreal projects. Native C++
-- source debugging (lldb-dap/GDB DAP) already lives in
-- lua/dap/unreal.lua -- this module intentionally does not duplicate it.
local util = require('utils.games.unreal.util')
local config = require('utils.games.unreal.config')
local shared_util = require('utils.games.shared.util')
local output_factory = require('utils.games.shared.output')

local notify = vim.notify
local levels = vim.log.levels
local output = output_factory.new(config.output_filetype)
local fs = vim.fs

local M = {}

function M.open_editor()
  local uproject = util.require_uproject()
  local engine_root = util.require_engine_root()
  if not uproject or not engine_root then
    return
  end
  local editor = config.editor_binary(engine_root)
  vim.fn.jobstart({ editor, uproject, '-log' }, { cwd = util.project_root(uproject), detach = true })
  notify('Unreal: editor launching for ' .. uproject, levels.INFO)
end

function M.generate_project_files()
  local uproject = util.require_uproject()
  local engine_root = util.require_engine_root()
  if not uproject or not engine_root then
    return
  end
  local script = config.generate_project_files_script(engine_root)
  if vim.fn.filereadable(script) == 0 then
    notify('Unreal: GenerateProjectFiles script not found at ' .. script, levels.ERROR)
    return
  end

  output.run_with_progress(
    'UnrealGenerateProjectFiles',
    'Generating project files',
    { script, uproject },
    {
      show_output = true,
      success = 'Project files generated.',
      failure = 'Failed to generate project files.',
      cwd = util.project_root(uproject),
    }
  )
end

local function prompt_choice(title, choices, default)
  local prompt = { title }
  for i, choice in ipairs(choices) do
    prompt[#prompt + 1] = string.format('%d. %s', i, choice)
  end
  local selected = vim.fn.inputlist(prompt)
  if selected >= 1 and selected <= #choices then
    return choices[selected]
  end
  return default
end

function M.build_project()
  local uproject = util.require_uproject()
  local engine_root = util.require_engine_root()
  if not uproject or not engine_root then
    return
  end

  local script = config.build_script(engine_root)
  if vim.fn.filereadable(script) == 0 then
    notify('Unreal: Build script not found at ' .. script, levels.ERROR)
    return
  end

  local configuration = prompt_choice('Unreal build configuration:', config.build_configurations, 'DebugGame')
  local target_kind = prompt_choice('Unreal target:', config.target_kinds, 'Editor')
  local name = util.project_name(uproject)
  local target = target_kind == 'Game' and name or (name .. target_kind)
  local platform = config.default_platform()

  output.run_with_progress(
    'UnrealBuild',
    string.format('Building %s %s %s', target, platform, configuration),
    { script, target, platform, configuration, uproject, '-WaitMutex' },
    {
      show_output = true,
      success = 'Build finished.',
      failure = 'Build failed.',
      cwd = util.project_root(uproject),
    }
  )
end

function M.package_project()
  local uproject = util.require_uproject()
  local engine_root = util.require_engine_root()
  if not uproject or not engine_root then
    return
  end

  local uat = config.run_uat_script(engine_root)
  if vim.fn.filereadable(uat) == 0 then
    notify('Unreal: RunUAT script not found at ' .. uat, levels.ERROR)
    return
  end

  local platform = shared_util.trim(vim.fn.input('Unreal package platform: ', config.default_platform()))
  if platform == '' then
    platform = config.default_platform()
  end
  local configuration = prompt_choice('Unreal package configuration:', config.build_configurations, 'Development')
  local archive_dir = shared_util.trim(
    vim.fn.input('Unreal archive directory: ', util.project_root(uproject) .. '/Saved/StagedBuilds', 'dir')
  )
  if archive_dir == '' then
    return
  end

  output.run_with_progress(
    'UnrealPackage',
    'Packaging (' .. platform .. '/' .. configuration .. ')',
    {
      uat,
      'BuildCookRun',
      '-project=' .. uproject,
      '-noP4',
      '-platform=' .. platform,
      '-clientconfig=' .. configuration,
      '-cook',
      '-build',
      '-stage',
      '-pak',
      '-archive',
      '-archivedirectory=' .. archive_dir,
    },
    {
      show_output = true,
      success = 'Package finished: ' .. archive_dir,
      failure = 'Packaging failed.',
      cwd = util.project_root(uproject),
    }
  )
end

function M.open_logs()
  local uproject = util.find_uproject()
  local root = util.project_root(uproject)
  local logs_dir = fs.joinpath(root, 'Saved', 'Logs')
  if vim.fn.isdirectory(logs_dir) == 0 then
    notify('Unreal: Saved/Logs directory does not exist yet.', levels.WARN)
    return
  end
  vim.cmd('edit ' .. vim.fn.fnameescape(logs_dir))
end

function M.describe_project()
  local uproject = util.find_uproject()
  local engine_root = util.find_engine_root()
  notify(
    table.concat({
      'Unreal project: ' .. (uproject or 'not found'),
      'Project name: ' .. (util.project_name(uproject) or 'unknown'),
      'Engine root: ' .. (engine_root or 'not found'),
      'Editor: ' .. (engine_root and config.editor_binary(engine_root) or 'not found'),
      'See :DebugUnreal* commands in lua/dap/unreal.lua for native source debugging.',
    }, '\n'),
    levels.INFO
  )
end

function M.get_actions()
  return {
    { id = 'open_editor', label = 'Open editor', group = 'Editor', run = M.open_editor },
    { id = 'generate_project_files', label = 'Generate project files', group = 'Build', run = M.generate_project_files },
    { id = 'build_project', label = 'Build project', group = 'Build', run = M.build_project },
    { id = 'package_project', label = 'Package (BuildCookRun)', group = 'Package', run = M.package_project },
    { id = 'open_logs', label = 'Open Saved/Logs', group = 'Project', run = M.open_logs },
    { id = 'describe_project', label = 'Describe project', group = 'Project', run = M.describe_project },
  }
end

function M.run_action(action)
  action.run()
end

function M.run_action_by_id(id)
  local list = M.get_actions()
  local map = shared_util.build_action_map(list)
  local action = map[id]
  if not action then
    notify('Unknown Unreal action: ' .. id, levels.ERROR)
    return
  end
  M.run_action(action)
end

function M.show_menu()
  require('utils.games.shared.ui').select_root_menu(M.get_actions(), M.run_action, {
    group_order = config.group_order,
    prompt = 'Select Unreal action:',
  })
end

return M
