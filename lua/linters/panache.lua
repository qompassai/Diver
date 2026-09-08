-- #################################################################
-- /qompassai/lua/linters/panache.lua
-- Qompass AI Panache Linter Spec
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
---@source https://github.com/jolars/panache

local diagnostic = vim.diagnostic
local fs = vim.fs

local ERROR = diagnostic.severity.ERROR
local INFO = diagnostic.severity.INFO
local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 4096
local OUTPUT_LENGTH_MAX = 16 * 1024 * 1024
local PATH_SEPARATOR = '/'

---@class PanacheViolation
---@field code string
---@field column integer
---@field file string
---@field line integer
---@field message string
---@field severity string

---@type table<string, integer>
local severities = {
  error = ERROR,
  info = INFO,
  warning = WARN,
}

---@param value integer|number|string|nil
---@param fallback integer
---@return integer
local function integer(value, fallback)
  assert(type(fallback) == 'number')
  assert(fallback >= 0)
  assert(fallback == math.floor(fallback))

  local parsed = tonumber(value)

  if parsed == nil then
    return fallback
  end

  if parsed ~= parsed then
    return fallback
  end
  if parsed == math.huge or parsed == -math.huge then
    return fallback
  end

  local floored = math.floor(parsed)

  ---@cast floored integer

  return floored
end

---@param level string?
---@return integer
local function severity(level)
  if level == nil or level == '' then
    return WARN
  end

  return severities[level:lower()] or WARN
end

---@param path string
---@return boolean
local function is_absolute_path(path)
  assert(type(path) == 'string')

  if path == '' then
    return false
  end

  if path:sub(1, 1) == PATH_SEPARATOR then
    return true
  end

  if path:match('^%a:[/\\]') then
    return true
  end

  if path:match('^[/\\][/\\]') then
    return true
  end

  return false
end

---@param path string
---@return string
local function normalize_path(path)
  assert(type(path) == 'string' and path ~= '')

  return fs.normalize(path)
end

---@param path string
---@param filename string
---@param root string
---@return boolean
local function belongs_to_buffer(path, filename, root)
  assert(type(path) == 'string' and path ~= '')
  assert(type(filename) == 'string' and filename ~= '')
  assert(type(root) == 'string' and root ~= '')

  if path == '<stdin>' or path == '-' then
    return true
  end

  local candidate

  if is_absolute_path(path) then
    candidate = normalize_path(path)
  else
    candidate = normalize_path(fs.joinpath(root, path))
  end

  return candidate == filename
end

---@param line string
---@return PanacheViolation?
local function parse_line(line)
  assert(type(line) == 'string')

  if line == '' then
    return nil
  end

  local file, line_number, column_number, level, code, message =
    line:match('^(.+):(%d+):(%d+):%s+([%a]+)%[([^%]]+)%]:%s+(.+)$')

  if file == nil or line_number == nil or column_number == nil or level == nil or code == nil or message == nil then
    return nil
  end

  return {
    code = code,
    column = integer(column_number, 1),
    file = file,
    line = integer(line_number, 1),
    message = message,
    severity = level,
  }
end

---@param violation PanacheViolation
---@param bufnr integer
---@param filename string
---@param root string
---@return vim.Diagnostic?
local function diagnostic_from_violation(violation, bufnr, filename, root)
  assert(type(violation) == 'table')
  assert(type(bufnr) == 'number' and bufnr >= 0)
  assert(type(filename) == 'string' and filename ~= '')
  assert(type(root) == 'string' and root ~= '')

  if not belongs_to_buffer(violation.file, filename, root) then
    return nil
  end

  local start_line = math.max(integer(violation.line, 1) - 1, 0)
  local start_column = math.max(integer(violation.column, 1) - 1, 0)

  ---@type vim.Diagnostic
  local entry = {
    bufnr = bufnr,
    code = violation.code,
    col = start_column,
    end_col = start_column + 1,
    end_lnum = start_line,
    lnum = start_line,
    message = violation.message,
    severity = severity(violation.severity),
    source = 'panache',
    user_data = {
      tool = 'panache',
    },
  }

  return entry
end

---@param context LintContext|integer
---@return integer bufnr
---@return string filename
---@return string root
local function context_fields(context)
  if type(context) ~= 'table' then
    error('panache parser requires a LintContext, not an integer context')
  end
  local bufnr = context.bufnr
  local filename = context.filename
  local root = context.root

  assert(type(bufnr) == 'number' and bufnr >= 0)
  assert(type(filename) == 'string' and filename ~= '')
  assert(type(root) == 'string' and root ~= '')

  local integer_bufnr = math.floor(bufnr)

  assert(integer_bufnr == bufnr)

  ---@cast integer_bufnr integer

  return integer_bufnr, filename, root
end

---@param output string
---@param context LintContext|integer
---@return vim.Diagnostic[]
local function parse(output, context)
  assert(type(output) == 'string')

  if output == '' then
    return {}
  end

  assert(#output <= OUTPUT_LENGTH_MAX, 'panache output exceeded maximum size')

  local bufnr, context_filename, context_root = context_fields(context)
  local filename = normalize_path(context_filename)
  local root = normalize_path(context_root)

  ---@type vim.Diagnostic[]
  local diagnostics = {}

  for line in output:gmatch('[^\r\n]+') do
    if #diagnostics >= DIAGNOSTICS_MAX then
      break
    end

    local violation = parse_line(line)

    if violation ~= nil then
      local entry = diagnostic_from_violation(violation, bufnr, filename, root)

      if entry ~= nil then
        diagnostics[#diagnostics + 1] = entry
      end
    end
  end

  assert(#diagnostics <= DIAGNOSTICS_MAX)

  return diagnostics
end

return ---@type Linter
{
  append_fname = false,
  automatic = false,

  args = function(context)
    assert(type(context.filename) == 'string' and context.filename ~= '')

    return {
      '--no-cache',
      '--no-color',
      'lint',
      '--message-format',
      'short',
      context.filename,
    }
  end,

  cmd = 'panache',

  cwd = function(context)
    assert(type(context.root) == 'string' and context.root ~= '')

    return context.root
  end,

  ignore_exitcode = true,
  parser = parse,

  root_markers = {
    '.panache.toml',
    'panache.toml',
    '.config/panache.toml',
    '_quarto.yml',
    '.quarto.yml',
    'quarto.yml',
    '.git',
  },

  stdin = false,
  stream = 'stdout',
  timeout = 30000,
}