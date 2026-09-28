-- #################################################################
-- /qompassai/lua/scip/utils.lua
-- Qompass AI SCIP Utils
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
local fs = vim.fs
local uv = vim.uv
local M = {}
---Return whether a filesystem path exists.
---@param path string
---@return boolean
function M.path_exists(path)
    return uv.fs_stat(path) ~= nil
end

---Return whether a command is executable.
---
---Neovim's `executable()` checks the executable bit for path-qualified
---commands and resolves plain command names through PATH, so one code path
---covers both cases.
---@param command string
---@return boolean
function M.executable(command)
    return vim.fn.executable(command) == 1
end

---Convert command output into display-buffer or quickfix lines.
---@param text string
---@return string[]
function M.text_lines(text)
    if text == '' then
        return {
            'No output.',
        }
    end

    return vim.split(text:gsub('\r\n', '\n'), '\n', {
        plain = true,
        trimempty = true,
    })
end

---Choose useful output from a completed system process.
---@param result vim.SystemCompleted
---@param prefer_stderr? boolean
---@return string
function M.system_output(result, prefer_stderr)
    local stderr = result.stderr or ''
    local stdout = result.stdout or ''

    if prefer_stderr and stderr ~= '' then
        return stderr
    end

    if stdout ~= '' then
        return stdout
    end

    return stderr
end

---Find a C/C++ compilation database commonly produced by CMake.
---@param root string
---@return string
function M.compilation_database(root)
    local candidates = {
        fs.joinpath(root, 'compile_commands.json'),
        fs.joinpath(root, 'build', 'compile_commands.json'),
        fs.joinpath(root, 'cmake-build-debug', 'compile_commands.json'),
        fs.joinpath(root, 'cmake-build-release', 'compile_commands.json'),
    }

    for _, candidate in ipairs(candidates) do
        if M.path_exists(candidate) then
            return candidate
        end
    end

    error(
        'No compile_commands.json found under '
            .. root
            .. '. Configure CMake with '
            .. '-DCMAKE_EXPORT_COMPILE_COMMANDS=ON.'
    )
end

---Resolve an indexer's dynamic/static command.
---@param value string|fun(context: ScipContext): string
---@param context ScipContext
---@return string?, string?
function M.resolve_command(value, context)
    if type(value) == 'string' then
        if value == '' then
            return nil, 'SCIP indexer command is empty'
        end

        return value, nil
    end

    local ok, result = pcall(value, context)

    if not ok then
        return nil, tostring(result)
    end

    if type(result) ~= 'string' or result == '' then
        return nil, 'SCIP indexer command must resolve to a non-empty string'
    end

    return result, nil
end

---Resolve an indexer's dynamic/static argument list.
---@param value string[]|fun(context: ScipContext): string[]
---@param context ScipContext
---@return string[]?, string?
function M.resolve_args(value, context)
    if type(value) == 'table' then
        return vim.deepcopy(value), nil
    end

    local ok, result = pcall(value, context)

    if not ok then
        return nil, tostring(result)
    end

    if type(result) ~= 'table' then
        return nil, 'SCIP indexer args must resolve to a string array'
    end

    -- Deep-copy the dynamic result exactly like the static branch: a future
    -- in-place edit must never alias the indexer's cached table.
    ---@cast result string[]
    return vim.deepcopy(result), nil
end

---Prefer a project-local executable over a global fallback command.
---
---Project-local tool installations (for example a Composer `vendor/bin`
---binary) win over the global PATH entry so the tool version follows the
---project's lockfile rather than an unrelated global version.
---
---@param root string Project root.
---@param relpath string[] Path segments of the project-local executable.
---@param fallback string Global command used when no local executable exists.
---@return string command Project-local path when it exists, else fallback.
function M.local_or_bin(root, relpath, fallback)
    local local_command = fs.joinpath(root, table.unpack(relpath))

    if M.path_exists(local_command) then
        return local_command
    end

    return fallback
end

return M
