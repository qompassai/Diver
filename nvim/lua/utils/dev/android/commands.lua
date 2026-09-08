-- #################################################################
-- /qompassai/lua/utils/dev/android/commands.lua
-- Qompass AI Commands
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
local M = {}
local api = vim.api
local map = vim.keymap.set
local actions = require('utils.dev.android.actions')
function M.setup_commands()
  local action_list = actions.get_actions()

  api.nvim_create_user_command('Android', function()
    actions.show_menu()
  end, {
    desc = 'Open Android action menu',
  })

  api.nvim_create_user_command('AndroidAction', function(opts)
    actions.run_action_by_id(opts.args)
  end, {
    nargs = 1,
    complete = function(arg_lead)
      return actions.get_action_ids(action_list, arg_lead)
    end,
    desc = 'Run an Android action by id',
  })
  for i = 1, #action_list do
    local action = action_list[i]
    local command_name = 'Android' .. actions.snake_to_pascal(action.id)

    api.nvim_create_user_command(command_name, function()
      actions.run_action(action)
    end, {
      desc = action.label,
    })
  end
end
function M.setup_keymaps()
  map('n', '<leader>ar', function()
    actions.run_action_by_id('run_debug')
  end, {
    desc = 'Android: Run debug',
  })
  map('n', '<leader>ac', function()
    actions.run_action_by_id('clean')
  end, {
    desc = 'Android: Clean project',
  })
  map('n', '<leader>ab', function()
    actions.run_action_by_id('build_release')
  end, {
    desc = 'Android: Build release',
  })
  map('n', '<leader>ae', function()
    actions.run_action_by_id('start_emulator')
  end, {
    desc = 'Android: Start emulator',
  })
  map('n', '<leader>ax', function()
    actions.run_action_by_id('stop_emulator')
  end, {
    desc = 'Android: Stop emulator',
  })

  map('n', '<leader>as', function()
    actions.run_action_by_id('capture_screen')
  end, {
    desc = 'Android: Capture screen',
  })
end

function M.setup()
  M.setup_commands()
  M.setup_keymaps()
end

return M
