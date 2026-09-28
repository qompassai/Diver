-- #################################################################
-- /qompassai/Diver/lua/games/robocode/init.lua
-- Qompass AI Robocode Platform Core
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
--- Robocode dev loop: scaffold Java robots, compile them with javac, and
--- run headless battles from Neovim. Plain-language version: Robocode is
--- the "program a battle tank" game -- you write a robot's brain in Java
--- and it fights other robots. This module finds your Java and Robocode
--- install, then launches battles the same way Robocode's own console
--- usage documents (robowiki: Robocode/Console_Usage).
---
--- Launch strategy: the AUR wrapper is skipped on purpose (see config.lua:
--- aur/robocode 1.11.1-1 ships a zero-byte /usr/bin/robocode). Battles
--- run as `java -cp <root>/libs/* robocode.Robocode -battle <file>
--- -nodisplay -results <file>` with the JVM flags from upstream's
--- robocode.sh, so headless and GUI launches behave identically to the
--- documented console usage.
---@module 'games.robocode'

local shared_util = require('games.shared.util')

local M = {}

M.config = require('games.robocode.config')
M.actions = require('games.robocode.actions')
M.commands = require('games.robocode.commands')
M.health = require('games.robocode.health')

---@return string? 'java' when executable on PATH, nil otherwise.
function M.find_java()
    if vim.fn.executable('java') == 1 then
        return 'java'
    end
    return nil
end

---@return string? 'javac' when executable on PATH, nil otherwise.
function M.find_javac()
    if vim.fn.executable('javac') == 1 then
        return 'javac'
    end
    return nil
end

---Resolve the Robocode install root: $ROBOCODE_HOME (or
---$NVIM_ROBOCODE_HOME) first, then the packaged defaults. A candidate
---only counts when libs/robocode.jar exists under it.
---@return string? install root, nil when no candidate holds the jar.
function M.find_install_root()
    ---@type string[]
    local candidates = {}
    local from_env = shared_util.env_first(M.config.env_names)
    if from_env ~= nil then
        candidates[#candidates + 1] = from_env
    end
    for _, root in ipairs(M.config.install_roots) do
        candidates[#candidates + 1] = root
    end
    for _, candidate in ipairs(candidates) do
        local expanded = vim.fn.expand(candidate)
        if vim.fn.filereadable(expanded .. '/libs/robocode.jar') == 1 then
            return expanded
        end
    end
    return nil
end

---Return the `robocode` launcher wrapper name when it is usable.
---A zero-size executable is the known-broken AUR 1.11.1 stub (see
---config.lua) and is treated as unavailable rather than success.
---@return string? wrapper name, nil when missing or a zero-byte stub.
function M.find_binary()
    for _, name in ipairs(M.config.binaries) do
        if vim.fn.executable(name) == 1 then
            local size = vim.fn.getfsize(vim.fn.exepath(name))
            if size > 0 then
                return name
            end
        end
    end
    return nil
end

---Resolved user-owned robot development directory (expanded, normalized).
---@return string
function M.dev_robots_dir()
    return vim.fs.normalize(vim.fn.expand(M.config.dev_robots_dir))
end

---Resolved user-writable Robocode config directory:
---$XDG_CONFIG_HOME/robocode, falling back to ~/.config/robocode.
---Robocode writes its settings, robot database, and screenshots under
---its working directory, so pointing the working directory here keeps
---the (often root-owned) install dir out of the write path.
---@return string
function M.config_dir()
    local xdg = vim.env.XDG_CONFIG_HOME
    local base = vim.fn.expand('~/.config')
    if xdg ~= nil and xdg ~= '' then
        base = xdg
    end
    return vim.fs.normalize(base .. '/robocode')
end

---Resolved directory for generated .battle specs (expanded, normalized).
---@return string
function M.battle_dir()
    return vim.fs.normalize(vim.fn.expand(M.config.battle_dir))
end

---@class games.robocode.LaunchOptions
---@field headless boolean run with -nodisplay (no GUI)
---@field battle_file string? .battle spec handed to -battle
---@field results_file string? path handed to -results
---@field tps integer? turns per second (headless only)
---@field robot_path string? -DROBOTPATH override for the robot repository

---@class games.robocode.Launch
---@field argv string[] process argv (no shell involved)
---@field cwd string working directory for the JVM

---Build a Robocode launch from the documented console usage. Returns
---nil + reason when java or the install root is unavailable, so callers
---report the gap instead of inventing a launch. Ensures the user config
---dir exists (Robocode writes settings under its working directory).
---@param opts games.robocode.LaunchOptions
---@return games.robocode.Launch? launch
---@return string? err
function M.build_launch(opts)
    local java = M.find_java()
    if java == nil then
        return nil, 'java not found on PATH (the AUR package needs java-environment)'
    end
    local root = M.find_install_root()
    if root == nil then
        return nil, 'Robocode install root not found (checked $ROBOCODE_HOME and /opt/robocode)'
    end

    local config_dir = M.config_dir()
    vim.fn.mkdir(config_dir, 'p')

    ---@type string[]
    local argv = {
        java,
        '-cp',
        root .. '/libs/*',
        '-Xmx' .. M.config.jvm_heap,
        '--add-opens=java.base/sun.net.www.protocol.jar=ALL-UNNAMED',
        '--add-opens=java.base/java.lang.reflect=ALL-UNNAMED',
        '--add-opens=java.desktop/javax.swing.text=ALL-UNNAMED',
        '--add-opens=java.desktop/sun.awt=ALL-UNNAMED',
        '-DWORKINGDIRECTORY=' .. config_dir,
    }
    if opts.robot_path ~= nil then
        argv[#argv + 1] = '-DROBOTPATH=' .. opts.robot_path
    end
    argv[#argv + 1] = 'robocode.Robocode'
    if opts.battle_file ~= nil then
        argv[#argv + 1] = '-battle'
        argv[#argv + 1] = opts.battle_file
    end
    if opts.headless then
        argv[#argv + 1] = '-nodisplay'
    end
    if opts.tps ~= nil then
        argv[#argv + 1] = '-tps'
        argv[#argv + 1] = tostring(opts.tps)
    end
    if opts.results_file ~= nil then
        argv[#argv + 1] = '-results'
        argv[#argv + 1] = opts.results_file
    end

    return { argv = argv, cwd = root }
end

function M.setup()
    M.commands.setup()
end

M.show_menu = M.actions.show_menu
M.run_action_by_id = M.actions.run_action_by_id

return M
