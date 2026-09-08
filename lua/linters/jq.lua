-- #################################################################
-- /qompassai/Diver/lua/linters/jq.lua
-- Qompass AI Diver Native jq Tiger Linter
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
---@source https://jqlang.org/manual/
local diagnostic = vim.diagnostic
local fs = vim.fs
local ERROR = diagnostic.severity.ERROR
local DIAGNOSTICS_MAX = 128
local LINE_LENGTH_MAX = 64 * 1024
local MESSAGE_LENGTH_MAX = 16 * 1024
local OUTPUT_LENGTH_MAX = 4 * 1024 * 1024
local floor = math.floor
local max = math.max
local tonumber = tonumber
local type = type
local SOURCE = 'jq'
local CODE = 'parse-error'
---@class JqParsedDiagnostic
---@field line integer
---@field column integer
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
local function strip_ansi(value)
  assert(type(value) == 'string', 'value must be a string')

  return (value:gsub('\27%[[%d;?]*[ -/]*[@-~]', ''))
end

---@param value string
---@return string
local function normalize_message(value)
  assert(type(value) == 'string', 'value must be a string')

  value = strip_ansi(value)

  value = value:gsub('\r\n', '\n')

  value = value:gsub('\r', '\n')

  value = trim(value)

  if #value > MESSAGE_LENGTH_MAX then
    value = value:sub(1, MESSAGE_LENGTH_MAX) .. '\n[message truncated]'
  end

  return value
end

---@param line string
---@return JqParsedDiagnostic?
local function parse_line(line)
  assert(type(line) == 'string', 'line must be a string')

  if line == '' or #line > LINE_LENGTH_MAX then
    return nil
  end

  line = strip_ansi(line)
  local message, line_text, column_text =
    line:match('^jq:%s*parse error:%s*(.-)%s+at line%s+(%d+),%s*column%s+(%d+)%s*$')
  if message == nil or line_text == nil or column_text == nil then
    return nil
  end

  local line_number = integer(line_text, 0)

  local column = integer(column_text, 0)

  if line_number < 1 then
    return nil
  end

  if column < 1 then
    return nil
  end

  message = normalize_message(message)

  if message == '' then
    message = 'Invalid JSON'
  end

  return {
    line = line_number,
    column = column,
    message = message,
  }
end

---@param entry JqParsedDiagnostic
---@param bufnr integer
---@return vim.Diagnostic
local function diagnostic_from_entry(entry, bufnr)
  assert(bufnr >= 0, 'bufnr must be non-negative')

  local lnum = max(entry.line - 1, 0)
  local col = max(entry.column - 1, 0)
  return {
    bufnr = bufnr,
    lnum = lnum,
    end_lnum = lnum,
    col = col,
    end_col = col + 1,
    message = entry.message,
    severity = ERROR,
    source = SOURCE,
    code = CODE,
    user_data = {
      parser = 'jq',
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

  assert(type(context) == 'table', 'jq parser requires a LintContext')

  ---@cast context LintContext

  assert(type(context.bufnr) == 'number' and context.bufnr >= 0, 'context.bufnr must be a valid buffer number')

  assert(type(context.filename) == 'string' and context.filename ~= '', 'context.filename must be a non-empty string')

  assert(type(context.root) == 'string' and context.root ~= '', 'context.root must be a non-empty string')

  assert(#output <= OUTPUT_LENGTH_MAX, 'jq output exceeded maximum size')

  ---@type vim.Diagnostic.Set[]
  local diagnostics = {}

  for raw_line in output:gmatch('[^\r\n]+') do
    if #diagnostics >= DIAGNOSTICS_MAX then
      break
    end

    local entry = parse_line(raw_line)

    if entry ~= nil then
      diagnostics[#diagnostics + 1] = diagnostic_from_entry(entry, context.bufnr)
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
    --
    -- Return a nonzero status when the parsed result is false/null or when
    -- parsing fails. The parser only consumes actual "parse error" messages,
    -- so a valid JSON value of false/null does not become a diagnostic.
    --
    '--exit-status',

    --
    -- Disable ANSI color unconditionally so stderr remains deterministic.
    --
    '--monochrome-output',

    --
    -- Identity filter: parse the input completely without transforming its
    -- semantics.
    --
    '.',
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
  --
  -- jq is a lightweight parser and consumes the current buffer over stdin.
  -- It is safe to run automatically without depending on an on-disk copy.
  --
  automatic = true,

  cmd = 'jq',

  args = args,

  append_fname = false,

  cwd = cwd,

  --
  -- jq exit statuses include:
  --
  --   0 = successful result
  --   1 = final value was false/null under --exit-status
  --   2 = usage/system error
  --   3 = jq program compilation error
  --   4 = no valid result under --exit-status
  --
  -- JSON parse failures are therefore represented through nonzero process
  -- status, while stderr contains the actual diagnostic we parse.
  --
  ignore_exitcode = true,

  parser = parse,

  root_markers = {
    'package.json',
    'pyproject.toml',
    'Cargo.toml',
    'go.mod',

    '.git',
  },

  --
  -- Analyze the active Neovim buffer, including unsaved edits.
  --
  stdin = true,

  --
  -- jq writes parser diagnostics to stderr.
  --
  stream = 'stderr',

  timeout = 10000,
}
