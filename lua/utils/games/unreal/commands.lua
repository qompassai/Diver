-- #################################################################
-- /qompassai/Diver/lua/utils/games/unreal/commands.lua
-- Qompass AI Unreal Commands
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
local actions = require('utils.games.unreal.actions')
local shared_util = require('utils.games.shared.util')
local M = {}
function M.setup_commands()
  local action_list = actions.get_actions()

  vim.api.nvim_create_user_command('Unreal', function()
    actions.show_menu()
  end, { desc = 'Open Unreal action menu' })

  vim.api.nvim_create_user_command('UnrealAction', function(opts)
    actions.run_action_by_id(opts.args)
  end, {
    nargs = 1,
    complete = function(arg_lead)
      return shared_util.get_action_ids(action_list, arg_lead)
    end,
    desc = 'Run an Unreal action by id',
  })

  for i = 1, #action_list do
    local action = action_list[i]
    local command_name = 'Unreal' .. shared_util.snake_to_pascal(action.id)
    vim.api.nvim_create_user_command(command_name, function()
      actions.run_action(action)
    end, { desc = action.label })
  end
end
function M.setup_keymaps()
  local map = vim.keymap.set
  map('n', '<leader>gee', actions.open_editor, {
    desc = 'Unreal: Open editor',
  })
  map('n', '<leader>geg', actions.generate_project_files, {
    desc = 'Unreal: Generate project files',
  })
  map('n', '<leader>geb', actions.build_project, {
    desc = 'Unreal: Build',
  })
  map('n', '<leader>gep', actions.package_project, {
    desc = 'Unreal: Package',
  })
  map('n', '<leader>gec', actions.cook_only, {
    desc = 'Unreal: Cook only',
  })
  map('n', '<leader>ges', actions.bootstrap_engine_checkout, {
    desc = 'Unreal: Bootstrap fresh engine checkout',
  })
  map('n', '<leader>gek', actions.package_plugin, {
    desc = 'Unreal: Package editor plugin',
  })
  map('n', '<leader>gel', actions.open_logs, {
    desc = 'Unreal: Open logs',
  })
end

function M.setup()
  M.setup_commands()
  M.setup_keymaps()
end

return M
