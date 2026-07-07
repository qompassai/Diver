-- #################################################################
-- /qompassai/lua/utils/dev/android/util.lua
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

function M.trim(s)
  return (s or ''):gsub('^%s*(.-)%s*$', '%1')
end

function M.get_android_sdk()
  local sdk = vim.fn.expand(vim.env.ANDROID_HOME or vim.g.android_sdk or '')
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

function M.find_gradlew(directory)
  local cwd = directory or vim.fn.getcwd()
  local parent = vim.fn.fnamemodify(cwd, ':h')
  local obj = vim
    .system({
      'find',
      cwd,
      '-maxdepth',
      '1',
      '-name',
      'gradlew',
    }, {})
    :wait()

  local result = obj.stdout
  if result == nil or #result == 0 then
    if cwd == parent then
      return nil
    end
    return M.find_gradlew(parent)
  end

  return {
    cwd = cwd,
    gradlew = M.trim(result),
  }
end

return M
