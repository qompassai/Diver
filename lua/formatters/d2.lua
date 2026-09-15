-- #################################################################
-- /qompassai/lua/formatters/d2.lua
-- Qompass AI Diver D2 Native Formatter Spec
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
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- ---@source https://github.com/d2lang/d2
-- ---@source https://d2lang.com/tour/man
local fs = vim.fs

---@type string[]
local ROOT_MARKERS = {
  '.git',
  '.hg',
  '.svn',
}

---@param value any
---@return string?
local function stringvalue(value)
  if type(value) ~= 'string' or value == '' then
    return nil
  end
  return value
end

---@param context FormatterContext
---@return string
local function projectroot(context)
  assert(type(context) == 'table', 'd2 cwd requires FormatterContext')
  local contextroot = stringvalue(context.root)
  if contextroot ~= nil then
    return fs.normalize(contextroot)
  end
  local filename = stringvalue(context.filename)
  if filename ~= nil then
    local detected = fs.root(filename, ROOT_MARKERS)
    if type(detected) == 'string' and detected ~= '' then
      return fs.normalize(detected)
    end
    local parent = fs.dirname(filename)
    if type(parent) == 'string' and parent ~= '' then
      return fs.normalize(parent)
    end
  end
  local cwd = stringvalue(context.cwd)
  if cwd ~= nil then
    return fs.normalize(cwd)
  end
  return fs.normalize(vim.fn.getcwd())
end

---@param context FormatterContext
---@return string[]
local function arguments(context)
  assert(type(context) == 'table', 'd2 arguments require FormatterContext')
  local tempfile = stringvalue(context.tempfile)
  assert(tempfile, 'd2 fmt requires the runner tempfile')
  return {
    'fmt',
    '--check=false',
    '--',
    tempfile,
  }
end

---@type FormatterSpec
return {
  cmd = 'd2',
  args = arguments,
  mode = 'tempfile',
  output = 'file',
  cwd = projectroot,
  root_markers = ROOT_MARKERS,
  env = {
    NO_COLOR = '1',
    D2_WATCH = '0',
  },
  exit_codes = { 0 },
  automatic = true,
  allow_empty = false,
  extension = 'd2',
}
