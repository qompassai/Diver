-- #################################################################
-- /qompassai/Diver/lua/games/voidsprite/actions.lua
-- Qompass AI Voidsprite Actions
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
--- GUI launch actions for voidsprite. The only verified CLI surface is
--- `voidsprite <file>` (upstream .desktop `Exec=voidsprite %U`); there is
--- no documented headless/batch mode, so export stays inside the editor.
--- The TIC-80 round trip: draw in voidsprite, save as PNG, then run
--- `import_spritesheet` (here or `:Tic80ImportSpritesheet`) to pull the
--- PNG into the cart's sprite memory.
---@module 'games.voidsprite.actions'

local config = require('games.voidsprite.config')
local util = require('games.voidsprite.util')
local shared_util = require('games.shared.util')

local notify = vim.notify
local levels = vim.log.levels

local M = {}

---Launch voidsprite on the current sprite buffer, or bare for a new session.
function M.open_in_editor()
    local bin = util.require_binary()
    if bin == nil then
        return
    end
    local sprite = vim.api.nvim_buf_get_name(0)
    local cmd = { bin }
    if util.is_sprite_file(sprite) then
        cmd[#cmd + 1] = sprite
    end
    vim.fn.jobstart(cmd, { detach = true })
    notify('Voidsprite: editor launching', levels.INFO)
end

---Launch a fresh voidsprite session (no file).
function M.new_session()
    local bin = util.require_binary()
    if bin == nil then
        return
    end
    vim.fn.jobstart({ bin }, { detach = true })
    notify('Voidsprite: new session launching', levels.INFO)
end

---Bridge into TIC-80: import a PNG sprite sheet (saved from voidsprite)
---into the current cart's sprite memory.
function M.import_into_tic80()
    local ok, tic80_actions = pcall(require, 'games.tic80.actions')
    if not ok then
        notify('Voidsprite: games.tic80.actions is unavailable.', levels.ERROR)
        return
    end
    tic80_actions.import_spritesheet()
end

function M.describe_environment()
    notify(table.concat({
        'Voidsprite binary: ' .. (util.find_binary() or 'not found'),
        'Current buffer sprite: ' .. tostring(util.is_sprite_file(vim.api.nvim_buf_get_name(0))),
        'TIC-80 bridge: draw here, save as PNG, then import into the cart sprite memory.',
    }, '\n'), levels.INFO)
end

---@return table[] Action descriptors for the menu/command surface.
function M.get_actions()
    return {
        {
            id = 'open_in_editor',
            label = 'Open in voidsprite',
            group = 'Editor',
            run = M.open_in_editor,
        },
        {
            id = 'new_session',
            label = 'New voidsprite session',
            group = 'Editor',
            run = M.new_session,
        },
        {
            id = 'describe_environment',
            label = 'Describe environment',
            group = 'Editor',
            run = M.describe_environment,
        },
        {
            id = 'import_into_tic80',
            label = 'Import PNG sprite sheet into TIC-80 cart',
            group = 'TIC-80',
            run = M.import_into_tic80,
        },
    }
end

---@param action table Action descriptor from get_actions().
function M.run_action(action)
    action.run()
end

---@param id string Action id from get_actions().
function M.run_action_by_id(id)
    local map = shared_util.build_action_map(M.get_actions())
    local action = map[id]
    if action == nil then
        notify('Unknown Voidsprite action: ' .. id, levels.ERROR)
        return
    end
    M.run_action(action)
end

function M.show_menu()
    require('games.shared.ui').select_root_menu(M.get_actions(), M.run_action, {
        group_order = config.group_order,
        prompt = 'Select Voidsprite action:',
    })
end

return M
