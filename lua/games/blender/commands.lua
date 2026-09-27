-- #################################################################
-- /qompassai/Diver/lua/games/blender/commands.lua
-- Qompass AI Blender Commands
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
local actions = require('games.blender.actions')
local shared_util = require('games.shared.util')

local M = {}

function M.setup_commands()
    local action_list = actions.get_actions()

    vim.api.nvim_create_user_command('Blender', function()
        actions.show_menu()
    end, { desc = 'Open Blender action menu' })

    vim.api.nvim_create_user_command('BlenderAction', function(opts)
        actions.run_action_by_id(opts.args)
    end, {
        nargs = 1,
        complete = function(arg_lead)
            return shared_util.get_action_ids(action_list, arg_lead)
        end,
        desc = 'Run a Blender action by id',
    })

    vim.api.nvim_create_user_command('BlenderRender', function()
        actions.render_still()
    end, { desc = 'Blender: render a still frame headless' })

    vim.api.nvim_create_user_command('BlenderTurntable', function()
        actions.render_turntable()
    end, { desc = 'Blender: render a camera turntable' })

    vim.api.nvim_create_user_command('BlenderExport', function(opts)
        if opts.args == 'fbx' then
            actions.export_fbx()
        else
            actions.export_glb()
        end
    end, {
        nargs = '?',
        complete = function()
            return { 'glb', 'fbx' }
        end,
        desc = 'Blender: export glTF (.glb) or FBX (.fbx)',
    })

    vim.api.nvim_create_user_command('BlenderSprites', function()
        actions.bake_sprites()
    end, { desc = 'Blender: bake a sprite sheet + JSON manifest' })

    vim.api.nvim_create_user_command('BlenderBatch', function()
        actions.batch_render()
    end, { desc = 'Blender: batch an operation over a .blend directory' })

    for i = 1, #action_list do
        local action = action_list[i]
        local command_name = 'Blender' .. shared_util.snake_to_pascal(action.id)

        if vim.fn.exists(':' .. command_name) ~= 2 then
            vim.api.nvim_create_user_command(command_name, function()
                actions.run_action(action)
            end, { desc = action.label })
        end
    end
end

function M.setup_keymaps()
    local map = vim.keymap.set

    map('n', '<leader>gbr', actions.render_still, {
        desc = 'Blender: Render still',
    })
    map('n', '<leader>gbt', actions.render_turntable, {
        desc = 'Blender: Render turntable',
    })
    map('n', '<leader>gbg', actions.export_glb, {
        desc = 'Blender: Export glTF (.glb)',
    })
    map('n', '<leader>gbf', actions.export_fbx, {
        desc = 'Blender: Export FBX (.fbx)',
    })
    map('n', '<leader>gbs', actions.bake_sprites, {
        desc = 'Blender: Bake sprite sheet',
    })
    map('n', '<leader>gbb', actions.batch_render, {
        desc = 'Blender: Batch over .blend directory',
    })
end

function M.setup()
    M.setup_commands()
    M.setup_keymaps()
end

return M
