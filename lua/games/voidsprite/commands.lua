-- #################################################################
-- /qompassai/Diver/lua/games/voidsprite/commands.lua
-- Qompass AI Voidsprite Commands
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
--- User commands for voidsprite: `:Voidsprite` menu, `:VoidspriteAction
--- <id>`, and one `:Voidsprite<Id>` per action.
---@module 'games.voidsprite.commands'

local actions = require('games.voidsprite.actions')
local shared_util = require('games.shared.util')

local M = {}

function M.setup_commands()
    local action_list = actions.get_actions()

    vim.api.nvim_create_user_command('Voidsprite', function()
        actions.show_menu()
    end, { desc = 'Open Voidsprite action menu' })

    vim.api.nvim_create_user_command('VoidspriteAction', function(cmd_opts)
        actions.run_action_by_id(cmd_opts.args)
    end, {
        nargs = 1,
        complete = function(arg_lead)
            return shared_util.get_action_ids(action_list, arg_lead)
        end,
        desc = 'Run a Voidsprite action by id',
    })

    for i = 1, #action_list do
        local action = action_list[i]
        local command_name = 'Voidsprite' .. shared_util.snake_to_pascal(action.id)
        vim.api.nvim_create_user_command(command_name, function()
            actions.run_action(action)
        end, { desc = action.label })
    end
end

function M.setup_keymaps()
    local map = vim.keymap.set
    map('n', '<leader>gvm', actions.show_menu, {
        desc = 'Voidsprite: Action menu',
    })
    map('n', '<leader>gve', actions.open_in_editor, {
        desc = 'Voidsprite: Open in editor',
    })
    map('n', '<leader>gvi', actions.import_into_tic80, {
        desc = 'Voidsprite: Import PNG sprite sheet into TIC-80 cart',
    })
end

function M.setup()
    M.setup_commands()
    M.setup_keymaps()
end

return M
