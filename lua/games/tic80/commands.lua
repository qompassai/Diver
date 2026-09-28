-- #################################################################
-- /qompassai/Diver/lua/games/tic80/commands.lua
-- Qompass AI TIC-80 Commands
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
--- User commands for TIC-80: `:Tic80` menu, `:Tic80Action <id>`, one
--- `:Tic80<Id>` per action, plus the legacy `:Tic80Run`/`:Tic80Stop`/
--- `:Tic80Watch` commands preserved from the original module.
---@module 'games.tic80.commands'

local actions = require('games.tic80.actions')
local shared_util = require('games.shared.util')

local M = {}

function M.setup_commands()
    local action_list = actions.get_actions()

    vim.api.nvim_create_user_command('Tic80', function()
        actions.show_menu()
    end, { desc = 'Open TIC-80 action menu' })

    vim.api.nvim_create_user_command('Tic80Action', function(cmd_opts)
        actions.run_action_by_id(cmd_opts.args)
    end, {
        nargs = 1,
        complete = function(arg_lead)
            return shared_util.get_action_ids(action_list, arg_lead)
        end,
        desc = 'Run a TIC-80 action by id',
    })

    for i = 1, #action_list do
        local action = action_list[i]
        local command_name = 'Tic80' .. shared_util.snake_to_pascal(action.id)
        vim.api.nvim_create_user_command(command_name, function()
            actions.run_action(action)
        end, { desc = action.label })
    end

    -- Legacy commands from the original single-file module: preserved so
    -- existing muscle memory and scripts keep working.
    vim.api.nvim_create_user_command('Tic80Run', function(cmd_opts)
        local target = cmd_opts.args
        if target == '' then
            target = vim.api.nvim_buf_get_name(0)
        end
        actions.run_cart(target)
    end, {
        nargs = '?',
        complete = 'file',
        force = true,
        desc = 'TIC-80: run a cart (.tic) or script (.lua); defaults to the current file',
    })

    vim.api.nvim_create_user_command('Tic80Stop', function()
        actions.stop_cart()
    end, {
        force = true,
        desc = 'TIC-80: stop the running cart',
    })

    vim.api.nvim_create_user_command('Tic80Watch', function()
        local enabled = actions.toggle_watch()
        vim.notify(
            'games.tic80: auto-restart on save ' .. (enabled and 'enabled' or 'disabled'),
            vim.log.levels.INFO
        )
    end, {
        force = true,
        desc = 'TIC-80: toggle auto-restart on save',
    })
end

function M.setup_keymaps()
    local map = vim.keymap.set
    map('n', '<leader>gtm', actions.show_menu, {
        desc = 'TIC-80: Action menu',
    })
    map('n', '<leader>gte', actions.open_editors, {
        desc = 'TIC-80: Open built-in editors',
    })
    map('n', '<leader>gti', actions.import_spritesheet, {
        desc = 'TIC-80: Import PNG sprite sheet',
    })
    map('n', '<leader>gtx', actions.export_build, {
        desc = 'TIC-80: Export build',
    })
end

function M.setup()
    M.setup_commands()
    M.setup_keymaps()
end

return M
