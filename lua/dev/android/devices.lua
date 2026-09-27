-- #################################################################
-- /qompassai/lua/dev/android/devices.lua
-- Qompass AI Devices
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

local util = require('dev.android.util')

function M.with_adb(callback)
    local sdk = util.get_android_sdk()
    if sdk == nil then
        vim.notify('Android SDK is not defined.', vim.log.levels.ERROR, {})
        return
    end

    callback(sdk .. '/platform-tools/adb')
end

---List attached devices that are authorized and online.
---
--- Only rows whose state is exactly 'device' are returned; 'unauthorized',
--- 'offline', and 'no permissions' rows are excluded because no adb
--- command can run against them.
---@param adb string Path to the adb binary.
---@return string[] ids Device serials.
function M.get_adb_devices(adb)
    vim.validate('adb', adb, 'string')

    local ids = {}
    local ok, obj = pcall(vim.system, { adb, 'devices' }, { text = true })
    if not ok then
        return ids
    end

    local done = obj:wait()
    local read = done.stdout or ''

    for row in read:gmatch('[^\r\n]+') do
        local items = {}
        for item in row:gmatch('%S+') do
            items[#items + 1] = item
        end

        if items[1] ~= nil and items[1] ~= 'List' and items[2] == 'device' then
            ids[#ids + 1] = items[1]
        end
    end

    return ids
end

---Look up a display name for one device, falling back to its serial.
---@param adb string Path to the adb binary.
---@param id string Device serial.
---@return string name
local function device_display_name(adb, id)
    local cmd

    if id:match('^emulator') then
        cmd = { adb, '-s', id, 'emu', 'avd', 'name' }
    else
        cmd = { adb, '-s', id, 'shell', 'getprop', 'ro.product.model' }
    end

    local ok, obj = pcall(vim.system, cmd, { text = true })
    if not ok then
        return id
    end

    local done = obj:wait()
    if done.code ~= 0 then
        return id
    end

    local name = util.trim((done.stdout or ''):match('^(.-)\r?\n') or (done.stdout or ''))
    if name == '' then
        return id
    end

    return name
end

---Look up display names for device serials. The result always aligns with
---`ids`: a failed lookup falls back to the serial instead of shifting
---later entries (the old implementation skipped failures and misaligned).
---@param adb string Path to the adb binary.
---@param ids string[] Device serials.
---@return string[] names One name per id.
function M.get_device_names(adb, ids)
    vim.validate('adb', adb, 'string')
    vim.validate('ids', ids, 'table')

    local names = {}
    for i = 1, #ids do
        names[#names + 1] = device_display_name(adb, ids[i])
    end

    return names
end

---List attached devices with display names. Names always align with ids:
---a failed lookup falls back to the serial, never shifts the table.
---@param adb string Path to the adb binary.
---@return { id: string, name: string }[]
function M.get_running_devices(adb)
    vim.validate('adb', adb, 'string')

    local devices = {}
    local ids = M.get_adb_devices(adb)

    for i = 1, #ids do
        local id = util.trim(ids[i])
        devices[#devices + 1] = {
            id = id,
            name = device_display_name(adb, id),
        }
    end

    return devices
end

---List AVD names with the official SDK tools.
---
--- Tries `$SDK/emulator/emulator -list-avds` first, then
--- `avdmanager list avd` from cmdline-tools. Both degrade gracefully when
--- the SDK or the tool is missing.
---@return string[]? avds AVD names, or nil when listing failed.
---@return string? err Human-readable reason when avds is nil.
function M.list_avds()
    local sdk = util.get_android_sdk()
    if sdk == nil then
        return nil, 'Android SDK is not defined.'
    end

    local emulator = sdk .. '/emulator/emulator'
    if vim.fn.executable(emulator) == 1 then
        local ok, obj = pcall(vim.system, { emulator, '-list-avds' }, { text = true })
        if ok then
            local done = obj:wait()
            if done.code == 0 then
                local avds = {}
                for line in (done.stdout or ''):gmatch('[^\r\n]+') do
                    line = util.trim(line)
                    if line ~= '' then
                        avds[#avds + 1] = line
                    end
                end

                return avds
            end
        end
    end

    local avdmanager = sdk .. '/cmdline-tools/latest/bin/avdmanager'
    if vim.fn.executable(avdmanager) == 1 then
        local ok, obj = pcall(vim.system, { avdmanager, 'list', 'avd' }, { text = true })
        if ok then
            local done = obj:wait()
            if done.code == 0 then
                local avds = {}
                for line in (done.stdout or ''):gmatch('[^\r\n]+') do
                    local name = line:match('^%s*Name:%s*(.-)%s*$')
                    if name ~= nil and name ~= '' then
                        avds[#avds + 1] = name
                    end
                end

                return avds
            end
        end
    end

    return nil, 'Could not list AVDs: emulator and avdmanager are unavailable.'
end

function M.find_main_activity(adb, device_id, application_id)
    local obj = vim.system({
        adb,
        '-s',
        device_id,
        'shell',
        'cmd',
        'package',
        'resolve-activity',
        '--brief',
        application_id,
    }, {}):wait()

    if obj.code ~= 0 then
        return nil
    end

    local result = nil
    for line in (obj.stdout or ''):gmatch('[^\r\n]+') do
        result = line
    end

    if result == nil then
        return nil
    end

    return util.trim(result)
end

return M
