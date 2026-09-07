-- #################################################################
-- /qompassai/Diver/lua/utils/games/unity/actions.lua
-- Qompass AI Unity Actions
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
local util = require('utils.games.unity.util')
local config = require('utils.games.unity.config')
local shared_util = require('utils.games.shared.util')
local output_factory = require('utils.games.shared.output')

local notify = vim.notify
local levels = vim.log.levels
local output = output_factory.new(config.output_filetype)

local M = {}

function M.open_editor()
  local root = util.require_root()
  if not root then
    return
  end
  local editor = util.require_editor(root)
  if not editor then
    return
  end
  vim.fn.jobstart({ editor, '-projectPath', root }, { detach = true })
  notify('Unity: editor launching for ' .. root, levels.INFO)
end

function M.build_project()
  local root = util.require_root()
  if not root then
    return
  end
  local editor = util.require_editor(root)
  if not editor then
    return
  end

  local method = shared_util.trim(vim.fn.input('Unity build method (Class.Method): '))
  if method == '' then
    return
  end
  local build_target = shared_util.trim(vim.fn.input('Unity -buildTarget (blank = default): '))
  local log_file = root .. '/build/unity-build.log'
  vim.fn.mkdir(root .. '/build', 'p')

  local cmd = {
    editor,
    '-batchmode',
    '-nographics',
    '-quit',
    '-projectPath',
    root,
    '-executeMethod',
    method,
    '-logFile',
    log_file,
  }
  if build_target ~= '' then
    vim.list_extend(cmd, { '-buildTarget', build_target })
  end

  output.run_with_progress('UnityBuild', 'Building via ' .. method, cmd, {
    show_output = true,
    success = 'Build finished. Log: ' .. log_file,
    failure = 'Build failed. See ' .. log_file,
    cwd = root,
  })
end

function M.run_tests()
  local root = util.require_root()
  if not root then
    return
  end
  local editor = util.require_editor(root)
  if not editor then
    return
  end

  local platform = shared_util.trim(vim.fn.input('Unity test platform (EditMode/PlayMode): ', 'EditMode'))
  if platform == '' then
    platform = 'EditMode'
  end
  local results = root .. '/build/unity-test-results.xml'
  vim.fn.mkdir(root .. '/build', 'p')

  local cmd = {
    editor,
    '-batchmode',
    '-nographics',
    '-projectPath',
    root,
    '-runTests',
    '-testPlatform',
    platform,
    '-testResults',
    results,
  }

  output.run_with_progress('UnityTest', 'Running ' .. platform .. ' tests', cmd, {
    show_output = true,
    success = 'Tests finished. Results: ' .. results,
    failure = 'Tests failed. Results: ' .. results,
    cwd = root,
  })
end

function M.refresh_project()
  local root = util.require_root()
  if not root then
    return
  end
  local editor = util.require_editor(root)
  if not editor then
    return
  end

  local log_file = root .. '/build/unity-refresh.log'
  vim.fn.mkdir(root .. '/build', 'p')

  output.run_with_progress(
    'UnityRefresh',
    'Reimporting assets',
    { editor, '-batchmode', '-nographics', '-quit', '-projectPath', root, '-logFile', log_file },
    {
      show_output = true,
      success = 'Reimport finished.',
      failure = 'Reimport failed. See ' .. log_file,
      cwd = root,
    }
  )
end

function M.open_editor_log()
  local root = util.find_root()
  local candidates = {}
  if root then
    candidates[#candidates + 1] = root .. '/build/unity-build.log'
  end
  candidates[#candidates + 1] = config.default_editor_log()

  local path = shared_util.first_existing_path(candidates)
  if not path then
    notify('Unity: no Editor.log found yet.', levels.WARN)
    return
  end
  vim.cmd('edit ' .. vim.fn.fnameescape(path))
end

function M.describe_project()
  local root = util.find_root()
  notify(
    table.concat({
      'Unity project root: ' .. (root or 'not found'),
      'Recorded editor version: ' .. (util.project_editor_version(root) or 'unknown'),
      'Resolved editor binary: ' .. (util.find_editor(root) or 'not found'),
    }, '\n'),
    levels.INFO
  )
end

function M.get_actions()
  return {
    { id = 'open_editor', label = 'Open editor', group = 'Editor', run = M.open_editor },
    { id = 'build_project', label = 'Build (batchmode -executeMethod)', group = 'Build', run = M.build_project },
    { id = 'refresh_project', label = 'Reimport assets (batchmode)', group = 'Build', run = M.refresh_project },
    { id = 'run_tests', label = 'Run tests', group = 'Test', run = M.run_tests },
    { id = 'open_editor_log', label = 'Open Editor.log', group = 'Project', run = M.open_editor_log },
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
    notify('Unknown Unity action: ' .. id, levels.ERROR)
    return
  end
  M.run_action(action)
end

function M.show_menu()
  require('utils.games.shared.ui').select_root_menu(M.get_actions(), M.run_action, {
    group_order = config.group_order,
    prompt = 'Select Unity action:',
  })
end

return M
