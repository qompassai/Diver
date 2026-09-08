-- #################################################################
-- /qompassai/Diver/lua/linters/zlint.lua
-- Qompass AI Diver Native ZLint Tiger Linter
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
---@source https://github.com/DonIsaac/zlint

local diagnostic = vim.diagnostic
local fs = vim.fs

local ERROR = diagnostic.severity.ERROR
local HINT = diagnostic.severity.HINT
local INFO = diagnostic.severity.INFO
local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 4096
local LINE_LENGTH_MAX = 64 * 1024
local MESSAGE_LENGTH_MAX = 16 * 1024
local OUTPUT_LENGTH_MAX = 16 * 1024 * 1024

local floor = math.floor
local max = math.max
local tonumber = tonumber
local type = type

local SOURCE = 'zlint'

---@type table<string, integer>
local SEVERITIES = {
  debug = HINT,
  error = ERROR,
  notice = INFO,
  warning = WARN,
}

---@class ZlintGithubAnnotation
---@field filename string
---@field line integer
---@field column integer
---@field end_line? integer
---@field end_column? integer
---@field severity string
---@field code? string
---@field message string

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
local function github_decode(value)
  assert(type(value) == 'string', 'value must be a string')

  value = value:gsub('%%0[Dd]', '\r')

  value = value:gsub('%%0[Aa]', '\n')

  value = value:gsub('%%3[Aa]', ':')

  value = value:gsub('%%2[Cc]', ',')

  value = value:gsub('%%25', '%%')

  return value
end

---@param value string
---@return string
local function strip_ansi(value)
  assert(type(value) == 'string', 'value must be a string')

  return (value:gsub('\27%[[%d;?]*[ -/]*[@-~]', ''))
end

---@param value string
---@return string
local function normalize_message(value)
  assert(type(value) == 'string', 'value must be a string')

  value = github_decode(value)

  value = strip_ansi(value)

  value = value:gsub('\r\n', '\n')

  value = value:gsub('\r', '\n')

  value = trim(value)

  if #value > MESSAGE_LENGTH_MAX then
    value = value:sub(1, MESSAGE_LENGTH_MAX) .. '\n[message truncated]'
  end

  return value
end

---@param path string
---@param root string
---@return string
local function normalize_path(path, root)
  assert(path ~= '', 'path must not be empty')

  assert(root ~= '', 'root must not be empty')

  path = github_decode(path)

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

---@param candidate string
---@param filename string
---@param root string
---@return boolean
local function belongs_to_buffer(candidate, filename, root)
  assert(candidate ~= '', 'candidate must not be empty')

  assert(filename ~= '', 'filename must not be empty')

  assert(root ~= '', 'root must not be empty')

  return normalize_path(candidate, root) == normalize_path(filename, root)
end

---@param value string
---@return integer
local function severity(value)
  value = value:lower()

  return SEVERITIES[value] or WARN
end

---@param properties string
---@return table<string, string>
local function parse_properties(properties)
  assert(type(properties) == 'string', 'properties must be a string')

  ---@type table<string, string>
  local result = {}

  for field in properties:gmatch('[^,]+') do
    local key, value = field:match('^%s*([^=]+)=(.*)%s*$')

    if key ~= nil and value ~= nil then
      key = trim(key)

      value = trim(value)

      if key ~= '' then
        result[key] = github_decode(value)
      end
    end
  end

  return result
end

---@param line string
---@return ZlintGithubAnnotation?
local function parse_line(line)
  assert(type(line) == 'string', 'line must be a string')

  if line == '' or #line > LINE_LENGTH_MAX then
    return nil
  end

  line = strip_ansi(line)

  local level, properties_text, message = line:match('^::([%a]+)%s+([^:]*)::(.*)$')

  if level == nil or properties_text == nil or message == nil then
    return nil
  end

  local properties = parse_properties(properties_text)

  local filename = properties.file

  local line_number = integer(properties.line, 0)

  local column = integer(properties.col, 1)

  if type(filename) ~= 'string' or filename == '' or line_number < 1 or column < 1 then
    return nil
  end

  message = normalize_message(message)

  if message == '' then
    return nil
  end

  local code = properties.title

  if type(code) == 'string' and code ~= '' then
    code = github_decode(trim(code))
  else
    code = nil
  end

  local end_line = integer(properties.endLine, 0)

  local end_column = integer(properties.endColumn, 0)

  if end_line < 1 then
    end_line = nil
  end

  if end_column < 1 then
    end_column = nil
  end

  return {
    filename = filename,
    line = line_number,
    column = column,
    end_line = end_line,
    end_column = end_column,
    severity = level,
    code = code,
    message = message,
  }
end

---@param entry ZlintGithubAnnotation
---@param bufnr integer
---@param filename string
---@param root string
---@return vim.Diagnostic?
local function diagnostic_from_entry(entry, bufnr, filename, root)
  if not belongs_to_buffer(entry.filename, filename, root) then
    return nil
  end

  local lnum = max(entry.line - 1, 0)

  local col = max(entry.column - 1, 0)

  local end_lnum = lnum

  if entry.end_line ~= nil then
    end_lnum = max(entry.end_line - 1, lnum)
  end

  local end_col = col + 1

  if entry.end_column ~= nil then
    end_col = max(entry.end_column - 1, end_lnum == lnum and col + 1 or 0)
  end

  return {
    bufnr = bufnr,

    lnum = lnum,
    end_lnum = end_lnum,

    col = col,
    end_col = end_col,

    message = entry.message,

    severity = severity(entry.severity),

    source = SOURCE,
    code = entry.code,

    user_data = {
      engine = 'zlint',
      rule = entry.code,
      zlint_severity = entry.severity,
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

  assert(type(context) == 'table', 'zlint parser requires a LintContext')

  ---@cast context LintContext

  assert(type(context.bufnr) == 'number' and context.bufnr >= 0, 'context.bufnr must be a valid buffer number')

  assert(type(context.filename) == 'string' and context.filename ~= '', 'context.filename must be a non-empty string')

  assert(type(context.root) == 'string' and context.root ~= '', 'context.root must be a non-empty string')

  assert(#output <= OUTPUT_LENGTH_MAX, 'zlint output exceeded maximum size')

  local filename = normalize_path(context.filename, context.root)

  local root = fs.normalize(context.root)

  ---@type vim.Diagnostic.Set[]
  local diagnostics = {}

  for raw_line in output:gmatch('[^\r\n]+') do
    if #diagnostics >= DIAGNOSTICS_MAX then
      break
    end

    local entry = parse_line(raw_line)

    if entry ~= nil then
      local result = diagnostic_from_entry(entry, context.bufnr, filename, root)

      if result ~= nil then
        diagnostics[#diagnostics + 1] = result
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
    '--format',
    'github',

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
  cmd = 'zlint',
  args = args,
  append_fname = false,
  cwd = cwd,
  ignore_exitcode = true,
  parser = parse,
  root_markers = {
    'zlint.json',
    'build.zig',
    'build.zig.zon',
    '.git',
  },
  stdin = false,
  stream = 'both',
  timeout = 30000,
}
