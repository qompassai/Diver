-- #################################################################
-- /qompassai/lua/utils/dev/android/devices.lua
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

local util = require('utils.dev.android.util')

function M.with_adb(callback)
  local sdk = util.get_android_sdk()
  if sdk == nil then
    vim.notify('Android SDK is not defined.', vim.log.levels.ERROR, {})
    return
  end

  callback(sdk .. '/platform-tools/adb')
end

function M.get_adb_devices(adb)
  local ids = {}
  local obj = vim.system({ adb, 'devices' }, {}):wait()
  local read = obj.stdout or ''

  for row in read:gmatch('[^\n]+') do
    local items = {}
    for item in row:gmatch('%S+') do
      items[#items + 1] = item
    end

    if items[1] and items[1] ~= 'List' then
      ids[#ids + 1] = items[1]
    end
  end

  return ids
end

function M.get_device_names(adb, ids)
  local devices = {}

  for i = 1, #ids do
    local id = ids[i]
    local cmd

    if id:match('^emulator') then
      cmd = { adb, '-s', id, 'emu', 'avd', 'name' }
    else
      cmd = { adb, '-s', id, 'shell', 'getprop', 'ro.product.model' }
    end

    local obj = vim.system(cmd, {}):wait()
    if obj.code == 0 then
      local read = obj.stdout or ''
      devices[#devices + 1] = util.trim(read:match('^(.-)\n') or read)
    end
  end

  return devices
end

function M.get_running_devices(adb)
  local devices = {}
  local ids = M.get_adb_devices(adb)
  local names = M.get_device_names(adb, ids)

  for i = 1, #ids do
    devices[#devices + 1] = {
      id = util.trim(ids[i]),
      name = util.trim(names[i] or ids[i]),
    }
  end

  return devices
end

function M.list_avds()
  local obj = vim
    .system(
      util.android_cli_cmd({
        'emulator',
        'list',
      }),
      { text = true }
    )
    :wait()

  if obj.code ~= 0 then
    return nil, util.trim(obj.stderr or 'Failed to list emulators.')
  end

  local avds = {}
  for line in (obj.stdout or ''):gmatch('[^\r\n]+') do
    line = util.trim(line)
    if line ~= '' then
      avds[#avds + 1] = line
    end
  end

  return avds
end

function M.find_main_activity(adb, device_id, application_id)
  local obj = vim
    .system({
      adb,
      '-s',
      device_id,
      'shell',
      'cmd',
      'package',
      'resolve-activity',
      '--brief',
      application_id,
    }, {})
    :wait()

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
