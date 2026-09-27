-- #################################################################
-- /qompassai/lua/dev/android/fdroid.lua
-- Qompass AI F-Droid readiness checks
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
--- F-Droid readiness checks for an Android project.
---
--- Plain-language version: F-Droid builds apps from source and publishes
--- them itself. Getting an app in requires a metadata recipe in the
--- fdroiddata repository plus an app tree that cooperates: Fastlane store
--- metadata in the repo, no proprietary dependencies, and a build that can
--- be made reproducible. These checks are advisory — they never fail a
--- build — and feed :AndroidDoctor.
---
--- Criteria grounded in fdroiddata's app-inclusion checklist and the
--- reproducible-builds docs (checked 2026-09-27).

local matrix = require('dev.android.matrix')
local util = require('dev.android.util')

local M = {}

---@class AndroidFdroidCheck
---@field id string Stable check id.
---@field label string Human-readable check name.
---@field ok boolean Whether the check passed.
---@field detail string What was found.

---Read a build file (bounded), trying .kts then .groovy.
---@param root_dir string Project root.
---@param module string Module directory, e.g. 'app'.
---@return string? content
local function read_module_build_file(root_dir, module)
    return util.read_file(root_dir .. '/' .. module .. '/build.gradle.kts')
        or util.read_file(root_dir .. '/' .. module .. '/build.gradle')
end

---Check that a path exists under the project root.
---@param root_dir string
---@param relpath string Relative path.
---@return boolean
local function path_exists(root_dir, relpath)
    return vim.uv.fs_stat(root_dir .. '/' .. relpath) ~= nil
end

---Check the Fastlane metadata paths matrix.fdroid requires.
---@param root_dir string Project root.
---@return AndroidFdroidCheck
local function check_fastlane(root_dir)
    local missing = {}
    for i = 1, #matrix.fdroid.metadata_paths do
        local path = matrix.fdroid.metadata_paths[i]
        if not path_exists(root_dir, path) then
            missing[#missing + 1] = path
        end
    end

    if #missing == 0 then
        return {
            id = 'fastlane',
            label = 'Fastlane store metadata',
            ok = true,
            detail = 'All required Fastlane files present.',
        }
    end

    return {
        id = 'fastlane',
        label = 'Fastlane store metadata',
        ok = false,
        detail = 'Missing: ' .. table.concat(missing, ', '),
    }
end

---Check reproducible-build flags in the module's lint/build configuration.
---@param root_dir string Project root.
---@param module string Module directory.
---@return AndroidFdroidCheck
local function check_reproducible(root_dir, module)
    local content = read_module_build_file(root_dir, module)
    if content == nil then
        return {
            id = 'reproducible',
            label = 'Reproducible build configuration',
            ok = false,
            detail = 'No build file found for module ' .. module .. '.',
        }
    end

    local missing = {}
    for i = 1, #matrix.fdroid.reproducible_flags do
        local flag = matrix.fdroid.reproducible_flags[i]
        if content:find(flag, 1, true) == nil then
            missing[#missing + 1] = flag
        end
    end

    if #missing == 0 then
        return {
            id = 'reproducible',
            label = 'Reproducible build configuration',
            ok = true,
            detail = 'vcsInfo/dependenciesInfo settings found in ' .. module .. '.',
        }
    end

    return {
        id = 'reproducible',
        label = 'Reproducible build configuration',
        ok = false,
        detail = 'Add to '
            .. module
            .. '/build.gradle.kts: '
            .. table.concat(missing, ', ')
            .. ' (see F-Droid reproducible-builds docs).',
    }
end

---Scan for known proprietary dependency patterns.
---@param root_dir string Project root.
---@param module string Module directory.
---@return AndroidFdroidCheck
local function check_proprietary(root_dir, module)
    local content = read_module_build_file(root_dir, module)
    if content == nil then
        return {
            id = 'proprietary',
            label = 'No proprietary dependencies',
            ok = false,
            detail = 'No build file found for module ' .. module .. '.',
        }
    end

    local hits = {}
    for i = 1, #matrix.fdroid.forbidden_patterns do
        local pattern = matrix.fdroid.forbidden_patterns[i]
        if content:find(pattern, 1, true) ~= nil then
            hits[#hits + 1] = pattern
        end
    end

    if #hits == 0 then
        return {
            id = 'proprietary',
            label = 'No proprietary dependencies',
            ok = true,
            detail = 'No known proprietary markers found.',
        }
    end

    return {
        id = 'proprietary',
        label = 'No proprietary dependencies',
        ok = false,
        detail = 'Found: ' .. table.concat(hits, ', ') .. ' — F-Droid rejects non-free SDKs.',
    }
end

---Check that the fdroid build flavor's assemble task has a matching config.
---@param root_dir string Project root.
---@param module string Module directory.
---@return AndroidFdroidCheck
local function check_flavor(root_dir, module)
    local content = read_module_build_file(root_dir, module)
    if content == nil then
        return { id = 'flavor', label = 'fdroid build flavor', ok = false, detail = 'No build file found.' }
    end

    if content:find('fdroid', 1, true) ~= nil then
        return {
            id = 'flavor',
            label = 'fdroid build flavor',
            ok = true,
            detail = 'A "fdroid" product flavor is declared.',
        }
    end

    return {
        id = 'flavor',
        label = 'fdroid build flavor',
        ok = false,
        detail = 'No "fdroid" product flavor; F-Droid can still build the release variant, '
            .. 'but a flavor keeps proprietary bits out.',
    }
end

---Run all F-Droid readiness checks for a project.
---@param root_dir string Project root.
---@param module? string Module directory (default 'app').
---@return AndroidFdroidCheck[]
function M.check(root_dir, module)
    assert(type(root_dir) == 'string' and root_dir ~= '', 'root_dir must be non-empty')
    module = module or 'app'

    return {
        check_fastlane(root_dir),
        check_reproducible(root_dir, module),
        check_proprietary(root_dir, module),
        check_flavor(root_dir, module),
    }
end

---One-line summary for the doctor.
---@param checks AndroidFdroidCheck[]
---@return string
function M.summarize(checks)
    local ok_count = 0
    for i = 1, #checks do
        if checks[i].ok then
            ok_count = ok_count + 1
        end
    end

    return ok_count .. '/' .. #checks .. ' F-Droid checks pass'
end

return M
