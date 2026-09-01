-- #################################################################
-- /qompassai/Diver/lua/linters/mago_analyze.lua
-- Qompass AI Mago Analyze
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
---@source https://github.com/carthage-software/mago
---@source https://mago.carthage.software/main/en/tools/analyzer/command-reference
---@source https://mago.carthage.software/main/en/fundamentals/shared-reporting-options

local diagnostic = vim.diagnostic
local fs = vim.fs

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
local tostring = tostring
local type = type

---@class MagoAnalyzePosition
---@field column? integer
---@field line? integer

---@class MagoAnalyzeSpan
---@field end? MagoAnalyzePosition
---@field file? string
---@field start? MagoAnalyzePosition

---@class MagoAnalyzeViolation
---@field code? string
---@field level? string
---@field message? string
---@field severity? string
---@field span? MagoAnalyzeSpan

---@type table<string, integer>
local severities = {
  error = ERROR,
  help = HINT,
  info = INFO,
  note = INFO,
  warn = WARN,
  warning = WARN,
}

---@param value integer|number|string|nil
---@param fallback integer
---@return integer
local function integer(value, fallback)
  assert(fallback >= 0)

  local parsed = tonumber(value)
  if parsed == nil then
    return fallback
  end

  return floor(parsed)
end

---@param level string|nil
---@return integer
local function severity(level)
  if type(level) ~= 'string' then
    return WARN
  end

  return severities[level:lower()] or WARN
end

---@param message string
---@return string
local function normalize_message(message)
  message = message:gsub('\r\n', '\n')
  message = message:gsub('\r', '\n')

  if #message > MESSAGE_LENGTH_MAX then
    return message:sub(1, MESSAGE_LENGTH_MAX) .. '\n[message truncated]'
  end

  return message
end

---@param path string
---@return boolean
local function is_absolute_path(path)
  local first = path:sub(1, 1)
  if first == '/' then
    return true
  end

  local prefix = path:sub(1, 2)
  if prefix == '\\\\' or prefix == '//' then
    return true
  end

  local separator = path:sub(3, 3)
  return first:match('%a') ~= nil and path:sub(2, 2) == ':' and (separator == '/' or separator == '\\')
end

---@param path string
---@param root string
---@return string
local function normalize_path(path, root)
  if is_absolute_path(path) then
    return fs.normalize(path)
  end

  return fs.normalize(fs.joinpath(root, path))
end

---@param path string
---@param filename string
---@param root string
---@return boolean
local function belongs_to_buffer(path, filename, root)
  assert(path ~= '')
  assert(filename ~= '')
  assert(root ~= '')

  if path == '-' or path == '<stdin>' then
    return true
  end

  return normalize_path(path, root) == filename
end

---@param violation MagoAnalyzeViolation
---@param filename string
---@param root string
---@return vim.Diagnostic.Set?
local function diagnostic_from_violation(violation, filename, root)
  local span = violation.span
  if type(span) ~= 'table' then
    return nil
  end

  local path = span.file
  if type(path) ~= 'string' or path == '' then
    return nil
  end

  if not belongs_to_buffer(path, filename, root) then
    return nil
  end

  local start = span.start
  local finish = span['end']
  local start_line = 0
  local start_column = 0

  if type(start) == 'table' then
    start_line = max(integer(start.line, 1) - 1, 0)
    start_column = max(integer(start.column, 1) - 1, 0)
  end

  local end_line = start_line
  local end_column = start_column + 1

  if type(finish) == 'table' then
    end_line = max(integer(finish.line, start_line + 1) - 1, start_line)

    local minimum_end_column = end_line == start_line and start_column + 1 or 0
    end_column = max(integer(finish.column, minimum_end_column + 1) - 1, minimum_end_column)
  end

  local message = violation.message
  if type(message) ~= 'string' or message == '' then
    message = 'Mago analyzer violation'
  else
    message = normalize_message(message)
  end

  local code = violation.code
  if type(code) ~= 'string' or code == '' then
    code = nil
  end

  return {
    lnum = start_line,
    end_lnum = end_line,
    col = start_column,
    end_col = end_column,
    message = message,
    severity = severity(violation.severity or violation.level),
    source = 'mago_analyze',
    code = code,
    user_data = {
      analyzer = 'mago',
    },
  }
end

---@param value any
---@return MagoAnalyzeViolation[]
local function violation_list(value)
  if type(value) ~= 'table' or not vim.islist(value) then
    return {}
  end

  ---@type MagoAnalyzeViolation[]
  local violations = {}
  for index = 1, #value do
    local candidate = value[index]
    if type(candidate) == 'table' then
      violations[#violations + 1] = candidate
    end
  end

  return violations
end

---@param decoded any
---@return MagoAnalyzeViolation[]
local function violations_from_json(decoded)
  if type(decoded) ~= 'table' then
    return {}
  end

  if vim.islist(decoded) then
    return violation_list(decoded)
  end

  local issues = decoded['issues']
  if issues ~= nil then
    return violation_list(issues)
  end

  local diagnostics = decoded['diagnostics']
  if diagnostics ~= nil then
    return violation_list(diagnostics)
  end

  return {}
end

---@param message string
---@return vim.Diagnostic.Set[]
local function parser_diagnostic(message)
  return {
    {
      lnum = 0,
      end_lnum = 0,
      col = 0,
      end_col = 1,
      message = normalize_message(message),
      severity = ERROR,
      source = 'mago_analyze',
      code = 'parser',
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

  assert(type(context) == 'table', 'mago_analyze parser requires a LintContext')
  ---@cast context LintContext

  assert(context.filename ~= '')
  assert(context.root ~= '')

  if #output > OUTPUT_LENGTH_MAX then
    return parser_diagnostic(('Mago output exceeded the %d-byte parser limit'):format(OUTPUT_LENGTH_MAX))
  end

  local ok, decoded = pcall(vim.json.decode, output)
  if not ok then
    return parser_diagnostic('Mago returned invalid JSON: ' .. tostring(decoded))
  end

  local violations = violations_from_json(decoded)
  if #violations == 0 then
    return {}
  end

  local filename = fs.normalize(context.filename)
  local root = fs.normalize(context.root)

  ---@type vim.Diagnostic.Set[]
  local diagnostics = {}
  local violations_count = min(#violations, DIAGNOSTICS_MAX)

  for index = 1, violations_count do
    local entry = diagnostic_from_violation(violations[index], filename, root)
    if entry ~= nil then
      diagnostics[#diagnostics + 1] = entry
    end
  end

  return diagnostics
end

---@param context LintContext
---@return string[]
local function args(context)
  assert(context.filename ~= '')

  return {
    'analyze',

    '--stdin-input',

    '--reporting-format',
    'json',

    context.filename,
  }
end

return ---@type Linter
{
  automatic = false,
  cmd = 'mago',
  args = args,
  append_fname = false,

  cwd = function(context)
    assert(context.root ~= '')
    return context.root
  end,

  ignore_exitcode = true,
  parser = parse,

  root_markers = {
    'mago.toml',
    'mago.yaml',
    'mago.yml',
    'mago.json',
    'mago.dist.toml',
    'mago.dist.yaml',
    'mago.dist.yml',
    'mago.dist.json',
    'composer.json',
    'composer.lock',
    'phpunit.xml',
    'phpunit.xml.dist',
    '.git',
  },

  stdin = true,
  stream = 'stdout',
  timeout = 30000,
}