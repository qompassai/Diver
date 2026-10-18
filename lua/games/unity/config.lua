-- /qompassai/Diver/lua/games/unity/config.lua
-- Qompass AI Unity Config
---@module 'games.unity.config'
local M = {}

M.env_names = { 'NVIM_UNITY_EDITOR_BIN', 'UNITY_EDITOR_BIN', 'UNITY_BIN' }
M.fallback_binaries = { 'unity-editor', 'Unity', 'unity' }
M.group_order = { 'Editor', 'Build', 'Test', 'Packages', 'Project' }
M.lockfile_filename = 'packages-lock.json'
M.manifest_filename = 'manifest.json'
M.output_filetype = 'unity-output'

-- Package Manager file names, relative to the project root -- kept
-- as named constants rather than inline strings so both actions
-- (list and add) can never drift apart on the path.
M.packages_dir = 'Packages'
M.root_markers = { 'ProjectSettings/ProjectVersion.txt' }

-- Default per-OS Editor.log location (used when no project-local log
-- has been produced yet).
function M.default_editor_log()
    if vim.fn.has('win32') == 1 or vim.fn.has('win64') == 1 then
        return vim.fn.expand('~') .. '/AppData/Local/Unity/Editor/Editor.log'
    end
    if vim.fn.has('mac') == 1 or vim.fn.has('macunix') == 1 then
        return vim.fn.expand('~') .. '/Library/Logs/Unity/Editor.log'
    end
    return vim.fn.expand('~') .. '/.config/unity3d/Editor.log'
end

-- Path to the Unity binary inside a Hub install for `version`.
function M.hub_editor_binary(root, version)
    if vim.fn.has('win32') == 1 or vim.fn.has('win64') == 1 then
        return root .. '/' .. version .. '/Editor/Unity.exe'
    end
    if vim.fn.has('mac') == 1 or vim.fn.has('macunix') == 1 then
        return root .. '/' .. version .. '/Unity.app/Contents/MacOS/Unity'
    end
    return root .. '/' .. version .. '/Editor/Unity'
end

-- Unity Hub install roots per platform, in priority order. The first
-- readable one wins; each is joined with the detected editor version.
function M.hub_roots()
    if vim.fn.has('win32') == 1 or vim.fn.has('win64') == 1 then
        return {
            'C:/Program Files/Unity/Hub/Editor',
            vim.fn.expand('~') .. '/AppData/Local/Unity/Hub/Editor',
        }
    end
    if vim.fn.has('mac') == 1 or vim.fn.has('macunix') == 1 then
        return { '/Applications/Unity/Hub/Editor' }
    end
    return {
        vim.fn.expand('~') .. '/Unity/Hub/Editor',
        '/opt/unity/hub/editor',
        '/usr/share/unity3d/Hub/Editor',
    }
end

return M
