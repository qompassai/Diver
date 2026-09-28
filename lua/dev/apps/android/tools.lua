-- #################################################################
-- /qompassai/lua/dev/android/tools.lua
-- Qompass AI Android toolchain manifest
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
--- Upstream tool verification record for the Android toolchain.
---
--- Plain-language version: before diver tells anyone to download a tool it
--- must be able to name the exact upstream release, its official download
--- URL, and its checksum. This module is that record. Versions were verified
--- against dl.google.com/android/repository/repository2-1.xml (Google's own
--- SDK package index) and services.gradle.org/versions/current on
--- 2026-09-27. Gradle 9.8.0 and platform-tools 37.0.1 were downloaded and
--- their hashes re-computed in this environment (marked "verified").
--- Everything else is recorded from the upstream index, not downloaded here.

local M = {}

---@class AndroidToolArchive
---@field url string Official download URL.
---@field checksum string Hash in "<algo>:<hex>" form.
---@field verified boolean True when the hash was recomputed locally.

---@class AndroidToolEntry
---@field name string Human-readable tool name.
---@field version string Upstream release version.
---@field sdkmanager? string sdkmanager package spec, when applicable.
---@field archives table<string, AndroidToolArchive> Per-host-os archives.
---@field notes string Provenance and caveats.
---@field min_for? string What requires this version (e.g. 'AGP 9.x').

---@type table<string, AndroidToolEntry>
M.manifest = {
    gradle = {
        name = 'Gradle',
        version = '9.8.0',
        sdkmanager = nil,
        archives = {
            all = {
                url = 'https://services.gradle.org/distributions/gradle-9.8.0-bin.zip',
                checksum = 'sha256:bafd5ce9cfaea0fbccfdc8439a1ac42fbd4cd9c89dc9a988228d8a2639a58e6c',
                verified = true,
            },
        },
        notes = 'Current stable from https://services.gradle.org/versions/current (2026-09-24, final=true). '
            .. 'Downloaded and SHA-256 verified against the official per-file checksum endpoint '
            .. '(https://services.gradle.org/distributions/gradle-9.8.0-bin.zip.sha256). '
            .. 'Runs on JVM 17-26; embedded Kotlin 2.4.x. '
            .. 'Gradle 9.6+ dropped InternalProblems, so AGP 8.x requires Gradle <= 9.5.x.',
    },
    ['cmdline-tools'] = {
        name = 'Android SDK Command-line Tools',
        version = '23.0',
        sdkmanager = 'cmdline-tools;23.0',
        archives = {
            linux = {
                url = 'https://dl.google.com/android/repository/commandlinetools-linux-16111833_latest.zip',
                checksum = 'sha1:e025545c62a8e64c7559119566a569fb1dec5f60',
                verified = false,
            },
            windows = {
                url = 'https://dl.google.com/android/repository/commandlinetools-win-16111833_latest.zip',
                checksum = 'sha1:(see repository2-1.xml)',
                verified = false,
            },
        },
        notes = 'From repository2-1.xml ("cmdline-tools;latest" resolves to 23.0). '
            .. "Not downloaded here; checksum is Google's published index value.",
    },
    ['platform-tools'] = {
        name = 'Android SDK Platform-Tools',
        version = '37.0.1',
        sdkmanager = 'platform-tools',
        archives = {
            linux = {
                url = 'https://dl.google.com/android/repository/platform-tools_r37.0.1-linux.zip',
                checksum = 'sha1:477254aa5f903c15cf51001717bdf347fb6b53e0',
                verified = true,
            },
            windows = {
                url = 'https://dl.google.com/android/repository/platform-tools_r37.0.1-windows.zip',
                checksum = 'sha1:(see repository2-1.xml)',
                verified = false,
            },
        },
        notes = 'Provides adb/fastboot. Downloaded and SHA-1 verified in this environment.',
    },
    ['build-tools'] = {
        name = 'Android SDK Build-Tools',
        version = '37.0.0',
        sdkmanager = 'build-tools;37.0.0',
        archives = {
            linux = {
                url = 'https://dl.google.com/android/repository/build-tools_r37_linux.zip',
                checksum = 'sha1:70954e99f4c3d9d46ee70fa32624672fe7cd6ebe',
                verified = false,
            },
        },
        notes = 'Newest non-RC in repository2-1.xml. Not downloaded in this environment.',
    },
    ndk = {
        name = 'Android NDK',
        version = 'r29 (29.0.14206865)',
        sdkmanager = 'ndk;29.0.14206865',
        archives = {
            linux = {
                url = 'https://dl.google.com/android/repository/android-ndk-r29-linux.zip',
                checksum = 'sha1:87e2bb7e9be5d6a1c6cdf5ec40dd4e0c6d07c30b',
                verified = false,
            },
        },
        notes = 'r29 is the newest widely-deployed stable (mozilla/glean pins it); '
            .. 'r30 entries exist in the index but were beta at last check. 784 MB; not downloaded here.',
    },
    cmake = {
        name = 'CMake (SDK package)',
        version = '4.1.2',
        sdkmanager = 'cmake;4.1.2',
        archives = {
            linux = {
                url = 'https://dl.google.com/android/repository/cmake-4.1.2-linux.zip',
                checksum = 'sha1:c8c4f1c19b75c56f28b9dcf1af928d25cf1a1471',
                verified = false,
            },
        },
        notes = 'Newest in repository2-1.xml. AGP auto-installs a matching CMake when licenses are accepted.',
    },
    emulator = {
        name = 'Android Emulator',
        version = '37.3.1',
        sdkmanager = 'emulator',
        archives = {
            linux = {
                url = 'https://dl.google.com/android/repository/emulator-linux_x64-16373887.zip',
                checksum = 'sha1:07431598c6a52d971f63ef4c76b4f1217ce6b64c',
                verified = false,
            },
        },
        notes = '354 MB; not downloaded in this environment.',
    },
    jdk = {
        name = 'JDK',
        version = '17+ (Gradle 9.x runs on JVM 17-26; AGP 9 accepts 17+)',
        sdkmanager = nil,
        archives = {},
        notes = 'No checksum recorded: use a distro package or https://adoptium.net (Eclipse Temurin). '
            .. 'Gradle 9.7.0 compatibility data confirms JVM 17-26 support.',
    },
}

local LINE_LIMIT_MAX = 200
local OUTPUT_LINES_MAX = 64

---Run a command and return its trimmed stdout, or nil on failure.
---@param argv string[] Argv-form command.
---@return string?
local function run_capture(argv)
    local ok, obj = pcall(vim.system, argv, { text = true })
    if not ok then
        return nil
    end

    local done = obj:wait()
    if done.code ~= 0 then
        return nil
    end

    local out = done.stdout or ''
    return out:gsub('^%s*(.-)%s*$', '%1')
end

---Extract the first line of a string (bounded).
---@param text string
---@return string
local function first_line(text)
    local line = text:match('([^\r\n]+)') or ''
    if #line > LINE_LIMIT_MAX then
        line = line:sub(1, LINE_LIMIT_MAX)
    end

    return line
end

---Probe an executable: present on PATH, plus optional first-line version.
---@param name string Executable name.
---@param version_argv? string[] Argv to print a version line.
---@return { present: boolean, version: string? }
function M.probe(name, version_argv)
    assert(type(name) == 'string' and name ~= '', 'probe needs a non-empty name')

    if vim.fn.executable(name) ~= 1 then
        return { present = false, version = nil }
    end

    local version = nil
    if version_argv ~= nil then
        local out = run_capture(version_argv)
        if out ~= nil then
            version = first_line(out)
        end
    end

    return { present = true, version = version }
end

---Probe the JDK on PATH via `java -version` (which writes to stderr).
---@return { present: boolean, version: string? }
function M.probe_java()
    if vim.fn.executable('java') ~= 1 then
        return { present = false, version = nil }
    end

    local ok, obj = pcall(vim.system, { 'java', '-version' }, { text = true })
    if not ok then
        return { present = true, version = nil }
    end

    local done = obj:wait()
    local text = done.stderr or done.stdout or ''

    return { present = true, version = first_line(text) }
end

---List installed SDK packages from an sdkmanager binary, bounded output.
---@param sdkmanager string Path to the sdkmanager binary.
---@return string[] lines "package = version" pairs, empty when unavailable.
function M.installed_packages(sdkmanager)
    local ok, obj = pcall(vim.system, { sdkmanager, '--list_installed' }, { text = true })
    if not ok then
        return {}
    end

    local done = obj:wait()
    if done.code ~= 0 then
        return {}
    end

    local lines = {}
    for line in (done.stdout or ''):gmatch('[^\r\n]+') do
        local trimmed = line:gsub('^%s*(.-)%s*$', '%1')
        if trimmed ~= '' and #lines < OUTPUT_LINES_MAX then
            lines[#lines + 1] = trimmed
        end
    end

    return lines
end

---Locate the sdkmanager binary under a SDK root, or nil.
---@param sdk_root string Android SDK root directory.
---@return string? path
function M.find_sdkmanager(sdk_root)
    assert(type(sdk_root) == 'string', 'sdk_root must be a string')

    local candidates = {
        sdk_root .. '/cmdline-tools/latest/bin/sdkmanager',
        sdk_root .. '/tools/bin/sdkmanager',
    }

    for i = 1, #candidates do
        if vim.fn.executable(candidates[i]) == 1 then
            return candidates[i]
        end
    end

    return nil
end

---Extract the wrapper's distribution version from gradle-wrapper.properties.
---@param root_dir string Project root containing gradle/wrapper/gradle-wrapper.properties.
---@return string? version e.g. '9.8.0'
function M.wrapper_version(root_dir)
    assert(type(root_dir) == 'string' and root_dir ~= '', 'root_dir must be non-empty')

    local path = root_dir .. '/gradle/wrapper/gradle-wrapper.properties'
    local file = io.open(path, 'r')
    if file == nil then
        return nil
    end

    local content = file:read('*a')
    file:close()

    if type(content) ~= 'string' then
        return nil
    end

    return content:match('gradle%-(%d+%.%d+%.?%d*)%-bin%.zip') or content:match('gradle%-(%d+%.%d+%.?%d*)%-all%.zip')
end

---Compare dotted version strings. Returns -1, 0, 1.
---@param a string
---@param b string
---@return integer
function M.compare_versions(a, b)
    assert(type(a) == 'string' and type(b) == 'string', 'versions must be strings')

    local function parts(version)
        local out = {}
        for num in version:gmatch('%d+') do
            out[#out + 1] = tonumber(num) or 0
        end

        return out
    end

    local pa, pb = parts(a), parts(b)
    local count = math.max(#pa, #pb)

    for i = 1, count do
        local x, y = pa[i] or 0, pb[i] or 0
        if x < y then
            return -1
        end
        if x > y then
            return 1
        end
    end

    return 0
end

return M
