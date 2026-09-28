-- #################################################################
-- /qompassai/Diver/lua/games/tic80/init.lua
-- Qompass AI TIC-80 Native Dev Loop
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
--- Native TIC-80 dev loop for the free build: run a cart or script file,
--- and optionally restart it every time a watched Lua file is saved.
--- This reproduces the PRO "external editor" workflow (save in Neovim,
--- TIC-80 picks up the change) without the PRO binary.
---
--- Typical setup: build sprites and music in TIC-80's editors, save the
--- cart as `game.tic`, and reduce its built-in code to one shim line:
--- `dofile('/home/phaedrus/tic80/game.lua')`. Edit `game.lua` in Neovim;
--- each save restarts the cart, the shim re-executes, and the fresh code
--- loads. Resources stay in the `.tic`, code stays in plain Lua files.
--- `:Tic80NewCart` scaffolds exactly this layout.
---
--- Full surface: `:Tic80` opens the action menu (export builds/media via
--- the verified `--cli --cmd` console chains, PNG sprite-sheet import from
--- voidsprite, music-track WAV export). Music has no external import path
--- upstream: compose in the tracker (F5). Screenshots/GIFs are F8/F9
--- in-game hotkeys; TIC-80 exposes no CLI capture flags.
---@module 'games.tic80'

local config = require('games.tic80.config')
local util = require('games.tic80.util')
local actions = require('games.tic80.actions')
local commands = require('games.tic80.commands')

local M = {}

M.config = config
M.util = util
M.actions = actions
M.commands = commands

---@type integer?
local watch_group = nil

---@return string? Binary name when executable, nil when tic80 is unavailable.
function M.find_binary()
    return util.find_binary()
end

---Run a cart (.tic) or script (.lua), stopping the previous run first.
---@param file string Cart or script path to hand to tic80.
---@return boolean ok False when the path is empty or no binary is available.
function M.run(file)
    return actions.run_cart(file)
end

---Stop the running cart, if any.
function M.stop()
    actions.stop_cart()
end

---@return boolean enabled The watch state after toggling.
function M.toggle_watch()
    return actions.toggle_watch()
end

---@param opts games.tic80.Options?
function M.setup(opts)
    config.resolve(opts)

    if watch_group ~= nil then
        vim.api.nvim_del_augroup_by_id(watch_group)
        watch_group = nil
    end
    watch_group = vim.api.nvim_create_augroup('games.tic80', { clear = true })

    if #config.current.dirs > 0 then
        vim.api.nvim_create_autocmd('BufWritePost', {
            group = watch_group,
            callback = function(args)
                if not actions.watch_enabled or not config.current.auto_restart then
                    return
                end
                local saved = args.match
                if saved == nil or saved == '' then
                    return
                end
                local path = vim.fs.normalize(vim.fn.expand(saved))
                if util.is_under_watched_dir(path) and path:sub(-4) == '.lua' then
                    actions.run_cart(path)
                end
            end,
            desc = 'TIC-80: restart the cart when a watched Lua file is saved',
        })
    end

    vim.api.nvim_create_autocmd('VimLeavePre', {
        group = watch_group,
        callback = function()
            actions.stop_cart()
        end,
        desc = 'TIC-80: stop the running cart when Neovim exits',
    })

    commands.setup()
end

M.show_menu = actions.show_menu
M.run_action_by_id = actions.run_action_by_id

return M
