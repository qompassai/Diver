-- #################################################################
-- /qompassai/lua/dev/android/bsp.lua
-- Qompass AI Android BSP integration
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
--- BSP-aware build entry points for the Android suite.
---
--- Plain-language version: when Microsoft's build-server-for-gradle is
--- configured for a project (a .bsp/*.json connection card), Neovim can
--- compile through the Build Server Protocol instead of shelling out to
--- ./gradlew — faster incremental builds, real diagnostics. When no BSP
--- server is present or running, everything here falls back to the plain
--- Gradle CLI. Nothing in this module errors when BSP is absent.
---
--- Depends on lua/bsp/ (the native BSP client) and
--- lua/bsp/servers/gradle.lua (the Gradle resolver). Both are loaded
--- lazily and guarded with pcall.

local M = {}

local levels = vim.log.levels
local notify = vim.notify

---@class AndroidBspStatus
---@field ok boolean True when a usable connection card exists.
---@field root? string Project root the card was found under.
---@field connection? string Connection card name.
---@field reason? string Why not available.
---@field hint? string How to make it available.

---Load the BSP client without failing when it is absent.
---@return table? client The 'bsp' module, or nil.
local function load_client()
    local ok, client = pcall(require, 'bsp')
    if not ok or type(client) ~= 'table' then
        return nil
    end

    return client
end

---Check the Gradle BSP connection card for a project.
---@param root_dir? string Project root (defaults to the resolver's root).
---@return AndroidBspStatus
function M.status(root_dir)
    local ok, gradle = pcall(require, 'dev.apps.android.gradle')
    if not ok or type(gradle) ~= 'table' or type(gradle.bsp_status) ~= 'function' then
        return { ok = false, reason = 'dev.apps.android.gradle is unavailable' }
    end

    return gradle.bsp_status(root_dir)
end

---Is a BSP session currently running for this root?
---@param root string Project root.
---@return boolean active
function M.session_active(root)
    assert(type(root) == 'string' and root ~= '', 'root must be non-empty')

    local client = load_client()
    if client == nil or type(client.state) ~= 'table' or type(client.state.sessions) ~= 'table' then
        return false
    end

    local session = client.state.sessions[root]
    return session ~= nil
end

---Offer to start the BSP server, then call back with the chosen path.
---
--- The callback receives 'bsp' when a session is active (or the user just
--- started one), otherwise 'gradle-cli'.
---@param root string Project root.
---@param callback fun(path: 'bsp' | 'gradle-cli')
function M.ensure(root, callback)
    assert(type(root) == 'string' and root ~= '', 'root must be non-empty')
    vim.validate('callback', callback, 'function')

    local status = M.status(root)
    if not status.ok then
        callback('gradle-cli')
        return
    end

    if M.session_active(root) then
        callback('bsp')
        return
    end

    vim.ui.select({ 'Start BSP (:BspStart)', 'Use ./gradlew instead' }, {
        prompt = 'BSP connection "' .. (status.connection or 'gradle') .. '" found. Use it?',
    }, function(choice)
        if choice == nil or choice:find('gradlew', 1, true) ~= nil then
            callback('gradle-cli')
            return
        end

        local ok, err = pcall(vim.cmd, 'BspStart')
        if not ok then
            notify('Could not start BSP: ' .. tostring(err), levels.WARN, {})
            callback('gradle-cli')
            return
        end

        callback('bsp')
    end)
end

---Run a build through BSP when active, otherwise through the Gradle CLI.
---@param root string Project root.
---@param fallback fun() The CLI build to run when BSP is unavailable.
---@return boolean used_bsp True when the BSP path was taken.
function M.compile_or_fallback(root, fallback)
    assert(type(root) == 'string' and root ~= '', 'root must be non-empty')
    vim.validate('fallback', fallback, 'function')

    if not M.session_active(root) then
        fallback()
        return false
    end

    local client = load_client()
    if client == nil or type(client.compile) ~= 'function' then
        fallback()
        return false
    end

    local ok, err = pcall(client.compile, root)
    if not ok then
        notify('BSP compile failed: ' .. tostring(err) .. ' — falling back to ./gradlew', levels.WARN, {})
        fallback()
        return false
    end

    return true
end

return M
