-- #################################################################
-- /qompassai/Diver/lua/linters/regal.lua
-- Qompass AI Diver Native Regal Tiger Linter
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
---@source https://github.com/open-policy-agent/regal

local diagnostic = vim.diagnostic
local fs = vim.fs
local json = vim.json

local ERROR = diagnostic.severity.ERROR
local HINT = diagnostic.severity.HINT
local INFO = diagnostic.severity.INFO
local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 4096
local MESSAGE_LENGTH_MAX = 16 * 1024
local OUTPUT_LENGTH_MAX = 16 * 1024 * 1024

local floor = math.floor
local max = math.max
local min = math.min
local tonumber = tonumber
local type = type

local SOURCE = 'regal'

---@class RegalLocation
---@field col? integer
---@field ["end"]? RegalLocation
---@field file? string
---@field row? integer

---@class RegalViolation
---@field category? string
---@field description? string
---@field level? string
---@field location? RegalLocation
---@field title? string

---@class RegalReport
---@field violations? RegalViolation[]

---@type table<string, integer>
local SEVERITIES = {
  error = ERROR,
  hint = HINT,
  info = INFO,
  warning = WARN,
}

---@param value integer|number|string|nil
---@param fallback integer
---@return integer
local function integer(value, fallback)
  assert(fallback >= 0, 'fallback must be non-negative')

  local parsed = tonumber(value)

  if parsed == nil then
    return fallback
  end

  return floor(parsed)
end

---@param value string
---@return string
local function trim(value)
  assert(type(value) == 'string', 'value must be a string')

  return (value:gsub('^%s*(.-)%s*$', '%1'))
end

---@param value string
---@return string
local function normalize_message(value)
  assert(type(value) == 'string', 'value must be a string')

  value = value:gsub('\r\n', '\n')

  value = value:gsub('\r', '\n')

  value = trim(value)

  if #value > MESSAGE_LENGTH_MAX then
    value = value:sub(1, MESSAGE_LENGTH_MAX) .. '\n[message truncated]'
  end

  return value
end

---@param level string|nil
---@return integer
local function severity(level)
  if type(level) ~= 'string' or level == '' then
    return WARN
  end

  return SEVERITIES[level:lower()] or WARN
end

---@param path string
---@param root string
---@return string
local function normalize_path(path, root)
  assert(path ~= '', 'path must not be empty')

  assert(root ~= '', 'root must not be empty')

  if path:sub(1, 7) == 'file://' then
    local ok, filename = pcall(vim.uri_to_fname, path)

    if ok and type(filename) == 'string' and filename ~= '' then
      return fs.normalize(filename)
    end
  end

  if path:sub(1, 1) == '/' then
    return fs.normalize(path)
  end

  return fs.normalize(fs.joinpath(root, path))
end

---@param path string
---@param filename string
---@param root string
---@return boolean
local function belongs_to_buffer(path, filename, root)
  assert(path ~= '', 'path must not be empty')

  assert(filename ~= '', 'filename must not be empty')

  assert(root ~= '', 'root must not be empty')

  return normalize_path(path, root) == normalize_path(filename, root)
end

---@param violation RegalViolation
---@param bufnr integer
---@param filename string
---@param root string
---@return vim.Diagnostic?
local function diagnostic_from_violation(violation, bufnr, filename, root)
  local location = violation.location

  if type(location) ~= 'table' then
    return nil
  end

  local path = location.file

  if type(path) ~= 'string' or path == '' then
    return nil
  end

  if not belongs_to_buffer(path, filename, root) then
    return nil
  end

  local start_line = max(integer(location.row, 1) - 1, 0)

  local start_column = max(integer(location.col, 1) - 1, 0)

  local end_line = start_line

  local end_column = start_column + 1

  local end_location = location['end']

  if type(end_location) == 'table' then
    end_line = max(integer(end_location.row, start_line + 1) - 1, start_line)

    local minimum_end_column = end_line == start_line and start_column + 1 or 0

    end_column = max(integer(end_location.col, minimum_end_column + 1) - 1, minimum_end_column)
  end

  local title = violation.title

  local description = violation.description

  local message

  if type(description) == 'string' and description ~= '' then
    message = description
  elseif type(title) == 'string' and title ~= '' then
    message = title
  else
    message = 'Regal policy violation'
  end

  message = normalize_message(message)

  local code

  if type(title) == 'string' and title ~= '' then
    code = title
  end

  return {
    bufnr = bufnr,

    lnum = start_line,
    end_lnum = end_line,

    col = start_column,
    end_col = end_column,

    message = message,

    severity = severity(violation.level),

    source = SOURCE,
    code = code,

    user_data = {
      category = violation.category,

      level = violation.level,
    },
  }
end

---@param output string
---@param context LintContext|integer
---@return vim.Diagnostic.Set[]
local function parse(output, context)
  if output == '' then
    return {}
  end

  assert(type(context) == 'table', 'regal parser requires a LintContext')

  ---@cast context LintContext

  assert(type(context.bufnr) == 'number' and context.bufnr >= 0, 'context.bufnr must be a valid buffer number')

  assert(type(context.filename) == 'string' and context.filename ~= '', 'context.filename must be a non-empty string')

  assert(type(context.root) == 'string' and context.root ~= '', 'context.root must be a non-empty string')

  assert(#output <= OUTPUT_LENGTH_MAX, 'regal output exceeded maximum size')

  local ok, decoded = pcall(json.decode, output)

  if not ok or type(decoded) ~= 'table' then
    return {}
  end

  ---@cast decoded RegalReport

  local violations = decoded.violations

  if type(violations) ~= 'table' then
    return {}
  end

  local filename = normalize_path(context.filename, context.root)

  local root = fs.normalize(context.root)

  ---@type vim.Diagnostic.Set[]
  local diagnostics = {}

  local violations_count = min(#violations, DIAGNOSTICS_MAX)

  for index = 1, violations_count do
    local violation = violations[index]

    if type(violation) == 'table' then
      ---@cast violation RegalViolation

      local entry = diagnostic_from_violation(violation, context.bufnr, filename, root)

      if entry ~= nil then
        diagnostics[#diagnostics + 1] = entry
      end
    end
  end

  assert(#diagnostics <= DIAGNOSTICS_MAX, 'diagnostic limit exceeded')

  return diagnostics
end

---@param context LintContext
---@return string[]
local function args(context)
  assert(type(context.filename) == 'string' and context.filename ~= '', 'context.filename must be a non-empty string')

  return {
    'lint',

    '--format=json',

    context.filename,
  }
end

---@param context LintContext
---@return string
local function cwd(context)
  assert(type(context.root) == 'string' and context.root ~= '', 'context.root must be a non-empty string')

  return fs.normalize(context.root)
end

return ---@type Linter
{
  automatic = false,

  cmd = 'regal',

  args = args,

  append_fname = false,

  cwd = cwd,

  ignore_exitcode = true,

  parser = parse,

  root_markers = {
    '.regal',
    '.regal.yaml',
    'rego.mod',
    '.git',
  },

  stdin = false,

  stream = 'stdout',

  timeout = 30000,
}