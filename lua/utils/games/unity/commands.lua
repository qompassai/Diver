-- #################################################################
-- /qompassai/Diver/lua/utils/games/unity/commands.lua
-- Qompass AI Unity Commands
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
local actions = require('utils.games.unity.actions')
local shared_util = require('utils.games.shared.util')

local M = {}

function M.setup_commands()
  local action_list = actions.get_actions()

  vim.api.nvim_create_user_command('Unity', function()
    actions.show_menu()
  end, { desc = 'Open Unity action menu' })

  vim.api.nvim_create_user_command('UnityAction', function(opts)
    actions.run_action_by_id(opts.args)
  end, {
    nargs = 1,
    complete = function(arg_lead)
      return shared_util.get_action_ids(action_list, arg_lead)
    end,
    desc = 'Run a Unity action by id',
  })

  for i = 1, #action_list do
    local action = action_list[i]
    local command_name = 'Unity' .. shared_util.snake_to_pascal(action.id)
    vim.api.nvim_create_user_command(command_name, function()
      actions.run_action(action)
    end, { desc = action.label })
  end
end

function M.setup_keymaps()
  local map = vim.keymap.set
  map('n', '<leader>gue', actions.open_editor, { desc = 'Unity: Open editor' })
  map('n', '<leader>gub', actions.build_project, { desc = 'Unity: Build' })
  map('n', '<leader>gut', actions.run_tests, { desc = 'Unity: Run tests' })
  map('n', '<leader>gul', actions.open_editor_log, { desc = 'Unity: Open Editor.log' })
  map('n', '<leader>gum', actions.build_target_matrix, { desc = 'Unity: Build target matrix' })
  map('n', '<leader>gup', actions.packages_list, { desc = 'Unity: List packages' })
  map('n', '<leader>gua', actions.packages_add, { desc = 'Unity: Add package' })
end

function M.setup()
  M.setup_commands()
  M.setup_keymaps()
end

return M
