-- #################################################################
-- /qompassai/Diver/lua/utils/games/aseprite/commands.lua
-- Qompass AI Aseprite Commands
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
local actions = require('utils.games.aseprite.actions')
local shared_util = require('utils.games.shared.util')

local M = {}

function M.setup_commands()
  local action_list = actions.get_actions()

  vim.api.nvim_create_user_command('Aseprite', function()
    actions.show_menu()
  end, { desc = 'Open Aseprite action menu' })

  vim.api.nvim_create_user_command('AsepriteAction', function(opts)
    actions.run_action_by_id(opts.args)
  end, {
    nargs = 1,
    complete = function(arg_lead)
      return shared_util.get_action_ids(action_list, arg_lead)
    end,
    desc = 'Run an Aseprite action by id',
  })

  for i = 1, #action_list do
    local action = action_list[i]
    local command_name = 'Aseprite' .. shared_util.snake_to_pascal(action.id)
    vim.api.nvim_create_user_command(command_name, function()
      actions.run_action(action)
    end, { desc = action.label })
  end
end

function M.setup_keymaps()
  local map = vim.keymap.set
  map('n', '<leader>gae', actions.open_in_editor, { desc = 'Aseprite: Open editor' })
  map('n', '<leader>gan', actions.new_sprite, { desc = 'Aseprite: New sprite' })
  map('n', '<leader>gas', actions.export_sprite_sheet, { desc = 'Aseprite: Export sprite sheet' })
  map('n', '<leader>gag', actions.export_gif, { desc = 'Aseprite: Export GIF' })
  map('n', '<leader>gar', actions.run_script, { desc = 'Aseprite: Run script' })
end

function M.setup()
  M.setup_commands()
  M.setup_keymaps()
end

return M
