-- #################################################################
-- /qompassai/Diver/lua/linters/joker.lua
-- Qompass AI Diver Native Joker Tiger Linter
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
---@source https://github.com/candid82/joker
---go install github.com/candid82/joker@latest
local diagnostic = vim.diagnostic
local fs = vim.fs

local ERROR = diagnostic.severity.ERROR
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

local SOURCE = 'joker'

---@type table<string, integer>
local SEVERITIES = {
  ['Exception'] = ERROR,
  ['Parse error'] = ERROR,
  ['Parse warning'] = WARN,
  ['Read error'] = ERROR,
  ['Read warning'] = WARN,
}

---@type table<string, string>
local DIALECTS = {
  clojure = 'clj',
  clojurescript = 'cljs',
  edn = 'edn',
  joker = 'joker',
}

---@class JokerParsedDiagnostic
---@field filename string
---@field line integer
---@field column integer
---@field kind string
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
  assert(candidate ~= '', 'candidate must not be empty')

  assert(filename ~= '', 'filename must not be empty')

  assert(root ~= '', 'root must not be empty')

  return normalize_path(candidate, root) == normalize_path(filename, root)
end

---@param kind string
---@return integer
local function severity(kind)
  local mapped = SEVERITIES[kind]

  if mapped ~= nil then
    return mapped
  end

  return INFO
end

---@param line string
---@return JokerParsedDiagnostic?
local function parse_line(line)
  assert(type(line) == 'string', 'line must be a string')

  if line == '' or #line > LINE_LENGTH_MAX then
    return nil
  end

  line = strip_ansi(line)
  local filename, line_text, column_text, kind, message = line:match('^(.+):(%d+):(%d+):%s*([^:]+):%s*(.+)$')

  if filename == nil or line_text == nil or column_text == nil or kind == nil or message == nil then
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

  kind = trim(kind)

  message = normalize_message(message)

  if kind == '' or message == '' then
    return nil
  end

  return {
    filename = filename,
    line = line_number,
    column = column,
    kind = kind,
    message = message,
  }
end

---@param entry JokerParsedDiagnostic
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

  return {
    bufnr = bufnr,

    lnum = lnum,
    end_lnum = lnum,

    col = col,
    end_col = col + 1,

    message = entry.message,

    severity = severity(entry.kind),

    source = SOURCE,
    code = entry.kind,

    user_data = {
      issue_type = entry.kind,
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

  assert(type(context) == 'table', 'joker parser requires a LintContext')

  ---@cast context LintContext

  assert(type(context.bufnr) == 'number' and context.bufnr >= 0, 'context.bufnr must be a valid buffer number')

  assert(type(context.filename) == 'string' and context.filename ~= '', 'context.filename must be a non-empty string')

  assert(type(context.root) == 'string' and context.root ~= '', 'context.root must be a non-empty string')

  assert(#output <= OUTPUT_LENGTH_MAX, 'joker output exceeded maximum size')

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
---@return string?
local function dialect(context)
  local filetype = context.filetype

  if type(filetype) ~= 'string' then
    return nil
  end

  return DIALECTS[filetype]
end

---@param context LintContext
---@return string[]
local function args(context)
  assert(type(context.filename) == 'string' and context.filename ~= '', 'context.filename must be a non-empty string')

  assert(type(context.root) == 'string' and context.root ~= '', 'context.root must be a non-empty string')

  local argv = {
    '--lint',

    '--working-dir',
    context.root,
  }

  local selected_dialect = dialect(context)

  if selected_dialect ~= nil then
    argv[#argv + 1] = '--dialect'

    argv[#argv + 1] = selected_dialect
  end

  argv[#argv + 1] = context.filename

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
  automatic = false,

  cmd = 'joker',

  args = args,

  append_fname = false,

  cwd = cwd,

  ignore_exitcode = true,

  parser = parse,

  root_markers = {
    '.joker',

    'bb.edn',
    'deps.edn',
    'project.clj',
    'shadow-cljs.edn',

    '.git',
  },

  stdin = false,

  stream = 'stdout',

  timeout = 30000,
}
