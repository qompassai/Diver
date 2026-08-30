-- #################################################################
-- /qompassai/Diver/lua/linters/bash.lua
-- Qompass AI Diver Native Bash Syntax Linter
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
---@source https://www.gnu.org/software/bash/manual/bash.html

local diagnostic = vim.diagnostic
local fs = vim.fs

local ERROR = diagnostic.severity.ERROR

local DIAGNOSTICS_MAX = 1024
local LINE_LENGTH_MAX = 64 * 1024
local MESSAGE_LENGTH_MAX = 16 * 1024
local OUTPUT_LENGTH_MAX = 4 * 1024 * 1024

local floor = math.floor
local max = math.max
local tonumber = tonumber
local type = type

local SOURCE = 'bash'
local CODE = 'syntax'

---@class BashParsedDiagnostic
---@field filename string
---@field line integer
---@field message string

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

---@param value string
---@return string
local function trim(value)
  assert(type(value) == 'string')

  return (
    value:gsub(
      '^%s*(.-)%s*$',
      '%1'
    )
  )
end

---@param value string
---@return string
local function normalize_message(value)
  assert(type(value) == 'string')

  value = value:gsub('\r\n', '\n')
  value = value:gsub('\r', '\n')

  value = trim(value)

  if #value > MESSAGE_LENGTH_MAX then
    value =
      value:sub(
        1,
        MESSAGE_LENGTH_MAX
      )
      .. '\n[message truncated]'
  end

  return value
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
    fs.joinpath(
      root,
      path
    )
  )
end

---@param candidate string
---@param filename string
---@param root string
---@return boolean
local function belongs_to_buffer(
  candidate,
  filename,
  root
)
  assert(candidate ~= '')
  assert(filename ~= '')
  assert(root ~= '')

  return normalize_path(
    candidate,
    root
  ) == filename
end

---@param line string
---@return BashParsedDiagnostic?
local function parse_line(line)
  assert(type(line) == 'string')

  if
    line == ''
    or #line > LINE_LENGTH_MAX
  then
    return nil
  end

  --
  -- Typical Bash parser output:
  --
  --   file.sh: line 12: syntax error near unexpected token `fi'
  --   file.sh: line 12: `fi'
  --
  -- We intentionally accept only the diagnostic-bearing first form.
  --
  local filename,
    line_number,
    message = line:match(
      '^(.+):%s+line%s+(%d+):%s+(.+)$'
    )

  if
    filename == nil
    or line_number == nil
    or message == nil
  then
    return nil
  end

  local parsed_line =
    integer(line_number, 0)

  if parsed_line < 1 then
    return nil
  end

  message =
    normalize_message(message)

  if message == '' then
    return nil
  end

  --
  -- Bash commonly emits a second source-text line after the useful
  -- diagnostic. Only messages describing a parser failure are retained.
  --
  local lower =
    message:lower()

  local is_diagnostic =
    lower:find(
      'syntax error',
      1,
      true
    ) ~= nil
    or lower:find(
      'unexpected eof',
      1,
      true
    ) ~= nil
    or lower:find(
      'unexpected end of file',
      1,
      true
    ) ~= nil
    or lower:find(
      'unterminated',
      1,
      true
    ) ~= nil

  if not is_diagnostic then
    return nil
  end

  return {
    filename = filename,
    line = parsed_line,
    message = message,
  }
end

---@param entry BashParsedDiagnostic
---@param filename string
---@param root string
---@return vim.Diagnostic?
local function diagnostic_from_entry(
  entry,
  filename,
  root
)
  if
    not belongs_to_buffer(
      entry.filename,
      filename,
      root
    )
  then
    return nil
  end

  --
  -- Bash lines are one-based.
  -- vim.Diagnostic lines are zero-based.
  --
  local lnum = max(
    entry.line - 1,
    0
  )

  return {
    lnum = lnum,
    end_lnum = lnum,

    --
    -- Bash's parser error stream normally reports a line but not a reliable
    -- source column. Do not invent semantic precision that Bash didn't give
    -- us.
    --
    col = 0,
    end_col = 1,

    message = entry.message,

    severity = ERROR,

    source = SOURCE,
    code = CODE,
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
    'bash parser requires a LintContext'
  )

  ---@cast context LintContext

  assert(context.filename ~= '')
  assert(context.root ~= '')

  assert(
    #output <= OUTPUT_LENGTH_MAX,
    'bash output exceeded maximum size'
  )

  local filename =
    fs.normalize(context.filename)

  local root =
    fs.normalize(context.root)

  ---@type vim.Diagnostic.Set[]
  local diagnostics = {}

  for line in output:gmatch(
    '[^\r\n]+'
  ) do
    if #diagnostics >= DIAGNOSTICS_MAX then
      break
    end

    local raw =
      parse_line(line)

    if raw ~= nil then
      local entry =
        diagnostic_from_entry(
          raw,
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
    --
    -- noexec:
    --
    -- Read and parse the complete script but execute no commands.
    --
    '-n',

    --
    -- Prevent environment-specific startup behavior from influencing the
    -- syntax-check process.
    --
    '--noprofile',
    '--norc',

    context.filename,
  }
end

---@param context LintContext
---@return string
local function cwd(context)
  assert(context.root ~= '')

  return fs.normalize(
    context.root
  )
end

return ---@type Linter
{
  automatic = true,

  cmd = 'bash',

  args = args,

  append_fname = false,

  cwd = cwd,

  --
  -- A Bash parser error results in a nonzero process exit. That is normal
  -- diagnostic-producing behavior for this adapter.
  --
  ignore_exitcode = true,

  parser = parse,

  root_markers = {
    '.bashrc',
    '.bash_profile',
    '.bash_logout',

    'Bashfile',

    'Makefile',

    '.git',
  },

  stdin = false,

  --
  -- Bash parser diagnostics are written to stderr.
  --
  stream = 'stderr',

  timeout = 15000,
}