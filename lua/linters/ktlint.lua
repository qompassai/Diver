-- #################################################################
-- /qompassai/Diver/lua/linters/ktlint.lua
-- Qompass AI Diver Native ktlint Tiger Linter
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
---@source https://github.com/pinterest/ktlint
---@source https://pinterest.github.io/ktlint/latest/install/cli/
local diagnostic = vim.diagnostic
local fs = vim.fs
local uv = vim.uv

local ERROR = diagnostic.severity.ERROR
local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 4096
local LINE_LENGTH_MAX = 64 * 1024
local MESSAGE_LENGTH_MAX = 16 * 1024
local OUTPUT_LENGTH_MAX = 16 * 1024 * 1024

local floor = math.floor
local max = math.max
local tonumber = tonumber
local type = type

local SOURCE = 'ktlint'

---@type string[]
local BASELINE_CANDIDATES = {
  'ktlint-baseline.xml',
  '.ktlint-baseline.xml',
  'config/ktlint-baseline.xml',
}

---@class KtlintParsedDiagnostic
---@field filename string?
---@field line integer
---@field column integer
---@field message string
---@field code? string

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

---@param path string
---@return boolean
local function exists(path)
  return uv.fs_stat(path) ~= nil
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

---@param root string
---@return string?
local function baseline_file(root)
  assert(root ~= '', 'root must not be empty')

  for index = 1, #BASELINE_CANDIDATES do
    local candidate = fs.joinpath(root, BASELINE_CANDIDATES[index])

    if exists(candidate) then
      return fs.normalize(candidate)
    end
  end

  return nil
end

---@param message string
---@return string?
local function diagnostic_code(message)
  local code = message:match('%(([%w_.%-]+:[%w_.%-]+)%)%s*$')

  if code ~= nil then
    return code
  end

  code = message:match('%[([%w_.%-]+:[%w_.%-]+)%]%s*$')

  if type(code) == 'string' and code ~= '' then
    return code
  end

  return nil
end

---@param message string
---@param code string|nil
---@return string
local function remove_code_suffix(message, code)
  if code == nil then
    return message
  end

  local escaped = vim.pesc(code)

  message = message:gsub('%s*%(' .. escaped .. '%)%s*$', '')

  message = message:gsub('%s*%[' .. escaped .. '%]%s*$', '')

  return trim(message)
end

---@param line string
---@return KtlintParsedDiagnostic?
local function parse_line(line)
  assert(type(line) == 'string', 'line must be a string')

  if line == '' or #line > LINE_LENGTH_MAX then
    return nil
  end

  line = strip_ansi(line)
  local filename, line_text, column_text, message = line:match('^(.+):(%d+):(%d+):%s*(.+)$')

  if filename == nil or line_text == nil or column_text == nil or message == nil then
    filename = nil

    line_text, column_text, message = line:match('^(%d+):(%d+):%s*(.+)$')
  end

  if line_text == nil or column_text == nil or message == nil then
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
    return nil
  end

  local code = diagnostic_code(message)

  message = remove_code_suffix(message, code)

  return {
    filename = filename,
    line = line_number,
    column = column,
    message = message,
    code = code,
  }
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

---@param candidate string
---@param filename string
---@param root string
---@return boolean
local function belongs_to_buffer(candidate, filename, root)
  return normalize_path(candidate, root) == normalize_path(filename, root)
end

---@param entry KtlintParsedDiagnostic
---@param bufnr integer
---@param filename string
---@param root string
---@return vim.Diagnostic?
local function diagnostic_from_entry(entry, bufnr, filename, root)
  if entry.filename ~= nil and entry.filename ~= '' and not belongs_to_buffer(entry.filename, filename, root) then
    return nil
  end
  local lnum = max(entry.line - 1, 0)

  local col = max(entry.column - 1, 0)

  return {
    bufnr = bufnr,

    lnum = lnum,
    end_lnum = lnum,

    col = col,
    end_col = col + 1,

    message = entry.message,

    severity = WARN,

    source = SOURCE,
    code = entry.code,

    user_data = {
      rule = entry.code,
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

  assert(type(context) == 'table', 'ktlint parser requires a LintContext')

  ---@cast context LintContext

  assert(type(context.bufnr) == 'number' and context.bufnr >= 0, 'context.bufnr must be a valid buffer number')

  assert(type(context.filename) == 'string' and context.filename ~= '', 'context.filename must be a non-empty string')

  assert(type(context.root) == 'string' and context.root ~= '', 'context.root must be a non-empty string')

  assert(#output <= OUTPUT_LENGTH_MAX, 'ktlint output exceeded maximum size')

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

  assert(type(context.root) == 'string' and context.root ~= '', 'context.root must be a non-empty string')
  local argv = {
    '--stdin',
    '--stdin-path',
    context.filename,
    '--log-level=none',
    '--reporter=plain',
  }

  local baseline = baseline_file(context.root)

  if baseline ~= nil then
    argv[#argv + 1] = '--baseline=' .. baseline
  end

  return argv
end

---@param context LintContext
---@return string
local function cwd(context)
  assert(type(context.root) == 'string' and context.root ~= '', 'context.root must be a non-empty string')

  return fs.normalize(context.root)
end

return ---@type Linter
{
  automatic = true,

  cmd = 'ktlint',

  args = args,

  append_fname = false,

  cwd = cwd,

  ignore_exitcode = true,

  parser = parse,

  root_markers = {
    --
    --
    '.editorconfig',

    --
    --
    'build.gradle',
    'build.gradle.kts',

    'gradle.properties',
    'gradlew',

    'settings.gradle',
    'settings.gradle.kts',

    --
    -- Optional ktlint baseline.
    --
    '.ktlint-baseline.xml',
    'ktlint-baseline.xml',

    --
    -- Generic repository boundary.
    --
    '.git',
  },

  stdin = true,

  --
  --
  stream = 'stderr',

  timeout = 30000,
}
