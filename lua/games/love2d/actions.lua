-- #################################################################
-- /qompassai/Diver/lua/games/love2d/actions.lua
-- Qompass AI LÖVE2D Actions
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
-- Interactive LÖVE2D actions: run/watch/package/release the game under the
-- cursor's project, vendor catalog libraries, and attach the dev hooks.
-- Orchestration lives in dev/package/release/libs; this module only wires
-- prompts to those functions.
local versions = require('games.love2d.versions')
local package = require('games.love2d.package')
local release = require('games.love2d.release')
local libs = require('games.love2d.libs')
local dev = require('games.love2d.dev')
local shared_util = require('games.shared.util')

local notify = vim.notify
local levels = vim.log.levels
local M = {}

---@param prompt string
---@param default string
---@return string? path (nil when the user cancels)
local function prompt_path(prompt, default)
    local picked = shared_util.trim(vim.fn.input(prompt, default, 'file'))
    if picked == '' then
        return nil
    end
    return picked
end

---@return string current working directory as the default project
local function default_project()
    return vim.fn.getcwd()
end

function M.run_game()
    local project = prompt_path('LÖVE2D project dir: ', default_project())
    if project == nil then
        return
    end
    local job = dev.run(project)
    if job ~= nil then
        notify('LÖVE2D: running ' .. project, levels.INFO)
    end
end

function M.watch_game()
    local project = prompt_path('LÖVE2D project dir: ', default_project())
    if project == nil then
        return
    end
    local ok, err = dev.watch(project)
    if not ok then
        notify('LÖVE2D: watch failed: ' .. tostring(err), levels.ERROR)
        return
    end
    local job = dev.run(project)
    if job ~= nil then
        notify('LÖVE2D: watching ' .. project .. ' (restart on change)', levels.INFO)
    end
end

function M.stop_game()
    dev.stop()
    notify('LÖVE2D: game stopped', levels.INFO)
end

function M.install_love()
    notify('LÖVE2D: installing LÖVE ' .. versions.VERSION .. ' ...', levels.INFO)
    vim.schedule(function()
        local bin, err = versions.ensure_installed()
        if bin == nil then
            notify('LÖVE2D: install failed: ' .. tostring(err), levels.ERROR)
        else
            notify('LÖVE2D: installed: ' .. bin, levels.INFO)
        end
    end)
end

function M.package_game()
    local project = prompt_path('LÖVE2D project dir: ', default_project())
    if project == nil then
        return
    end
    local out = prompt_path('Output .love: ', project .. '/game.love')
    if out == nil then
        return
    end
    local path, info = package.package(project, out)
    if path == nil then
        notify('LÖVE2D: packaging failed: ' .. tostring(info), levels.ERROR)
        return
    end
    notify(('LÖVE2D: packaged %s (%d files, %d bytes)'):format(path, info.entries, info.bytes), levels.INFO)
end

function M.release_game()
    local game_love = prompt_path('Game .love file: ', default_project() .. '/game.love')
    if game_love == nil then
        return
    end
    local dest_root = prompt_path('Release destination: ', default_project() .. '/releases')
    if dest_root == nil then
        return
    end
    local results = release.release(game_love, dest_root)
    for _, result in ipairs(results) do
        if result.ok then
            notify(('LÖVE2D: %s bundle -> %s'):format(result.target, result.path), levels.INFO)
        else
            notify(('LÖVE2D: %s failed: %s'):format(result.target, result.err), levels.ERROR)
        end
    end
end

function M.vendor_library()
    local keys = libs.keys()
    vim.ui.select(keys, { prompt = 'LÖVE2D library:' }, function(choice)
        if choice == nil then
            return
        end
        local dest = prompt_path('Vendor destination: ', default_project() .. '/lib')
        if dest == nil then
            return
        end
        local vendored, err = libs.vendor(choice, dest)
        if vendored == nil then
            notify('LÖVE2D: vendor failed: ' .. tostring(err), levels.ERROR)
            return
        end
        local entry = libs.get(choice)
        notify(('LÖVE2D: vendored %s (%d files). %s'):format(choice, #vendored, entry.require_hint), levels.INFO)
    end)
end

function M.setup_console()
    local project = prompt_path('LÖVE2D project dir: ', default_project())
    if project == nil then
        return
    end
    local ok, err = dev.setup_console(project)
    if not ok then
        notify('LÖVE2D: console hook failed: ' .. tostring(err), levels.ERROR)
    end
end

function M.setup_profiler()
    local project = prompt_path('LÖVE2D project dir: ', default_project())
    if project == nil then
        return
    end
    local ok, err = dev.setup_profiler(project)
    if not ok then
        notify('LÖVE2D: profiler hook failed: ' .. tostring(err), levels.ERROR)
    end
end

function M.doctor()
    vim.cmd('checkhealth games.love2d')
end

---@return table[] action list { id, label, run }
function M.get_actions()
    return {
        { id = 'run_game', label = 'Run game', run = M.run_game },
        { id = 'watch_game', label = 'Run + hot-reload on change', run = M.watch_game },
        { id = 'stop_game', label = 'Stop game', run = M.stop_game },
        { id = 'install_love', label = 'Install LÖVE ' .. versions.VERSION, run = M.install_love },
        { id = 'package_game', label = 'Package .love', run = M.package_game },
        { id = 'release_game', label = 'Release per-OS bundles', run = M.release_game },
        { id = 'vendor_library', label = 'Vendor a library', run = M.vendor_library },
        { id = 'setup_console', label = 'Attach debug console (lovebird)', run = M.setup_console },
        { id = 'setup_profiler', label = 'Attach profiler (loveprofiler)', run = M.setup_profiler },
        { id = 'doctor', label = 'Doctor (:checkhealth)', run = M.doctor },
    }
end

---@param action table
function M.run_action(action)
    local ok, err = pcall(action.run)
    if not ok then
        notify('LÖVE2D action failed: ' .. tostring(err), levels.ERROR)
    end
end

---@param id string
function M.run_action_by_id(id)
    local list = M.get_actions()
    for _, action in ipairs(list) do
        if action.id == id then
            M.run_action(action)
            return
        end
    end
    notify('LÖVE2D: unknown action: ' .. tostring(id), levels.ERROR)
end

function M.show_menu()
    require('games.shared.ui').select_root_menu(M.get_actions(), M.run_action, {
        prompt = 'LÖVE2D',
    })
end

return M
