-- #################################################################
-- /qompassai/Diver/lua/games/robocode/health.lua
-- Qompass AI Robocode Health (:checkhealth games.robocode)
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
-- checkhealth provider for games.robocode: Java/JDK presence, Robocode
-- install-root resolution, launcher-wrapper sanity (the AUR 1.11.1
-- wrapper is a known zero-byte stub -- see config.lua), and the
-- user-owned robot development directory.
--
-- NOTE: games.robocode is required lazily here because init.lua requires
-- this module -- a top-level require would capture a half-initialized
-- table.
local M = {}

function M.check()
    local robocode = require('games.robocode')
    local health = vim.health
    health.start('games.robocode')

    if robocode.find_java() ~= nil then
        health.ok('java on PATH')
    else
        health.error(
            'java not found on PATH',
            'Install a JDK: the AUR package needs java-environment.'
        )
    end

    if robocode.find_javac() ~= nil then
        health.ok('javac on PATH (robot compilation available)')
    else
        health.warn(
            'javac not found on PATH',
            'Install a JDK to compile robots; GUI and precompiled battles still work.'
        )
    end

    local root = robocode.find_install_root()
    if root == nil then
        health.error(
            'Robocode install root not found',
            'Install aur/robocode, or point $ROBOCODE_HOME at a tree holding libs/robocode.jar.'
        )
        return
    end
    health.ok('install root: ' .. root)

    local wrapper = robocode.find_binary()
    if wrapper ~= nil then
        health.ok('launcher wrapper usable: ' .. wrapper)
    elseif vim.fn.executable('robocode') == 1 then
        health.error(
            'robocode wrapper on PATH is a zero-byte stub',
            'aur/robocode 1.11.1-1 ships a broken /usr/bin/robocode; '
                .. 'this module launches via java from '
                .. root
                .. ' instead, so battles still work.'
        )
    else
        health.warn(
            'no robocode wrapper on PATH',
            'Not required: this module launches via java from ' .. root .. ' directly.'
        )
    end

    local dev_dir = robocode.dev_robots_dir()
    if vim.fn.isdirectory(dev_dir) == 1 then
        health.ok('robot dev dir: ' .. dev_dir)
    else
        health.warn(
            'robot dev dir missing: ' .. dev_dir,
            'Created automatically by :RobocodeNew; battles need compiled robots there.'
        )
    end

    local config_dir = robocode.config_dir()
    if vim.fn.isdirectory(config_dir) == 1 then
        health.ok('config dir: ' .. config_dir)
    else
        health.info('config dir not created yet: ' .. config_dir .. ' (created on first launch)')
    end
end

return M
