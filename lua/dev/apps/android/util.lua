-- #################################################################
-- /qompassai/lua/dev/android/util.lua
-- Qompass AI Util
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
local M = {}

---Maximum directories to ascend when searching for the Gradle wrapper.
local FIND_GRADLEW_MAX_DEPTH = 32

function M.trim(s)
    return (s or ''):gsub('^%s*(.-)%s*$', '%1')
end

---True when Neovim runs on Windows.
---@return boolean
function M.is_windows()
    return vim.fn.has('win32') == 1
end

function M.get_android_sdk()
    local sdk = vim.fn.expand(vim.env.ANDROID_HOME or vim.env.ANDROID_SDK_ROOT or vim.g.android_sdk or '')
    if sdk == '' then
        return nil
    end
    return sdk
end

function M.android_cli_cmd(args)
    local cmd = { 'android' }
    local sdk = M.get_android_sdk()

    if sdk then
        cmd[#cmd + 1] = '--sdk=' .. sdk
    end

    for i = 1, #args do
        cmd[#cmd + 1] = args[i]
    end

    return cmd
end

function M.read_file(path)
    local file = io.open(path, 'r')
    if not file then
        return nil
    end

    local content = file:read('*all')
    file:close()
    return content
end

---Find the Gradle wrapper script in a directory, preferring gradlew over gradlew.bat.
---@param dir string Directory to inspect (no recursion).
---@return string? path Wrapper script path, or nil.
local function wrapper_in(dir)
    local candidates = { dir .. '/gradlew', dir .. '/gradlew.bat' }

    for i = 1, #candidates do
        if vim.uv.fs_stat(candidates[i]) ~= nil then
            return candidates[i]
        end
    end

    return nil
end

---Find the Gradle wrapper by ascending from a directory (bounded).
---
--- Pure Lua: no external `find` binary, so it works on Windows too.
---@param directory? string Starting directory (defaults to the current working directory).
---@return { cwd: string, gradlew: string }? found Wrapper location, or nil.
function M.find_gradlew(directory)
    local cwd = directory or vim.fn.getcwd()

    for _ = 1, FIND_GRADLEW_MAX_DEPTH do
        local gradlew = wrapper_in(cwd)
        if gradlew ~= nil then
            return {
                cwd = cwd,
                gradlew = gradlew,
            }
        end

        local parent = vim.fn.fnamemodify(cwd, ':h')
        if parent == cwd then
            return nil
        end

        cwd = parent
    end

    return nil
end

---Build an argv for the Gradle wrapper that also runs on Windows.
---
--- uv-spawned processes cannot execute .bat files directly, so on Windows
--- the wrapper runs through cmd.exe /c.
---@param gradlew string Wrapper script path (from M.find_gradlew).
---@param args string[] Gradle arguments.
---@return string[] argv
function M.gradle_argv(gradlew, args)
    assert(type(gradlew) == 'string' and gradlew ~= '', 'gradlew path must be non-empty')
    vim.validate('args', args, 'table')

    local argv = {}
    if M.is_windows() then
        argv[1] = 'cmd.exe'
        argv[2] = '/c'
        argv[3] = gradlew
    else
        argv[1] = gradlew
    end

    for i = 1, #args do
        argv[#argv + 1] = args[i]
    end

    return argv
end

return M
