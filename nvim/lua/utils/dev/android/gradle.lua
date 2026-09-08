-- #################################################################
-- /qompassai/lua/utils/dev/android/gradle.lua
-- Qompass AI Gradle
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

function M.parse_settings_modules(root_dir)
  local content = util.read_file(root_dir .. '/settings.gradle.kts') or util.read_file(root_dir .. '/settings.gradle')

  if not content then
    return {}
  end

  local modules = {}
  local seen = {}

  local function add_module(name)
    name = name:gsub('^:', '')
    if name ~= '' and not seen[name] then
      seen[name] = true
      modules[#modules + 1] = name
    end
  end

  for match in content:gmatch('include%s*%(?["\']([^"\']+)["\']') do
    add_module(match)
  end

  for match in content:gmatch('include%s+[\'"]([^\'"]+)[\'"]') do
    add_module(match)
  end

  return modules
end

function M.is_application_module(root_dir, module)
  local content = util.read_file(root_dir .. '/' .. module .. '/build.gradle.kts')
    or util.read_file(root_dir .. '/' .. module .. '/build.gradle')

  if not content then
    return false
  end

  return content:find('com%.android%.application') ~= nil
    or content:find('"com.android.application"') ~= nil
    or content:find("'com.android.application'") ~= nil
end

function M.find_application_modules(root_dir)
  local apps = {}

  local modules = M.parse_settings_modules(root_dir)
  for i = 1, #modules do
    local module = modules[i]
    if M.is_application_module(root_dir, module) then
      apps[#apps + 1] = module
    end
  end

  if #apps == 0 and M.is_application_module(root_dir, 'app') then
    apps[#apps + 1] = 'app'
  end

  return apps
end

function M.find_application_id(root_dir, module)
  module = module or 'app'

  local content = util.read_file(root_dir .. '/' .. module .. '/build.gradle.kts')
    or util.read_file(root_dir .. '/' .. module .. '/build.gradle')

  if not content then
    return nil
  end

  for line in content:gmatch('[^\r\n]+') do
    if line:find('applicationId') then
      local app_id = line:match('applicationId%s*%(?%s*["\']([^"\']+)["\']')
        or line:match('applicationId%s*=%s*["\']([^"\']+)["\']')
        or line:match('.*["\']([^"\']+)["\']')

      if app_id then
        return app_id
      end
    end
  end

  return nil
end

function M.find_debug_apk(root_dir, module)
  module = module or 'app'
  local module_dir = root_dir .. '/' .. module
  local patterns = {
    module_dir .. '/build/outputs/apk/**/debug/*.apk',
    module_dir .. '/build/outputs/apk/debug/*.apk',
  }

  local newest_path = nil
  local newest_time = 0

  for i = 1, #patterns do
    local files = vim.fn.glob(patterns[i], true, true)
    for j = 1, #files do
      local path = files[j]
      local mtime = vim.fn.getftime(path)
      if mtime > newest_time then
        newest_time = mtime
        newest_path = path
      end
    end
  end

  return newest_path
end

function M.gradle_module_name(module)
  return ':' .. module:gsub('^:', '')
end

return M
