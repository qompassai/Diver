-- #################################################################
-- /qompassai/Diver/lua/utils/games/shared/godot_engine.lua
-- Qompass AI Godot-compatible Engine Factory
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
-- Shared native-tooling factory for Godot and Godot-compatible forks
-- (currently Godot 4 and Redot 4, which retain project.godot / .tscn /
-- .gd file compatibility). Each fork gets its own isolated module by
-- calling M.new(opts) with its own binary candidates and keymap prefix,
-- so the two engines never share cached state or output windows.
local shared_util = require('utils.games.shared.util')
local shared_ui = require('utils.games.shared.ui')
local output_factory = require('utils.games.shared.output')

local notify = vim.notify
local levels = vim.log.levels

local M = {}

---@param opts table
---  name          display name, e.g. "Godot" or "Redot"
---  command_prefix    user command prefix, e.g. "Godot" or "Redot"
---  leader        keymap group prefix, e.g. "<leader>gg" or "<leader>gr"
---  binaries      ordered list of executable name candidates
---  env_names     ordered list of env var names for an explicit override
---  root_markers  project root marker files (default {'project.godot'})
function M.new(opts)
  assert(opts and opts.name, 'games.shared.godot_engine: opts.name is required')

  local engine = {}
  local name = opts.name
  local command_prefix = opts.command_prefix or name
  local leader = opts.leader or '<leader>gg'
  local binaries = opts.binaries or { name:lower() }
  local env_names = opts.env_names or { name:upper() .. '_BIN' }
  local root_markers = opts.root_markers or { 'project.godot' }
  local output_filetype = (opts.output_filetype or (name:lower() .. '-output'))

  local output = output_factory.new(output_filetype)

  local config = {
    output_filetype = output_filetype,
    group_order = { 'Editor', 'Run', 'Export', 'Project' },
  }
  engine.config = config

  local util = {}
  engine.util = util

  function util.find_binary()
    local override = shared_util.env_first(env_names)
    if override then
      local resolved = shared_util.first_executable({ override })
      if resolved then
        return resolved
      end
      notify(name .. ': configured binary is not executable: ' .. override, levels.WARN)
    end
    return shared_util.first_executable(binaries)
  end

  function util.find_root(start_dir)
    return shared_util.find_root(root_markers, start_dir)
  end

  function util.require_binary()
    local bin = util.find_binary()
    if not bin then
      notify(
        string.format(
          '%s executable not found. Set %s or add one of {%s} to $PATH.',
          name,
          table.concat(env_names, ' / '),
          table.concat(binaries, ', ')
        ),
        levels.ERROR
      )
    end
    return bin
  end

  function util.require_root()
    local root = util.find_root()
    if not root then
      notify(name .. ': no ' .. table.concat(root_markers, '/') .. ' found upward from cwd.', levels.ERROR)
    end
    return root
  end

  local actions = {}
  engine.actions = actions

  function actions.open_editor()
    local bin, root = util.require_binary(), util.require_root()
    if not bin or not root then
      return
    end
    vim.fn.jobstart({ bin, '--editor', '--path', root }, { detach = true })
    notify(name .. ': editor launching for ' .. root, levels.INFO)
  end

  function actions.open_project_manager()
    local bin = util.require_binary()
    if not bin then
      return
    end
    vim.fn.jobstart({ bin, '--project-manager' }, { detach = true })
    notify(name .. ': project manager launching', levels.INFO)
  end

  function actions.run_project()
    local bin, root = util.require_binary(), util.require_root()
    if not bin or not root then
      return
    end
    vim.fn.jobstart({ bin, '--path', root }, { detach = true })
    notify(name .. ': running project at ' .. root, levels.INFO)
  end

  function actions.run_current_scene()
    local bin, root = util.require_binary(), util.require_root()
    if not bin or not root then
      return
    end
    local file = vim.api.nvim_buf_get_name(0)
    if file == '' or not file:match('%.tscn$') then
      notify(name .. ': current buffer is not a .tscn scene', levels.WARN)
      return
    end
    local relative = file:sub(#root + 2)
    vim.fn.jobstart({ bin, '--path', root, relative }, { detach = true })
    notify(name .. ': running scene ' .. relative, levels.INFO)
  end

  function actions.check_current_script()
    local bin, root = util.require_binary(), util.require_root()
    if not bin or not root then
      return
    end
    local file = vim.api.nvim_buf_get_name(0)
    if file == '' or not file:match('%.gd$') then
      notify(name .. ': current buffer is not a .gd script', levels.WARN)
      return
    end
    output.run_with_progress(
      command_prefix .. 'Check',
      'Checking ' .. vim.fs.basename(file),
      { bin, '--headless', '--path', root, '--check-only', '--script', file },
      {
        show_output = true,
        success = 'No parse errors.',
        failure = 'Parse errors found.',
        cwd = root,
      }
    )
  end

  local function export(preset_kind, flag)
    local bin, root = util.require_binary(), util.require_root()
    if not bin or not root then
      return
    end
    local preset = shared_util.trim(vim.fn.input(name .. ' export preset: '))
    if preset == '' then
      return
    end
    local output_path = shared_util.trim(
      vim.fn.input(name .. ' export output path: ', root .. '/build/', 'file')
    )
    if output_path == '' then
      return
    end
    vim.fn.mkdir(vim.fs.dirname(output_path), 'p')
    output.run_with_progress(
      command_prefix .. preset_kind,
      'Exporting (' .. preset_kind .. ') ' .. preset,
      { bin, '--headless', '--path', root, flag, preset, output_path },
      {
        show_output = true,
        success = 'Export finished: ' .. output_path,
        failure = 'Export failed.',
        cwd = root,
      }
    )
  end

  function actions.export_release()
    export('ExportRelease', '--export-release')
  end

  function actions.export_debug()
    export('ExportDebug', '--export-debug')
  end

  function actions.describe_project()
    local root = util.find_root()
    local bin = util.find_binary()
    notify(
      table.concat({
        name .. ' project root: ' .. (root or 'not found'),
        name .. ' binary: ' .. (bin or 'not found'),
      }, '\n'),
      levels.INFO
    )
  end

  function actions.get_actions()
    return {
      { id = 'open_editor', label = 'Open editor', group = 'Editor', run = actions.open_editor },
      { id = 'open_project_manager', label = 'Open project manager', group = 'Editor', run = actions.open_project_manager },
      { id = 'run_project', label = 'Run project', group = 'Run', run = actions.run_project },
      { id = 'run_current_scene', label = 'Run current scene', group = 'Run', run = actions.run_current_scene },
      { id = 'check_current_script', label = 'Check current script (parse only)', group = 'Run', run = actions.check_current_script },
      { id = 'export_release', label = 'Export release', group = 'Export', run = actions.export_release },
      { id = 'export_debug', label = 'Export debug', group = 'Export', run = actions.export_debug },
      { id = 'describe_project', label = 'Describe project', group = 'Project', run = actions.describe_project },
    }
  end

  function actions.run_action(action)
    action.run()
  end

  function actions.run_action_by_id(id)
    local list = actions.get_actions()
    local map = shared_util.build_action_map(list)
    local action = map[id]
    if not action then
      notify('Unknown ' .. name .. ' action: ' .. id, levels.ERROR)
      return
    end
    actions.run_action(action)
  end

  function actions.show_menu()
    shared_ui.select_root_menu(actions.get_actions(), actions.run_action, {
      group_order = config.group_order,
      prompt = 'Select ' .. name .. ' action:',
    })
  end

  local commands = {}
  engine.commands = commands

  function commands.setup_commands()
    local action_list = actions.get_actions()

    vim.api.nvim_create_user_command(command_prefix, function()
      actions.show_menu()
    end, { desc = 'Open ' .. name .. ' action menu' })

    vim.api.nvim_create_user_command(command_prefix .. 'Action', function(cmd_opts)
      actions.run_action_by_id(cmd_opts.args)
    end, {
      nargs = 1,
      complete = function(arg_lead)
        return shared_util.get_action_ids(action_list, arg_lead)
      end,
      desc = 'Run a ' .. name .. ' action by id',
    })

    for i = 1, #action_list do
      local action = action_list[i]
      local cmd_name = command_prefix .. shared_util.snake_to_pascal(action.id)
      vim.api.nvim_create_user_command(cmd_name, function()
        actions.run_action(action)
      end, { desc = action.label })
    end
  end

  function commands.setup_keymaps()
    local map = vim.keymap.set
    local function key(suffix)
      return leader .. suffix
    end

    map('n', key('e'), actions.open_editor, { desc = name .. ': Open editor' })
    map('n', key('p'), actions.open_project_manager, { desc = name .. ': Open project manager' })
    map('n', key('r'), actions.run_project, { desc = name .. ': Run project' })
    map('n', key('s'), actions.run_current_scene, { desc = name .. ': Run current scene' })
    map('n', key('c'), actions.check_current_script, { desc = name .. ': Check current script' })
    map('n', key('x'), actions.export_release, { desc = name .. ': Export release' })
    map('n', key('d'), actions.export_debug, { desc = name .. ': Export debug' })
  end

  function engine.setup()
    commands.setup_commands()
    commands.setup_keymaps()
  end

  engine.show_menu = actions.show_menu
  engine.run_action_by_id = actions.run_action_by_id

  return engine
end

return M
