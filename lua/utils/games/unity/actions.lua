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
local async_util = require('utils.games.shared.async_util')

local notify = vim.notify
local levels = vim.log.levels
local output = output_factory.new(config.output_filetype)

local M = {}
local MAX_BUILD_TARGETS = 8
local BUILD_MATRIX_TIMEOUT_MS = 2 * 60 * 60 * 1000

function M.open_editor()
  local root = util.require_root()
  if not root then
    return
  end
  local editor = util.require_editor(root)
  if not editor then
    return
  end
  vim.fn.jobstart({ editor, '-projectPath', root }, {
    detach = true,
  })
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
    vim.list_extend(cmd, {
      '-buildTarget',
      build_target,
    })
  end

  output.run_with_progress('UnityBuild', 'Building via ' .. method, cmd, {
    show_output = true,
    success = 'Build finished. Log: ' .. log_file,
    failure = 'Build failed. See ' .. log_file,
    cwd = root,
  })
end

-- TODO (README): "multi-target batch build (-buildTarget matrix)".
function M.build_target_matrix()
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

  local targets_input = shared_util.trim(
    vim.fn.input('Build targets, comma-separated (e.g. StandaloneLinux64,StandaloneWindows64,Android): ')
  )
  if targets_input == '' then
    return
  end

  local targets = {}
  for candidate in targets_input:gmatch('[^,]+') do
    local trimmed = shared_util.trim(candidate)
    if trimmed ~= '' then
      targets[#targets + 1] = trimmed
    end
  end
  assert(#targets > 0, 'Unity: build_target_matrix requires at least one target')
  assert(
    #targets <= MAX_BUILD_TARGETS,
    ('Unity: %d targets exceeds MAX_BUILD_TARGETS=%d'):format(#targets, MAX_BUILD_TARGETS)
  )
  vim.fn.mkdir(root .. '/build', 'p')
  notify(('Unity: starting sequential batch build for %d target(s)...'):format(#targets), levels.INFO)
  local ok, result = async_util.run_bounded(function()
    local per_target_results = {}
    for _, target in ipairs(targets) do
      local log_file = root .. '/build/unity-build-' .. target .. '.log'
      local cmd = {
        editor,
        '-batchmode',
        '-nographics',
        '-quit',
        '-projectPath',
        root,
        '-executeMethod',
        method,
        '-buildTarget',
        target,
        '-logFile',
        log_file,
      }
      local await_ok, completed = vim.async.pawait(async_util.system_task(cmd, {
        cwd = root,
        text = true,
      }))
      per_target_results[#per_target_results + 1] = {
        target = target,
        ok = await_ok and completed ~= nil and completed.code == 0,
        log_file = log_file,
      }
    end
    return per_target_results
  end, BUILD_MATRIX_TIMEOUT_MS)

  if not ok then
    notify('Unity: build matrix did not complete: ' .. tostring(result), levels.ERROR)
    return
  end

  local summary_lines = {}
  local quickfix_failures = {}
  for _, entry in ipairs(result) do
    summary_lines[#summary_lines + 1] =
      string.format('%s: %s (%s)', entry.target, entry.ok and 'OK' or 'FAILED', entry.log_file)
    if not entry.ok then
      quickfix_failures[#quickfix_failures + 1] = { filename = entry.log_file, text = entry.target .. ' build failed' }
    end
  end

  notify(
    'Unity build matrix finished:\n' .. table.concat(summary_lines, '\n'),
    #quickfix_failures == 0 and levels.INFO or levels.ERROR
  )
  if #quickfix_failures > 0 then
    vim.fn.setqflist(quickfix_failures, 'r')
    vim.cmd('copen')
  end
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

local function manifest_path(root)
  return root .. '/' .. config.packages_dir .. '/' .. config.manifest_filename
end

local function lockfile_path(root)
  return root .. '/' .. config.packages_dir .. '/' .. config.lockfile_filename
end

function M.packages_list()
  local root = util.require_root()
  if not root then
    return
  end

  local manifest_contents = shared_util.read_file(manifest_path(root))
  if manifest_contents == nil then
    notify('Unity: no Packages/manifest.json found at ' .. manifest_path(root), levels.ERROR)
    return
  end
  local decode_ok, manifest = pcall(vim.json.decode, manifest_contents)
  if not decode_ok or type(manifest) ~= 'table' or type(manifest.dependencies) ~= 'table' then
    notify('Unity: Packages/manifest.json could not be parsed as expected.', levels.ERROR)
    return
  end

  local lock_contents = shared_util.read_file(lockfile_path(root))
  local lock_decode_ok, lock = pcall(vim.json.decode, lock_contents or '')
  local resolved = {}
  if lock_decode_ok and type(lock) == 'table' and type(lock.dependencies) == 'table' then
    resolved = lock.dependencies
  end

  local package_names = {}
  for package_name in pairs(manifest.dependencies) do
    package_names[#package_names + 1] = package_name
  end
  table.sort(package_names)

  local lines = { 'Unity packages -- requested (manifest.json) vs. resolved (packages-lock.json):', '' }
  for _, package_name in ipairs(package_names) do
    local requested = tostring(manifest.dependencies[package_name])
    local resolved_entry = resolved[package_name]
    local resolved_version = (resolved_entry and resolved_entry.version)
      or 'unresolved (open the editor once to resolve)'
    lines[#lines + 1] = string.format('  %-42s requested=%-24s resolved=%s', package_name, requested, resolved_version)
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = 'unity-packages'
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].modifiable = false
  vim.cmd('botright split')
  vim.api.nvim_win_set_buf(vim.api.nvim_get_current_win(), buf)
end

function M.packages_add()
  local root = util.require_root()
  if not root then
    return
  end

  local path = manifest_path(root)
  local contents = shared_util.read_file(path)
  if contents == nil then
    notify('Unity: no Packages/manifest.json found at ' .. path, levels.ERROR)
    return
  end
  local decode_ok, manifest = pcall(vim.json.decode, contents)
  if not decode_ok or type(manifest) ~= 'table' then
    notify('Unity: Packages/manifest.json could not be parsed as expected.', levels.ERROR)
    return
  end
  manifest.dependencies = manifest.dependencies or {}

  local package_name = shared_util.trim(vim.fn.input('Package id (e.g. com.unity.timeline): '))
  if package_name == '' then
    return
  end
  local version_or_url = shared_util.trim(vim.fn.input('Version, or a git URL for a git-hosted package: '))
  if version_or_url == '' then
    return
  end

  manifest.dependencies[package_name] = version_or_url

  local write_ok, write_err = pcall(function()
    local encoded = vim.json.encode(manifest)
    local file = assert(io.open(path, 'w'), 'could not open manifest.json for write: ' .. path)
    file:write(encoded)
    file:close()
  end)
  if not write_ok then
    notify('Unity: failed to write manifest.json: ' .. tostring(write_err), levels.ERROR)
    return
  end

  notify(
    string.format(
      'Unity: added "%s": "%s" to Packages/manifest.json. Open the editor (or run Reimport assets) to resolve it.',
      package_name,
      version_or_url
    ),
    levels.INFO
  )
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
    {
      id = 'build_target_matrix',
      label = 'Build target matrix (-buildTarget, sequential)',
      group = 'Build',
      run = M.build_target_matrix,
    },
    { id = 'refresh_project', label = 'Reimport assets (batchmode)', group = 'Build', run = M.refresh_project },
    { id = 'run_tests', label = 'Run tests', group = 'Test', run = M.run_tests },
    {
      id = 'packages_list',
      label = 'List packages (requested vs. resolved)',
      group = 'Packages',
      run = M.packages_list,
    },
    { id = 'packages_add', label = 'Add package to manifest.json', group = 'Packages', run = M.packages_add },
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
