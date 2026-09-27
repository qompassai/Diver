-- #################################################################
-- /qompassai/Diver/lua/games/love2d/commands.lua
-- Qompass AI LÖVE2D Commands
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
-- User commands and keymaps for games.love2d. Wires the action list from
-- actions.lua into :Love2d* commands and <leader>gl* keymaps.
local actions = require('games.love2d.actions')
local shared_util = require('games.shared.util')

local M = {}

function M.setup_commands()
    local action_list = actions.get_actions()

    vim.api.nvim_create_user_command('Love2d', function()
        actions.show_menu()
    end, { desc = 'Open LÖVE2D action menu' })

    vim.api.nvim_create_user_command('Love2dAction', function(opts)
        actions.run_action_by_id(opts.args)
    end, {
        nargs = 1,
        complete = function(arg_lead)
            return shared_util.get_action_ids(action_list, arg_lead)
        end,
        desc = 'Run a LÖVE2D action by id',
    })

    vim.api.nvim_create_user_command('LoveRun', function(opts)
        local dev = require('games.love2d.dev')
        local project = opts.args ~= '' and opts.args or vim.fn.getcwd()
        dev.run(project)
    end, {
        nargs = '?',
        complete = 'dir',
        desc = 'Run the LÖVE2D game through the managed binary',
    })

    vim.api.nvim_create_user_command('Love2dInstall', function()
        actions.install_love()
    end, { desc = 'Install the pinned LÖVE release' })

    vim.api.nvim_create_user_command('Love2dPackage', function()
        actions.package_game()
    end, { desc = 'Package the project into a deterministic .love' })

    vim.api.nvim_create_user_command('Love2dRelease', function()
        actions.release_game()
    end, { desc = 'Release per-OS bundles from a .love' })

    vim.api.nvim_create_user_command('Love2dStop', function()
        actions.stop_game()
    end, { desc = 'Stop the running LÖVE2D game' })

    for i = 1, #action_list do
        local action = action_list[i]
        local command_name = 'Love2d' .. shared_util.snake_to_pascal(action.id)

        if vim.fn.exists(':' .. command_name) ~= 2 then
            vim.api.nvim_create_user_command(command_name, function()
                actions.run_action(action)
            end, { desc = action.label })
        end
    end
end

function M.setup_keymaps()
    local map = vim.keymap.set

    map('n', '<leader>glr', actions.run_game, { desc = 'LÖVE2D: Run game' })
    map('n', '<leader>glw', actions.watch_game, { desc = 'LÖVE2D: Run + hot-reload' })
    map('n', '<leader>gls', actions.stop_game, { desc = 'LÖVE2D: Stop game' })
    map('n', '<leader>gli', actions.install_love, { desc = 'LÖVE2D: Install LÖVE' })
    map('n', '<leader>glp', actions.package_game, { desc = 'LÖVE2D: Package .love' })
    map('n', '<leader>gle', actions.release_game, { desc = 'LÖVE2D: Release bundles' })
    map('n', '<leader>glv', actions.vendor_library, { desc = 'LÖVE2D: Vendor library' })
    map('n', '<leader>glc', actions.setup_console, { desc = 'LÖVE2D: Debug console' })
    map('n', '<leader>glf', actions.setup_profiler, { desc = 'LÖVE2D: Profiler' })
    map('n', '<leader>gld', actions.doctor, { desc = 'LÖVE2D: Doctor' })
end

function M.setup()
    M.setup_commands()
    M.setup_keymaps()
end

return M
