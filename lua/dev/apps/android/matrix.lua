-- #################################################################
-- /qompassai/lua/dev/android/matrix.lua
-- Qompass AI Android build matrices
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
--- Supported build matrices for Android + F-Droid work, as data.
---
--- Plain-language version: not every host can build every kind of app for
--- every device. This module is the single source of truth for which
--- combinations diver supports (app kind x target ABI x host OS), plus the
--- F-Droid flavor requirements, so :AndroidDoctor can check them instead of
--- guessing. Edit the tables when the world changes; keep functions pure.
---
--- Facts encoded here are grounded in Android docs and F-Droid's own
--- inclusion criteria (metadata/<applicationId>.yml in fdroiddata, Fastlane
--- store metadata in-repo, reproducible builds for maintainer-signed
--- distribution). Verified 2026-09-27.

local M = {}

---@class AndroidHostInfo
---@field id string 'windows' | 'linux' | 'macos' | 'other'
---@field label string Human-readable host name.

---@class AndroidMatrixCombo
---@field app_kind string 'android-app' | 'fdroid-app'
---@field target string 'x86_64' | 'aarch64'
---@field host string 'windows' | 'linux'
---@field form string Where the combo is usable: 'computer' | 'phone' | 'both'.
---@field notes string Why the combo is supported (or its caveat).

---@type string[]
M.hosts = { 'windows', 'linux' }

---@type string[]
M.targets = { 'x86_64', 'aarch64' }

---@type string[]
M.app_kinds = { 'android-app', 'fdroid-app' }

---@type string[]
M.flavors = { 'debug', 'release', 'fdroid' }

--- Supported combos: every row is one claim the doctor can verify.
---@type AndroidMatrixCombo[]
M.combos = {
    -- Each row is one supported claim the doctor can verify.
    {
        app_kind = 'android-app',
        target = 'x86_64',
        host = 'linux',
        form = 'computer',
        notes = 'Gradle + SDK on Linux builds x86_64 emulator images and APKs; tested headless.',
    },
    {
        app_kind = 'android-app',
        target = 'x86_64',
        host = 'windows',
        form = 'computer',
        notes = 'Android Studio/Gradle on Windows; x86_64 is the desktop-emulator ABI.',
    },
    {
        app_kind = 'android-app',
        target = 'aarch64',
        host = 'linux',
        form = 'both',
        notes = 'AAB/APK for arm64-v8a phones from a Linux host; NDK r29 cross-compiles.',
    },
    {
        app_kind = 'android-app',
        target = 'aarch64',
        host = 'windows',
        form = 'computer',
        notes = 'AAB/APK for arm64-v8a phones from a Windows host; NDK r29 cross-compiles.',
    },
    {
        app_kind = 'fdroid-app',
        target = 'aarch64',
        host = 'linux',
        form = 'both',
        notes = 'F-Droid builds from source on Linux; reproducible builds need pinned SDK/NDK.',
    },
    {
        app_kind = 'fdroid-app',
        target = 'x86_64',
        host = 'linux',
        form = 'computer',
        notes = 'Metadata can declare ABI splits; x86_64 APKs ship when the split is set.',
    },
    {
        app_kind = 'fdroid-app',
        target = 'aarch64',
        host = 'windows',
        form = 'computer',
        notes = 'Develop on Windows, verify the F-Droid recipe against Linux/WSL2.',
    },
}

--- F-Droid flavor requirements, checked by dev.apps.android.fdroid.
---@class AndroidFdroidRequirements
---@field metadata_paths string[] Fastlane paths expected in the app repo.
---@field reproducible_flags string[] build.gradle.kts patterns for reproducible builds.
---@field forbidden_patterns string[] Patterns that block F-Droid inclusion.
---@field metadata_recipe string Where the submission recipe lives.

---@type AndroidFdroidRequirements
M.fdroid = {
    metadata_paths = {
        'fastlane/metadata/android/en-US/title.txt',
        'fastlane/metadata/android/en-US/full_description.txt',
        'fastlane/metadata/android/en-US/short_description.txt',
        'fastlane/metadata/android/en-US/images/icon.png',
    },
    reproducible_flags = {
        'vcsInfo',
        'dependenciesInfo',
    },
    forbidden_patterns = {
        'com.google.android.gms',
        'com.google.firebase',
    },
    metadata_recipe = 'metadata/<applicationId>.yml (in the fdroiddata repository)',
}

---Detect the host Neovim runs on. Never errors: unknown maps to 'other'.
---@return string id 'windows' | 'linux' | 'macos' | 'other'
function M.host()
    local ok, uname = pcall(vim.uv.os_uname)
    if not ok or type(uname) ~= 'table' then
        return 'other'
    end

    local sysname = tostring(uname.sysname or ''):lower()
    if sysname:find('windows', 1, true) ~= nil then
        return 'windows'
    end
    if sysname:find('linux', 1, true) ~= nil then
        return 'linux'
    end
    if sysname:find('darwin', 1, true) ~= nil then
        return 'macos'
    end

    return 'other'
end

---Is the host in the supported matrix?
---@param host? string Host id; defaults to M.host().
---@return boolean supported
function M.host_supported(host)
    host = host or M.host()
    for i = 1, #M.hosts do
        if M.hosts[i] == host then
            return true
        end
    end

    return false
end

---Return every supported combo for an app kind (or all kinds).
---@param app_kind? string 'android-app' | 'fdroid-app' | nil
---@return AndroidMatrixCombo[]
function M.combos_for(app_kind)
    if app_kind == nil then
        return M.combos
    end

    local out = {}
    for i = 1, #M.combos do
        if M.combos[i].app_kind == app_kind then
            out[#out + 1] = M.combos[i]
        end
    end

    return out
end

---Check whether a concrete build request is inside the supported matrix.
---@param app_kind string 'android-app' | 'fdroid-app'
---@param target string 'x86_64' | 'aarch64'
---@param host string 'windows' | 'linux'
---@return boolean ok
---@return string note Human-readable reason (caveat or 'outside the supported matrix').
function M.check_combo(app_kind, target, host)
    for i = 1, #M.combos do
        local combo = M.combos[i]
        if combo.app_kind == app_kind and combo.target == target and combo.host == host then
            return true, combo.notes
        end
    end

    return false, 'Outside the supported matrix: ' .. app_kind .. ' / ' .. target .. ' / ' .. host
end

---Which Gradle tasks build each flavor? Keep in sync with fdroid.lua.
---@param flavor string 'debug' | 'release' | 'fdroid'
---@return string task Gradle task name.
function M.task_for_flavor(flavor)
    if flavor == 'fdroid' then
        return 'assembleRelease'
    end
    if flavor == 'release' then
        return 'assembleRelease'
    end

    return 'assembleDebug'
end

return M
