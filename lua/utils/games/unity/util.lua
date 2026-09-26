--- Unity helpers — find the Unity editor and project for game work.
---
--- Plain-language version: to work on a Unity game you need two things: the project folder and the Unity editor
--- program. This module hunts them down (walking up directories, checking installs) so the other Unity tools do not
--- have to. It is a helper library the Unity modules call into.
---@module 'utils.games.unity.util'
-- #################################################################
-- /qompassai/Diver/lua/utils/games/unity/util.lua
-- Qompass AI Unity Util
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
local config = require('utils.games.unity.config')
local shared_util = require('utils.games.shared.util')

local M = {}

---Find the Unity project root by walking up from a starting directory.
---@param start_dir? string directory to start from (default: cwd)
---@return string|nil root the project root path, or nil when not found
function M.find_root(start_dir)
    return shared_util.find_root(config.root_markers, start_dir)
end

---Find the Unity project root, returning nil when none is found.
---@return string|nil root the project root path, or nil when not found
function M.require_root()
    local root = M.find_root()
    if not root then
        vim.notify('Unity: no ProjectSettings/ProjectVersion.txt found upward from cwd.', vim.log.levels.ERROR)
    end
    return root
end

-- Reads `m_EditorVersion: 2022.3.10f1` out of ProjectVersion.txt.
---Read the Unity editor version from the project's version file.
---@param root string project root path
---@return string|nil version the editor version, or nil when unreadable
function M.project_editor_version(root)
    root = root or M.find_root()
    if not root then
        return nil
    end
    local content = shared_util.read_file(root .. '/ProjectSettings/ProjectVersion.txt')
    if not content then
        return nil
    end
    return content:match('m_EditorVersion:%s*(%S+)')
end

-- Locates the Hub-installed Editor binary matching the project's
-- recorded version, falling back to any editor on $PATH.
---Locate a Unity editor binary for the project.
---@param root string project root path
---@return string|nil editor path to the editor binary, or nil when not found
function M.find_editor(root)
    local override = shared_util.env_first(config.env_names)
    if override then
        local resolved = shared_util.first_executable({ override })
        if resolved then
            return resolved
        end
        vim.notify('Unity: configured binary is not executable: ' .. override, vim.log.levels.WARN)
    end

    local version = M.project_editor_version(root)
    if version then
        for _, hub_root in ipairs(config.hub_roots()) do
            local candidate = config.hub_editor_binary(hub_root, version)
            if shared_util.first_executable({ candidate }) then
                return candidate
            end
        end
        vim.notify('Unity: editor version ' .. version .. ' not found under any Hub root.', vim.log.levels.WARN)
    end

    return shared_util.first_executable(config.fallback_binaries)
end

---Locate a Unity editor binary, returning nil when none is found.
---@param root string project root path
---@return string|nil editor path to the editor binary, or nil when not found
function M.require_editor(root)
    local editor = M.find_editor(root)
    if not editor then
        vim.notify(
            'Unity Editor executable not found. Set NVIM_UNITY_EDITOR_BIN, install via Unity Hub, '
                .. 'or add unity-editor to $PATH.',
            vim.log.levels.ERROR
        )
    end
    return editor
end

return M
