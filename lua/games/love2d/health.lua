-- #################################################################
-- /qompassai/Diver/lua/games/love2d/health.lua
-- Qompass AI LÖVE2D Health (:checkhealth games.love2d)
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
-- checkhealth provider for games.love2d: binary resolution, version against
-- the pinned 11.5 release, API definition presence, library catalog
-- integrity, and the optional Butler hook.
local config = require('games.love2d.config')
local versions = require('games.love2d.versions')
local libs = require('games.love2d.libs')

local M = {}

function M.check()
    vim.health.start('games.love2d')

    local bin = versions.find_binary()
    if bin == nil then
        vim.health.error(
            'love binary not found',
            'Run :Love2dInstall to fetch LÖVE ' .. versions.VERSION .. ', or set LOVE_BIN / add love to $PATH.'
        )
        return
    end
    vim.health.ok('binary: ' .. bin)

    local installed = versions.installed_version()
    if installed == nil then
        vim.health.error('could not determine love version from --version output')
    elseif installed == versions.VERSION then
        vim.health.ok('version ' .. installed .. ' (pinned ' .. versions.VERSION .. ')')
    else
        vim.health.warn(('version %s does not match pinned %s'):format(installed, versions.VERSION))
    end

    local apidefs = vim.fn.globpath(config.apidefs_dir, 'love.lua', false, true)
    if #apidefs > 0 then
        vim.health.ok('API definitions: ' .. apidefs[1])
    else
        vim.health.error('API definitions missing: no love.lua under ' .. config.apidefs_dir)
    end

    local catalog_ok, problems = libs.catalog_integrity()
    if catalog_ok then
        vim.health.ok(('library catalog: %d entries, all pinned + checksummed'):format(#libs.CATALOG))
    else
        vim.health.error('library catalog integrity failed:\n- ' .. table.concat(problems, '\n- '))
    end

    for _, key in ipairs({ 'linux', 'win64', 'macos' }) do
        local artifact = versions.ARTIFACTS[key]
        if versions.artifact_path(key) ~= nil then
            vim.health.ok(('release artifact cached: %s'):format(artifact.file))
        else
            vim.health.warn(('release artifact not cached: %s (%s)'):format(artifact.file, key))
        end
    end

    if vim.fn.executable(config.butler.binary) == 1 then
        vim.health.ok('itch.io butler on PATH (push hook available)')
    else
        vim.health.warn('itch.io butler not on PATH (push hook unavailable)')
    end
end

return M
