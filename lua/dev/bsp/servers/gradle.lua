-- #################################################################
-- /qompassai/Diver/lua/bsp/servers/gradle.lua
-- Qompass AI Gradle
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
--- Gradle build server resolver for the native BSP client.
---
--- Plain-language version: Gradle is the build tool behind Android apps and
--- most JVM projects. Microsoft's build-server-for-gradle speaks BSP on
--- Gradle's behalf, so Neovim can ask it for build targets, compile, and
--- diagnostics instead of shelling out to `./gradlew` blindly. This module
--- only finds the project root and reads the `.bsp/*.json` connection card;
--- it never downloads or launches anything itself.
---
--- Upstream: https://github.com/microsoft/build-server-for-gradle
--- (Java implementation; upstream documents Java support — Kotlin/Android
--- projects build through the same Gradle model. Requires JDK 17+ to
--- build/launch the server itself.)
---
--- Dev-flow wiring: `dev.apps.android` (the `:Android` suite) detects this same
--- root via `dev.apps.android.gradle`; its `bsp_status` action reports whether a
--- connection card exists here and offers `:BspStart` when it does.
---@module 'dev.bsp.servers.gradle'

local util = require('dev.bsp.servers.util')

local M = {}

local ROOT_MARKERS = {
    'settings.gradle',
    'settings.gradle.kts',
    'build.gradle',
    'build.gradle.kts',
}

---@param root string
---@return boolean
function M.is_gradle_project(root)
    if type(root) ~= 'string' or root == '' then
        return false
    end

    for _, marker in ipairs(ROOT_MARKERS) do
        local stat = vim.uv.fs_stat(vim.fs.joinpath(root, marker))
        if stat and stat.type == 'file' then
            return true
        end
    end

    return false
end

---@return string[]
function M.markers()
    return vim.deepcopy(ROOT_MARKERS)
end

---@param bufnr? integer
---@return string|nil
function M.root(bufnr)
    return util.root_from_markers(bufnr, ROOT_MARKERS)
end

---@param root string
---@param preferred_name? string
---@return QompassBspConnection|nil, string|nil
function M.connection(root, preferred_name)
    if not M.is_gradle_project(root) then
        return nil, 'Not a Gradle project: ' .. root
    end

    return util.find_connection(root, preferred_name)
end

---@param connection QompassBspConnection
---@return boolean, string|nil
function M.executable(connection)
    if type(connection) ~= 'table' or type(connection.argv) ~= 'table' then
        return false, 'The BSP connection is malformed'
    end

    return util.executable_from_argv(connection.argv)
end

return M
