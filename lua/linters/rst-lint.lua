-- #################################################################
-- /qompassai/Diver/lua/linters/rst-lint.lua
-- Qompass AI reStructuredText Lint
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
---@source https://github.com/twolfson/restructuredtext-lint

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

---@class RestructuredTextLintDiagnostic
---@field line? integer
---@field source? string
---@field level? integer
---@field type? string
---@field message? string
---@field full_message? string

---@type table<integer, integer>
local level_severities = {
  [0] = HINT,
  [1] = INFO,
  [2] = WARN,
  [3] = ERROR,
  [4] = ERROR,
}

---@type table<string, integer>
local type_severities = {
  DEBUG = HINT,
  INFO = INFO,
  WARNING = WARN,
  ERROR = ERROR,
  SEVERE = ERROR,
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

---@param value unknown
---@param fallback string
---@return string
local function string_or(value, fallback)
  if type(value) ~= 'string' or value == '' then
    return fallback
  end

  return value
end

---@param value string
---@return string
local function normalize_message(value)
  --
  -- Diagnostic messages should remain single logical messages. Embedded
  -- carriage returns can otherwise produce inconsistent rendering between
  -- diagnostic consumers.
  --
  value = value:gsub('\r\n', '\n')
  value = value:gsub('\r', '\n')

  if #value > MESSAGE_LENGTH_MAX then
    value =
      value:sub(1, MESSAGE_LENGTH_MAX)
      .. '\n[message truncated]'
  end

  return value
end

---@param level integer|number|string|nil
---@param kind string|nil
---@return integer
local function severity(level, kind)
  local numeric = tonumber(level)

  if numeric ~= nil then
    local mapped =
      level_severities[floor(numeric)]

    if mapped ~= nil then
      return mapped
    end
  end

  if type(kind) == 'string' then
    local mapped =
      type_severities[kind:upper()]

    if mapped ~= nil then
      return mapped
    end
  end

  return WARN
end

---@param path string
---@param root string
---@return string
local function normalize_path(path, root)
  assert(path ~= '')
  assert(root ~= '')

  if path:sub(1, 7) == 'file://' then
    local ok, filename = pcall(
      vim.uri_to_fname,
      path
    )

    if
      ok
      and type(filename) == 'string'
      and filename ~= ''
    then
      return fs.normalize(filename)
    end
  end

  if fs.is_absolute(path) then
    return fs.normalize(path)
  end

  return fs.normalize(
    fs.joinpath(root, path)
  )
end

---@param source string|nil
---@param filename string
---@param root string
---@return boolean
local function belongs_to_buffer(
  source,
  filename,
  root
)
  --
  -- A missing source is accepted because docutils can emit diagnostics that
  -- have no concrete source location. Since this linter is invoked with
  -- exactly one filename, such a diagnostic necessarily belongs to the
  -- current invocation.
  --
  if source == nil or source == '' then
    return true
  end

  return normalize_path(source, root) == filename
end

---@param line integer
---@param bufnr integer
---@return integer
local function end_column(line, bufnr)
  if
    bufnr < 1
    or not vim.api.nvim_buf_is_valid(bufnr)
  then
    return 1
  end

  local line_count =
    vim.api.nvim_buf_line_count(bufnr)

  if
    line < 0
    or line >= line_count
  then
    return 1
  end

  local lines = vim.api.nvim_buf_get_lines(
    bufnr,
    line,
    line + 1,
    false
  )

  local text = lines[1]

  if type(text) ~= 'string' then
    return 1
  end

  return max(#text, 1)
end

---@param entry RestructuredTextLintDiagnostic
---@param context LintContext
---@param filename string
---@param root string
---@return vim.Diagnostic?
local function diagnostic_from_entry(
  entry,
  context,
  filename,
  root
)
  if
    not belongs_to_buffer(
      entry.source,
      filename,
      root
    )
  then
    return nil
  end

  --
  -- restructuredtext-lint/docutils reports one-based line numbers.
  --
  -- Some document-wide failures such as anonymous-link mismatches can have
  -- no line at all. Pin those to the first line instead of discarding a real
  -- structural error.
  --
  local lnum = max(
    integer(entry.line, 1) - 1,
    0
  )

  local message = string_or(
    entry.message,
    'reStructuredText lint violation'
  )

  message = normalize_message(message)

  local kind

  if type(entry.type) == 'string' then
    kind = entry.type:upper()

    if kind == '' then
      kind = nil
    end
  end

  return {
    lnum = lnum,
    end_lnum = lnum,

    --
    -- restructuredtext-lint exposes line information but no source column.
    -- Highlighting the line is more accurate than manufacturing a column.
    --
    col = 0,
    end_col = end_column(
      lnum,
      context.bufnr
    ),

    message = message,

    severity = severity(
      entry.level,
      kind
    ),

    source = 'restructuredtext-lint',

    --
    -- There are no individual rule identifiers. The Docutils diagnostic
    -- category is the closest stable classification supplied by the tool.
    --
    code = kind,

    user_data = {
      level = entry.level,
      type = kind,
      source = entry.source,
      full_message = entry.full_message,
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

  assert(
    type(context) == 'table',
    'restructuredtext-lint parser requires a LintContext'
  )

  ---@cast context LintContext

  assert(context.filename ~= '')
  assert(context.root ~= '')

  assert(
    #output <= OUTPUT_LENGTH_MAX,
    'restructuredtext-lint output exceeded maximum size'
  )

  local ok, decoded = pcall(
    json.decode,
    output
  )

  if
    not ok
    or type(decoded) ~= 'table'
  then
    return {}
  end

  local filename =
    fs.normalize(context.filename)

  local root =
    fs.normalize(context.root)

  ---@type vim.Diagnostic.Set[]
  local diagnostics = {}

  local count = min(
    #decoded,
    DIAGNOSTICS_MAX
  )

  for index = 1, count do
    local raw = decoded[index]

    if type(raw) == 'table' then
      ---@cast raw RestructuredTextLintDiagnostic

      local entry =
        diagnostic_from_entry(
          raw,
          context,
          filename,
          root
        )

      if entry ~= nil then
        diagnostics[#diagnostics + 1] =
          entry
      end
    end
  end

  assert(
    #diagnostics <= DIAGNOSTICS_MAX
  )

  return diagnostics
end

---@param context LintContext
---@return string[]
local function args(context)
  assert(context.filename ~= '')
  assert(context.root ~= '')

  return {
    '--format',
    'json',

    --
    -- Tiger-style default:
    --
    -- Warning is the tool's normal threshold and captures structural
    -- problems without promoting Docutils informational chatter into
    -- routine editor diagnostics.
    --
    '--level',
    'warning',

    context.filename,
  }
end

return ---@type Linter
{
  automatic = false,

  --
  -- The package installs both names. Using ordered candidates allows the
  -- native linter runner to prefer the shorter canonical executable while
  -- remaining compatible with environments exposing only the long name.
  --
  cmd = {
    'rst-lint',
    'restructuredtext-lint',
  },

  args = args,

  append_fname = false,

  cwd = function(context)
    assert(context.root ~= '')

    return context.root
  end,

  --
  -- Exit status:
  --
  --   0 = lint clean
  --   1 = internal rst-lint failure
  --   2 = lint violations
  --
  -- The framework must permit nonzero status here because status 2 is the
  -- normal diagnostic-producing result.
  --
  ignore_exitcode = true,

  parser = parse,

  root_markers = {
    --
    -- Python packaging metadata is especially useful because reStructuredText
    -- is commonly used for Python package documentation and README files.
    --
    'pyproject.toml',
    'setup.cfg',
    'setup.py',

    --
    -- Sphinx documentation projects.
    --
    'conf.py',
    'docs/conf.py',

    --
    -- Common repository-level reStructuredText documents.
    --
    'README.rst',
    'CHANGELOG.rst',
    'CONTRIBUTING.rst',

    '.git',
  },

  stdin = false,
  stream = 'stdout',
  timeout = 30000,
}