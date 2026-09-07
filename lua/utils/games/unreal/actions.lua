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
local async_util = require('utils.games.shared.async_util')

local notify = vim.notify
local levels = vim.log.levels
local output = output_factory.new(config.output_filetype)
local fs = vim.fs

local M = {}

-- Fixed, explicit bound (Tiger Style): Setup.sh's job is downloading
-- gigabytes of third-party binaries over the network the first time
-- an engine checkout is bootstrapped -- more like a `git lfs pull` of
-- a large monorepo than a compile step. A short timeout would abort
-- a perfectly healthy download in progress, but "no timeout" is never
-- acceptable either (a genuinely hung download should eventually be
-- reported, not sit silently forever) -- so the bound is generous
-- (hours, not minutes) rather than absent.
local ENGINE_BOOTSTRAP_TIMEOUT_MS = 3 * 60 * 60 * 1000

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

-- TODO (README): "Unreal: cook-only action."
--
-- WHY THIS IS ITS OWN ACTION rather than reusing package_project with
-- more flags: cooking converts source content (materials, blueprints,
-- textures) into platform-ready runtime data WITHOUT compiling C++ or
-- staging/packing the result -- the same relationship a `make`
-- target that only runs a codegen step has to the full `make all &&
-- make install`. Iterating on content (tweak a material, re-cook,
-- check it in PIE-cooked mode) is much faster when the build and
-- stage steps are skipped entirely instead of merely hidden behind
-- "incremental" flags.
function M.cook_only()
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

  local platform = shared_util.trim(vim.fn.input('Unreal cook platform: ', config.default_platform()))
  if platform == '' then
    platform = config.default_platform()
  end

  output.run_with_progress(
    'UnrealCookOnly',
    'Cooking (' .. platform .. ') -- no build/stage',
    {
      uat,
      'BuildCookRun',
      '-project=' .. uproject,
      '-noP4',
      '-platform=' .. platform,
      '-cook',
      '-skipbuild',
      '-skipstage',
    },
    {
      show_output = true,
      success = 'Cook finished (no build/stage).',
      failure = 'Cook failed.',
      cwd = util.project_root(uproject),
    }
  )
end

-- TODO (README): "Setup.sh/GenerateProjectFiles bootstrap for a
-- freshly cloned engine checkout."
--
-- Deliberately prompts for the engine root rather than reusing
-- `util.require_engine_root()`: that helper is meant for engines
-- already configured via NVIM_UNREAL_ENGINE_ROOT (built and ready to
-- launch); a checkout you are about to bootstrap for the FIRST time
-- may not be that one yet (e.g. you are standing up a second engine
-- version side by side). We still offer the configured root as the
-- input's default so the common case is just pressing <CR>.
function M.bootstrap_engine_checkout()
  local default_root = util.find_engine_root() or config.engine_root_candidates()[1] or ''
  local engine_root = shared_util.trim(vim.fn.input('Freshly cloned Unreal Engine root: ', default_root, 'dir'))
  if engine_root == '' then
    return
  end
  engine_root = engine_root:gsub('/+$', '')

  local setup_script = config.engine_setup_script(engine_root)
  local generate_script = config.engine_generate_project_files_script(engine_root)
  if vim.fn.filereadable(setup_script) == 0 then
    notify(
      'Unreal: Setup script not found at ' .. setup_script .. ' -- is this really an engine source checkout root?',
      levels.ERROR
    )
    return
  end

  local buf = output.create_window()
  local system_opts = output.create_system_opts(buf)
  system_opts.cwd = engine_root

  notify(
    'Unreal: bootstrapping engine checkout at ' .. engine_root .. ' (Setup.sh, then GenerateProjectFiles.sh)...',
    levels.INFO
  )

  -- WHY vim.async HERE, specifically (this is the textbook case for
  -- it): this is a strictly ORDERED two-step bootstrap --
  -- GenerateProjectFiles.sh inspects third-party source that
  -- Setup.sh's downloads must have already placed on disk, so step 2
  -- must not start until step 1 has truly finished successfully.
  -- `output.run_with_progress` (used elsewhere in this file) fires a
  -- single command and reports one exit code; chaining a second
  -- command from its `on_success` callback would work, but each
  -- additional ordered step would nest one callback deeper. Awaiting
  -- each step in turn instead reads top-to-bottom like the shell
  -- one-liner it replaces (`./Setup.sh && ./GenerateProjectFiles.sh`),
  -- with the failure of either step short-circuiting the rest via a
  -- plain Lua `error()` -- same control flow as `&&`, not a new one.
  local ok, err = async_util.run_bounded(function()
    local setup_ok, setup_completed = vim.async.pawait(async_util.system_task({ setup_script }, system_opts))
    if not setup_ok or setup_completed == nil then
      error('Setup.sh did not complete: ' .. tostring(setup_completed))
    end
    if setup_completed.code ~= 0 then
      error('Setup.sh exited with code ' .. tostring(setup_completed.code))
    end

    if vim.fn.filereadable(generate_script) == 0 then
      error('GenerateProjectFiles script not found at ' .. generate_script)
    end

    local generate_ok, generate_completed = vim.async.pawait(async_util.system_task({ generate_script }, system_opts))
    if not generate_ok or generate_completed == nil or generate_completed.code ~= 0 then
      error('GenerateProjectFiles.sh exited with code ' .. tostring(generate_completed and generate_completed.code))
    end
  end, ENGINE_BOOTSTRAP_TIMEOUT_MS)

  if ok then
    notify('Unreal: engine checkout bootstrapped -- Setup.sh and GenerateProjectFiles.sh both finished.', levels.INFO)
  else
    notify('Unreal: engine bootstrap failed: ' .. tostring(err), levels.ERROR)
  end
end

-- TODO (README): "editor plugin packaging (RunUAT.sh BuildPlugin)."
--
-- Deliberately does NOT require an open .uproject/engine pairing the
-- way build/package/cook do: a `.uplugin` can be packaged standalone
-- (e.g. to publish it for other projects), so this only needs an
-- engine root plus the two paths the user gives us -- narrower
-- preconditions than the project-bound actions above, stated
-- explicitly rather than silently reusing require_uproject().
function M.package_plugin()
  local engine_root = util.require_engine_root()
  if not engine_root then
    return
  end

  local uat = config.run_uat_script(engine_root)
  if vim.fn.filereadable(uat) == 0 then
    notify('Unreal: RunUAT script not found at ' .. uat, levels.ERROR)
    return
  end

  local plugin_path = shared_util.trim(vim.fn.input('Path to .uplugin: ', '', 'file'))
  if plugin_path == '' then
    return
  end
  if plugin_path:sub(-#'.uplugin') ~= '.uplugin' then
    notify('Unreal: expected a .uplugin file, got: ' .. plugin_path, levels.ERROR)
    return
  end

  local default_package_dir = fs.joinpath(fs.dirname(plugin_path), 'Package')
  local package_dir = shared_util.trim(vim.fn.input('Package output directory: ', default_package_dir, 'dir'))
  if package_dir == '' then
    return
  end

  output.run_with_progress(
    'UnrealPackagePlugin',
    'Packaging plugin ' .. fs.basename(plugin_path),
    { uat, 'BuildPlugin', '-Plugin=' .. plugin_path, '-Package=' .. package_dir, '-Rocket' },
    {
      show_output = true,
      success = 'Plugin packaged: ' .. package_dir,
      failure = 'Plugin packaging failed.',
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
    { id = 'cook_only', label = 'Cook only (skip build/stage)', group = 'Build', run = M.cook_only },
    {
      id = 'bootstrap_engine_checkout',
      label = 'Bootstrap fresh engine checkout (Setup + GenerateProjectFiles)',
      group = 'Build',
      run = M.bootstrap_engine_checkout,
    },
    { id = 'package_project', label = 'Package (BuildCookRun)', group = 'Package', run = M.package_project },
    { id = 'package_plugin', label = 'Package editor plugin (BuildPlugin)', group = 'Package', run = M.package_plugin },
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
