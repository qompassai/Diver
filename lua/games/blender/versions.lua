-- #################################################################
-- /qompassai/Diver/lua/games/blender/versions.lua
-- Qompass AI Blender Versions
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
-- Blender binary discovery and version guards. Every CLI wrapper in
-- this engine calls check_version() before spawning blender, so an
-- ancient or missing binary fails closed with a clear message.
--
-- Download provenance (track C, 2026-09-27):
--   source: https://www.blender.org/download/ (current release 5.2.2 LTS)
--   tarball: https://download.blender.org/release/Blender5.2/blender-5.2.2-linux-x64.tar.xz
--   sha256: 84098912789dc450e95697c4184fb8a90acbe5111c2ba4aede3fecb57806a168
--   (verified against https://download.blender.org/release/Blender5.2/blender-5.2.2.sha256)
--   installed at: ~/workspace/tools/blender/5.2.2/
local config = require('games.blender.config')
local shared_util = require('games.shared.util')

local M = {}

local VERSION_TIMEOUT_MS = 15000

---Parse a strict 'major.minor.patch' version string. Anything else
---(wrong shape, wrong type) yields nil.
---@param text string|nil
---@return integer[]? parts Exactly { major, minor, patch }, or nil when malformed
function M.parse_version(text)
    if type(text) ~= 'string' then
        return nil
    end

    local major, minor, patch = text:match('^(%d+)%.(%d+)%.(%d+)$')

    if major == nil or minor == nil or patch == nil then
        return nil
    end

    local parts = {
        tonumber(major),
        tonumber(minor),
        tonumber(patch),
    }

    for index = 1, 3 do
        if parts[index] == nil then
            return nil
        end
    end

    ---@cast parts integer[]

    return parts
end

---Compare two parsed versions.
---@param installed integer[] { major, minor, patch }
---@param minimum integer[] { major, minor, patch }
---@return boolean at_least True when installed >= minimum
function M.version_at_least(installed, minimum)
    assert(type(installed) == 'table' and #installed == 3)
    assert(type(minimum) == 'table' and #minimum == 3)

    for index = 1, 3 do
        if installed[index] ~= minimum[index] then
            return installed[index] > minimum[index]
        end
    end

    return true
end

---Locate the blender binary. Explicit env override first, then the
---managed install under tools_dir, then PATH.
---@param search_dirs? string[] Override install roots (tests use a bogus dir here)
---@return string? path Absolute binary path, or nil when not found
function M.binary_path(search_dirs)
    local env_bin = shared_util.env_first(config.env_names)

    if env_bin ~= nil and env_bin ~= '' then
        local expanded = vim.fn.expand(env_bin)

        if vim.fn.executable(expanded) == 1 then
            return expanded
        end
    end

    local roots = search_dirs or { config.tools_dir }

    -- Prefer the pinned release directory, then any install root.
    -- Tarball layout nests the binary one level deeper
    -- (<root>/<version>/blender-<version>-linux-x64/blender), so
    -- search recursively and take the first executable hit.
    local ordered = {}

    for _, root in ipairs(roots) do
        ordered[#ordered + 1] = root .. '/' .. config.pinned_version
        ordered[#ordered + 1] = root
    end

    for _, dir in ipairs(ordered) do
        local hits = vim.fn.glob(dir .. '/**/blender', false, true)

        if type(hits) == 'table' then
            for _, hit in ipairs(hits) do
                if vim.fn.executable(hit) == 1 then
                    return hit
                end
            end
        end
    end

    local on_path = vim.fn.exepath(config.binaries[1])

    if on_path ~= '' and vim.fn.executable(on_path) == 1 then
        return on_path
    end

    return nil
end

---Result shape of M.system_wait. Defined locally because this
---LuaLS's bundled vim runtime does not name vim.SystemCompleted,
---and every CLI wrapper reads code/stdout/stderr off it.
---@class BlenderSystemResult
---@field code integer Process exit code (nonzero when killed by timeout)
---@field stdout? string Captured standard output (text mode only)
---@field stderr? string Captured standard error (text mode only)
---@field signal? integer Signal number when the process was killed

---Spawn a subprocess and wait, converting spawn failures (missing
---binary, ENOENT, ...) into a (nil, err) return instead of a throw.
---Every CLI wrapper goes through here so nothing escapes as an
---uncaught error.
---@param argv string[]
---@param opts table vim.system options
---@return BlenderSystemResult? result
---@return string? err
function M.system_wait(argv, opts)
    assert(type(argv) == 'table' and #argv > 0)
    assert(type(opts) == 'table')

    local ok, completed = pcall(function()
        return vim.system(argv, opts):wait()
    end)

    if not ok then
        return nil, 'blender: failed to spawn ' .. tostring(argv[1]) .. ': ' .. tostring(completed)
    end

    -- Copy into the local result shape so callers never depend on
    -- which vim runtime library the installed LuaLS happens to ship.
    return {
        code = completed.code,
        stdout = completed.stdout,
        stderr = completed.stderr,
        signal = completed.signal,
    },
        nil
end

---Query `blender --version` and parse the release triple.
---@param bin? string Explicit binary path (defaults to discovery)
---@return string? version 'major.minor.patch', or nil with an error message
---@return string? err
function M.installed_version(bin)
    local binary = bin or M.binary_path()

    if binary == nil or binary == '' then
        return nil, 'blender binary not found'
    end

    local result, spawn_err = M.system_wait({ binary, '--version' }, { text = true, timeout = VERSION_TIMEOUT_MS })

    if result == nil then
        return nil, spawn_err
    end

    if result.code ~= 0 then
        return nil, 'blender --version failed with exit code ' .. tostring(result.code)
    end

    local first_line = (result.stdout or ''):match('^([^\r\n]*)')
    local triple = first_line and first_line:match('Blender (%d+%.%d+%.%d+)')

    if triple == nil then
        return nil, 'could not parse blender version from: ' .. tostring(first_line)
    end

    return triple, nil
end

---Fail closed unless the discovered binary meets the minimum release.
---Every CLI wrapper calls this before spawning blender.
---@param min_version? string Minimum 'major.minor.patch' (defaults to config.min_version)
---@param bin? string Explicit binary path (defaults to discovery)
---@return boolean ok
---@return string? err
function M.check_version(min_version, bin)
    local minimum = M.parse_version(min_version or config.min_version)

    if minimum == nil then
        return false, 'blender: invalid minimum version: ' .. tostring(min_version)
    end

    local installed, version_err = M.installed_version(bin)

    if installed == nil then
        return false, 'blender: ' .. tostring(version_err)
    end

    local parts = M.parse_version(installed)

    if parts == nil then
        return false, 'blender: unparsable installed version: ' .. installed
    end

    if not M.version_at_least(parts, minimum) then
        return false,
            ('blender %s is older than the minimum supported %s'):format(installed, min_version or config.min_version)
    end

    return true, nil
end

---Resolve the binary or explain how to get one. Never downloads:
---installing software from inside the editor is out of scope.
---@return string? path
---@return string? err
function M.ensure_installed()
    local path = M.binary_path()

    if path ~= nil then
        return path, nil
    end

    return nil,
        (
            'Blender is not installed. Install the %s Linux x86_64 tarball from https://www.blender.org/download/ '
            .. 'under %s/<version>/, or set BLENDER_BIN to an explicit binary path.'
        ):format(config.pinned_version, config.tools_dir)
end

return M
