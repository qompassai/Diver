-- #################################################################
-- /qompassai/Diver/lua/games/blender/health.lua
-- Qompass AI Blender Health
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
-- checkhealth provider for games.blender: binary resolution,
-- version against the pinned/minimum releases, and proof that the
-- Python interpreter inside Blender itself executes.
local config = require('games.blender.config')
local versions = require('games.blender.versions')

local M = {}

local PYTHON_PROBE_TIMEOUT_MS = 60000
local PYTHON_PROBE_MARKER = 'DIVER_BLENDER_PYTHON_OK'

---@return boolean ok
local function probe_blender_python(bin)
    local result, spawn_err = versions.system_wait({
        bin,
        '-b',
        '--python-expr',
        'import sys; print("' .. PYTHON_PROBE_MARKER .. ' " + sys.version.split()[0])',
    }, { text = true, timeout = PYTHON_PROBE_TIMEOUT_MS })

    if result == nil then
        vim.health.error('embedded Python probe could not spawn blender: ' .. tostring(spawn_err))
        return false
    end

    if result.code ~= 0 then
        return false
    end

    local combined = (result.stdout or '') .. '\n' .. (result.stderr or '')

    return combined:find(PYTHON_PROBE_MARKER, 1, true) ~= nil
end

function M.check()
    vim.health.start('games.blender')

    local bin = versions.binary_path()

    if bin == nil then
        vim.health.error(
            'blender binary not found',
            (
                'Install the %s Linux x86_64 tarball from https://www.blender.org/download/ under %s/<version>/, '
                .. 'or set BLENDER_BIN.'
            ):format(config.pinned_version, config.tools_dir)
        )
        return
    end

    vim.health.ok('binary: ' .. bin)

    local installed, version_err = versions.installed_version(bin)

    if installed == nil then
        vim.health.error('could not determine blender version: ' .. tostring(version_err))
        return
    end

    local parts = versions.parse_version(installed)
    local minimum = versions.parse_version(config.min_version)

    if parts ~= nil and minimum ~= nil and versions.version_at_least(parts, minimum) then
        local msg = ('blender %s >= %s (pinned %s)'):format(installed, config.min_version, config.pinned_version)
        vim.health.ok(msg)
    else
        vim.health.warn(('version %s is older than the minimum %s'):format(installed, config.min_version))
    end

    if probe_blender_python(bin) then
        vim.health.ok('embedded Python executes inside blender')
    else
        vim.health.error('embedded Python probe failed -- --python-expr did not run')
    end
end

return M
