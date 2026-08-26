-- #################################################################
-- /qompassai/Diver/lua/linters/rumdl.lua
-- Qompass AI Diver Native rumdl Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0
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
local diagnostic = vim.diagnostic
local fn = vim.fn
---@class RumdlDiagnostic
---@field column? integer
---@field file? string
---@field fix? table
---@field fixable? boolean
---@field line? integer
---@field message? string
---@field rule? string
---@field severity? string

---@param value unknown
---@param fallback integer
---@return integer
local function integer(value, fallback)
  if type(value) == 'number' then
    return fn.float2nr(value)
  end
  if type(value) == 'string' then
    return fn.str2nr(value, 10)
  end
  return fallback
end

---@param value unknown
---@return integer
local function severity(value)
  local name = tostring(value or ''):lower()
  if name == 'error' then
    return diagnostic.severity.ERROR
  end
  if name == 'information' or name == 'info' then
    return diagnostic.severity.INFO
  end
  if name == 'hint' then
    return diagnostic.severity.HINT
  end
  return diagnostic.severity.WARN
end

---@param output string
---@param _context LintContext
---@return vim.Diagnostic.Set[]
local function parse(output, _context)
  if vim.trim(output) == '' then
    return {}
  end

  local ok, decoded = pcall(vim.json.decode, output)
  if not ok or type(decoded) ~= 'table' then
    error(('invalid rumdl JSON: %s'):format(vim.trim(output)), 0)
  end

  ---@cast decoded RumdlDiagnostic[]
  local diagnostics = {}
  for _, record in ipairs(decoded) do
    if type(record) == 'table' then
      local lnum = math.max(integer(record.line, 1) - 1, 0)
      local col = math.max(integer(record.column, 1) - 1, 0)
      local rule = tostring(record.rule or 'rumdl')
      local message = tostring(record.message or 'Unknown rumdl diagnostic')

      diagnostics[#diagnostics + 1] = {
        lnum = lnum,
        end_lnum = lnum,
        col = col,
        end_col = col + 1,
        message = ('[%s] %s'):format(rule, message),
        severity = severity(record.severity),
        source = 'rumdl',
        code = rule,
        user_data = {
          fix = record.fix,
          fixable = record.fixable == true,
        },
      }
    end
  end

  return diagnostics
end

return ---@type Linter
{
  cmd = 'rumdl',
  args = function(context)
    return {
      'check',
      '--output-format',
      'json',
      '--color',
      'never',
      '--stdin',
      '--stdin-filename',
      context.filename,
    }
  end,
  append_fname = false,
  cwd = function(context)
    return vim.fs.dirname(context.filename) or context.cwd
  end,
  exit_codes = {
    [0] = true,
    [1] = true,
  },
  parser = parse,
  stdin = true,
  stream = 'stdout',
  timeout = 15000,
}
