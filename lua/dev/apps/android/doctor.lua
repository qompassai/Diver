-- #################################################################
-- /qompassai/lua/dev/android/doctor.lua
-- Qompass AI Android doctor
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
--- :AndroidDoctor — health check for the Android toolchain and project.
---
--- Plain-language version: one command that answers "can I build Android
--- apps here?" It checks the host OS, the SDK layout, the tools diver
--- knows about (adb, gradlew, java), connected devices and emulators, the
--- BSP connection, F-Droid readiness, and the subsystem wiring — all with
--- real commands, never invented success. Anything missing degrades to a
--- WARN/SKIP, never an error.

local M = {}

local bsp = require('dev.apps.android.bsp')
local fdroid = require('dev.apps.android.fdroid')
local matrix = require('dev.apps.android.matrix')
local subsystems = require('dev.apps.android.subsystems')
local tools = require('dev.apps.android.tools')
local util = require('dev.apps.android.util')
local output = require('dev.apps.android.output')

local levels = vim.log.levels
local notify = vim.notify

---@class AndroidDoctorCheck
---@field id string Stable check id.
---@field label string Human-readable check name.
---@field status string 'ok' | 'warn' | 'fail' | 'skip'
---@field detail string What was found.

---@param checks AndroidDoctorCheck[]
---@param id string
---@param label string
---@param status string
---@param detail string
local function add(checks, id, label, status, detail)
    checks[#checks + 1] = { id = id, label = label, status = status, detail = detail }
end

---@param checks AndroidDoctorCheck[]
local function check_host(checks)
    local host = matrix.host()
    if matrix.host_supported(host) then
        add(checks, 'host', 'Host OS', 'ok', host .. ' is in the supported matrix.')
    else
        add(checks, 'host', 'Host OS', 'warn', host .. ' is not in the supported matrix (windows/linux).')
    end
end

---@param checks AndroidDoctorCheck[]
---@return string? sdk_root
local function check_sdk(checks)
    local sdk = util.get_android_sdk()
    if sdk == nil then
        add(checks, 'sdk', 'Android SDK', 'fail', 'ANDROID_HOME/ANDROID_SDK_ROOT (or g:android_sdk) is not set.')
        return nil
    end

    if vim.uv.fs_stat(sdk) == nil then
        add(checks, 'sdk', 'Android SDK', 'fail', 'SDK directory does not exist: ' .. sdk)
        return nil
    end

    add(checks, 'sdk', 'Android SDK', 'ok', 'SDK root: ' .. sdk)
    return sdk
end

---@param checks AndroidDoctorCheck[]
---@param sdk string SDK root.
local function check_adb(checks, sdk)
    local adb = sdk .. '/platform-tools/adb'
    if vim.fn.executable(adb) ~= 1 then
        add(checks, 'adb', 'adb', 'warn', 'adb not found at ' .. adb)
        return
    end

    local probe = tools.probe(adb, { adb, 'version' })
    local expected = tools.manifest['platform-tools'].version
    add(checks, 'adb', 'adb', 'ok', (probe.version or 'present') .. ' — manifest expects platform-tools ' .. expected)
end

---@param checks AndroidDoctorCheck[]
---@param sdk string SDK root.
local function check_devices(checks, sdk)
    local adb = sdk .. '/platform-tools/adb'
    if vim.fn.executable(adb) ~= 1 then
        add(checks, 'devices', 'Devices', 'skip', 'adb unavailable.')
        return
    end

    local ok, devices = pcall(require, 'dev.apps.android.devices')
    if not ok then
        add(checks, 'devices', 'Devices', 'skip', 'dev.apps.android.devices unavailable.')
        return
    end

    local ids = devices.get_adb_devices(adb)
    if #ids == 0 then
        add(checks, 'devices', 'Devices', 'warn', 'No authorized devices or emulators attached.')
    else
        add(checks, 'devices', 'Devices', 'ok', #ids .. ' device(s): ' .. table.concat(ids, ', '))
    end
end

---@param checks AndroidDoctorCheck[]
---@param sdk string SDK root.
local function check_avds(checks, sdk)
    local emulator = sdk .. '/emulator/emulator'
    if vim.fn.executable(emulator) ~= 1 then
        add(checks, 'avds', 'AVDs', 'skip', 'emulator binary not installed.')
        return
    end

    local ok, obj = pcall(vim.system, { emulator, '-list-avds' }, { text = true })
    if not ok then
        add(checks, 'avds', 'AVDs', 'skip', 'Could not query the emulator.')
        return
    end

    local done = obj:wait()
    local avds = {}
    for line in (done.stdout or ''):gmatch('[^\r\n]+') do
        local trimmed = util.trim(line)
        if trimmed ~= '' then
            avds[#avds + 1] = trimmed
        end
    end

    if #avds == 0 then
        add(checks, 'avds', 'AVDs', 'warn', 'No AVDs defined; create one with avdmanager.')
    else
        add(checks, 'avds', 'AVDs', 'ok', #avds .. ' AVD(s): ' .. table.concat(avds, ', '))
    end
end

---@param checks AndroidDoctorCheck[]
local function check_gradlew(checks)
    local found = util.find_gradlew()
    if found == nil then
        add(checks, 'gradlew', 'Gradle wrapper', 'skip', 'No gradlew in this project tree.')
        return
    end

    local version = tools.wrapper_version(found.cwd)
    local current = tools.manifest.gradle.version
    if version == nil then
        add(checks, 'gradlew', 'Gradle wrapper', 'warn', 'gradlew found at ' .. found.cwd .. '; version unreadable.')
        return
    end

    local cmp = tools.compare_versions(version, current)
    if cmp == 0 then
        add(checks, 'gradlew', 'Gradle wrapper', 'ok', 'wrapper ' .. version .. ' (current).')
    elseif cmp < 0 then
        add(checks, 'gradlew', 'Gradle wrapper', 'warn', 'wrapper ' .. version .. ' < current ' .. current .. '.')
    else
        add(
            checks,
            'gradlew',
            'Gradle wrapper',
            'ok',
            'wrapper ' .. version .. ' (newer than manifest ' .. current .. ').'
        )
    end
end

---@param checks AndroidDoctorCheck[]
local function check_java(checks)
    local probe = tools.probe_java()
    if not probe.present then
        add(checks, 'java', 'JDK', 'fail', 'java not on PATH; Gradle needs JVM 17+.')
        return
    end

    add(checks, 'java', 'JDK', 'ok', probe.version or 'java present (version unreadable).')
end

---@param checks AndroidDoctorCheck[]
---@param root_dir? string
local function check_bsp(checks, root_dir)
    local status = bsp.status(root_dir)
    if status.ok then
        local detail = 'Connection "' .. (status.connection or 'gradle') .. '" at ' .. (status.root or '?') .. '.'
        add(checks, 'bsp', 'BSP (Gradle)', 'ok', detail)
    else
        local detail = status.reason or 'Not configured.'
        if status.hint then
            detail = detail .. ' ' .. status.hint
        end
        add(checks, 'bsp', 'BSP (Gradle)', 'warn', detail)
    end
end

---@param checks AndroidDoctorCheck[]
---@param root_dir? string
local function check_matrix(checks, root_dir)
    local host = matrix.host()
    local app_kind = 'android-app'
    if root_dir ~= nil and vim.uv.fs_stat(root_dir .. '/fastlane') ~= nil then
        app_kind = 'fdroid-app'
    end

    local ok, note = matrix.check_combo(app_kind, 'aarch64', host)
    add(checks, 'matrix', 'Build matrix', ok and 'ok' or 'warn', note)
end

---@param checks AndroidDoctorCheck[]
---@param root_dir? string
local function check_fdroid(checks, root_dir)
    if root_dir == nil then
        add(checks, 'fdroid', 'F-Droid readiness', 'skip', 'No project root.')
        return
    end

    local summary = fdroid.summarize(fdroid.check(root_dir))
    local all_ok = summary:sub(1, 1) ~= '0'
    add(checks, 'fdroid', 'F-Droid readiness', all_ok and 'ok' or 'warn', summary)
end

---@param checks AndroidDoctorCheck[]
local function check_subsystems(checks)
    for _, sub in ipairs(subsystems.check_all()) do
        add(checks, sub.id, sub.name, sub.present and 'ok' or 'warn', sub.detail)
    end
end

local STATUS_MARK = { ok = '✓', warn = '!', fail = '✗', skip = '-' }

---Run the doctor and render results into the android build window.
---@return AndroidDoctorCheck[] checks Structured results (also rendered).
function M.run()
    ---@type AndroidDoctorCheck[]
    local checks = {}

    check_host(checks)
    local sdk = check_sdk(checks)
    if sdk ~= nil then
        check_adb(checks, sdk)
        check_devices(checks, sdk)
        check_avds(checks, sdk)
    end
    check_gradlew(checks)
    check_java(checks)

    local found = util.find_gradlew()
    local root_dir = found and found.cwd or nil
    check_bsp(checks, root_dir)
    check_matrix(checks, root_dir)
    check_fdroid(checks, root_dir)
    check_subsystems(checks)

    local buf = output.create_build_window()
    local lines = { 'Android doctor', '' }
    for i = 1, #checks do
        local check = checks[i]
        local mark = STATUS_MARK[check.status] or '?'
        lines[#lines + 1] = ('[%s] %s: %s'):format(mark, check.label, check.detail)
    end

    vim.api.nvim_set_option_value('modifiable', true, { buf = buf })
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_set_option_value('modifiable', false, { buf = buf })

    local counts = { ok = 0, warn = 0, fail = 0, skip = 0 }
    for i = 1, #checks do
        local status = checks[i].status
        counts[status] = (counts[status] or 0) + 1
    end

    notify(
        ('Android doctor: %d ok, %d warn, %d fail, %d skip'):format(counts.ok, counts.warn, counts.fail, counts.skip),
        counts.fail > 0 and levels.ERROR or levels.INFO,
        {}
    )

    return checks
end

return M
