-- ###########################################################################
-- /qompassai/lua/linters/yamllint.lua
-- Qompass AI Diver Native Yamllint Linter
--
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- ###########################################################################

---@source https://yamllint.readthedocs.io/en/stable/quickstart.html
---@source https://yamllint.readthedocs.io/en/stable/configuration.html
---@source https://yamllint.readthedocs.io/en/stable/rules.html

local diagnostic = vim.diagnostic
local fn = vim.fn
local fs = vim.fs

local ERROR = diagnostic.severity.ERROR
local WARN = diagnostic.severity.WARN
local INFO = diagnostic.severity.INFO

local MAX_DIAGNOSTICS = 1024
local MAX_LINE_BYTES = 64 * 1024
local MAX_MESSAGE_BYTES = 16 * 1024
local MAX_OUTPUT_BYTES = 8 * 1024 * 1024

local SOURCE = 'yamllint'

---@type string[]
local ROOT_MARKERS = {
  '.yamllint',
  '.yamllint.yaml',
  '.yamllint.yml',
  '.git',
}

---@class YamllintDiagnostic
---@field bufnr integer
---@field lnum integer
---@field end_lnum integer
---@field col integer
---@field end_col integer
---@field message string
---@field severity integer
---@field source string
---@field code string?
---@field user_data table?

---@param value any
---@return string?
local function string_value(value)
  if type(value) ~= 'string' or value == '' then
    return nil
  end

  return value
end

---@param value string
---@return string
local function trim(value)
  assert(type(value) == 'string')

  return (value:gsub('^%s*(.-)%s*$', '%1'))
end

---@param value string
---@return string
local function compact(value)
  assert(type(value) == 'string')

  return trim(value:gsub('%s+', ' '))
end

---@param value string
---@param limit integer
---@return string
local function truncate(value, limit)
  assert(type(value) == 'string')
  assert(limit >= 0)

  if #value <= limit then
    return value
  end

  if limit <= 3 then
    return value:sub(1, limit)
  end

  return value:sub(1, limit - 3) .. '...'
end

---@param value string
---@return string
local function strip_ansi(value)
  assert(type(value) == 'string')

  return (value:gsub('\27%[[%d;?]*[ -/]*[@-~]', ''))
end

---@param value any
---@param fallback integer
---@return integer
local function integer(value, fallback)
  assert(fallback >= 0)

  local parsed = tonumber(value)

  if parsed == nil then
    return fallback
  end

  return math.floor(parsed)
end

---@param value any
---@return integer
local function zero_based_line(value)
  local line = integer(value, 0)

  if line <= 1 then
    return 0
  end

  return line - 1
end

---@param value any
---@return integer
local function zero_based_column(value)
  local column = integer(value, 0)

  if column <= 1 then
    return 0
  end

  return column - 1
end

---@param path string
---@return boolean
local function is_absolute(path)
  assert(type(path) == 'string')
  assert(path ~= '')

  return fn.isabsolutepath(path) == 1
end

---@param path string
---@return string
local function normalize(path)
  assert(type(path) == 'string')
  assert(path ~= '')

  return fs.normalize(path)
end

---@param path string
---@param root string
---@return string
local function absolute_path(path, root)
  assert(path ~= '')
  assert(root ~= '')

  if path:sub(1, 7) == 'file://' then
    local ok, filename = pcall(vim.uri_to_fname, path)

    if ok and type(filename) == 'string' and filename ~= '' then
      return normalize(filename)
    end
  end

  if is_absolute(path) then
    return normalize(path)
  end

  return normalize(fs.joinpath(root, path))
end

---@param context LintContext
---@return string
local function project_root(context)
  local configured_root = string_value(context.root)

  if configured_root ~= nil then
    return normalize(configured_root)
  end

  local filename = string_value(context.filename)

  if filename ~= nil then
    local detected = fs.root(filename, ROOT_MARKERS)

    if type(detected) == 'string' and detected ~= '' then
      return normalize(detected)
    end

    local parent = fs.dirname(filename)

    if type(parent) == 'string' and parent ~= '' then
      return normalize(parent)
    end
  end

  local cwd = string_value(context.cwd)

  if cwd ~= nil then
    return normalize(cwd)
  end

  return normalize(fn.getcwd())
end

---@param candidate string?
---@param context LintContext
---@return boolean
local function belongs_to_buffer(candidate, context)
  local reported = string_value(candidate)

  if reported == nil or reported == '-' or reported == '<stdin>' then
    return true
  end

  local filename = string_value(context.filename)

  if filename == nil then
    return true
  end

  local root = project_root(context)
  local resolved_reported = absolute_path(reported, root)
  local normalized_filename = normalize(filename)

  return resolved_reported == normalized_filename
end

---@param level string
---@return integer
local function severity(level)
  local normalized = level:lower()

  if normalized == 'error' then
    return ERROR
  end

  if normalized == 'warning' or normalized == 'warn' then
    return WARN
  end

  return INFO
end

---@param message string
---@return string, string?
local function parse_message(message)
  assert(type(message) == 'string')

  local text = compact(strip_ansi(message))
  local body, code = text:match('^(.-)%s*%(([^()]*)%)%s*$')

  if body == nil then
    return truncate(text, MAX_MESSAGE_BYTES), nil
  end

  body = trim(body)
  code = trim(code)

  if code == '' then
    code = nil
  end

  return truncate(body, MAX_MESSAGE_BYTES), code
end

---@class YamllintParsedLine
---@field filename string
---@field line integer
---@field column integer
---@field level string
---@field message string

---@param line string
---@return YamllintParsedLine?
local function parse_line(line)
  assert(type(line) == 'string')

  local cleaned = trim(strip_ansi(line))

  if cleaned == '' then
    return nil
  end

  --
  local filename, line_number, column, level, message = cleaned:match('^(.+):(%d+):(%d+):%s*%[([^%]]+)%]%s*(.-)%s*$')

  if filename == nil or line_number == nil or column == nil or level == nil or message == nil then
    return nil
  end

  local parsed_line = integer(line_number, 0)
  local parsed_column = integer(column, 0)

  if parsed_line < 1 or parsed_column < 1 then
    return nil
  end

  return {
    filename = filename,
    line = parsed_line,
    column = parsed_column,
    level = level,
    message = message,
  }
end

---@param parsed YamllintParsedLine
---@param context LintContext
---@return YamllintDiagnostic?
local function make_diagnostic(parsed, context)
  if not belongs_to_buffer(parsed.filename, context) then
    return nil
  end

  local message, code = parse_message(parsed.message)
  local lnum = zero_based_line(parsed.line)
  local col = zero_based_column(parsed.column)

  return {
    bufnr = context.bufnr,
    code = code,
    col = col,
    end_col = col + 1,
    end_lnum = lnum,
    lnum = lnum,
    message = message,
    severity = severity(parsed.level),
    source = SOURCE,
    user_data = {
      yamllint_filename = parsed.filename,
      yamllint_level = parsed.level,
      yamllint_rule = code,
    },
  }
end

---@param output string
---@return string?
local function failure_message(output)
  local text = trim(strip_ansi(output))

  if text == '' then
    return nil
  end

  for raw_line in text:gmatch('[^\r\n]+') do
    local line = compact(raw_line)
    local lower = line:lower()

    if
      lower:find('error', 1, true) ~= nil
      or lower:find('exception', 1, true) ~= nil
      or lower:find('invalid', 1, true) ~= nil
      or lower:find('failed', 1, true) ~= nil
      or lower:find('config', 1, true) ~= nil
    then
      return truncate(line, MAX_MESSAGE_BYTES)
    end
  end

  local first = text:match('([^\r\n]+)')

  if first == nil then
    return nil
  end

  return truncate(compact(first), MAX_MESSAGE_BYTES)
end

---@param output string
---@param context LintContext
---@return YamllintDiagnostic[]
local function parse_failure(output, context)
  local message = failure_message(output)

  if message == nil then
    return {}
  end

  return {
    {
      bufnr = context.bufnr,
      code = 'yamllint-error',
      col = 0,
      end_col = 0,
      end_lnum = 0,
      lnum = 0,
      message = message,
      severity = ERROR,
      source = SOURCE,
    },
  }
end

---@param context LintContext
---@return YamllintDiagnostic[]
local function oversized_output(context)
  return {
    {
      bufnr = context.bufnr,
      code = 'output-limit',
      col = 0,
      end_col = 0,
      end_lnum = 0,
      lnum = 0,
      message = string.format('yamllint output exceeded the %d-byte parser limit', MAX_OUTPUT_BYTES),
      severity = WARN,
      source = SOURCE,
    },
  }
end

---@param output string
---@param context LintContext|integer
---@return YamllintDiagnostic[]
local function parse(output, context)
  if output == '' then
    return {}
  end

  assert(type(context) == 'table', 'yamllint parser requires LintContext')

  ---@cast context LintContext

  assert(type(context.bufnr) == 'number', 'yamllint parser requires context.bufnr')

  if #output > MAX_OUTPUT_BYTES then
    return oversized_output(context)
  end

  ---@type YamllintDiagnostic[]
  local diagnostics = {}

  local recognized = false

  for raw_line in output:gmatch('[^\r\n]+') do
    if #diagnostics >= MAX_DIAGNOSTICS then
      break
    end

    if #raw_line <= MAX_LINE_BYTES then
      local parsed = parse_line(raw_line)

      if parsed ~= nil then
        recognized = true

        local entry = make_diagnostic(parsed, context)

        if entry ~= nil then
          diagnostics[#diagnostics + 1] = entry
        end
      end
    end
  end

  if recognized then
    return diagnostics
  end

  return parse_failure(output, context)
end

---@param context LintContext
---@return string[]
local function args(context)
  assert(type(context) == 'table', 'yamllint args requires LintContext')

  return {
    '--format',
    'parsable',

    '-',
  }
end

---@param context LintContext
---@return string
local function cwd(context)
  assert(type(context) == 'table', 'yamllint cwd requires LintContext')

  return project_root(context)
end

---@type Linter
return {
  automatic = true,
  cmd = 'yamllint',
  args = args,
  append_fname = false,
  cwd = cwd,

  ignore_exitcode = true,

  parser = parse,

  root_markers = ROOT_MARKERS,

  stdin = true,
  stream = 'stdout',
  timeout = 60000,
}