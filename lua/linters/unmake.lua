-- #################################################################
-- ~/.config/nvim/lua/linters/unmake.lua
-- Qompass AI Diver Native Unmake Linter
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0
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
-- #################################################################
---@source https://github.com/mcandre/unmake
---@source https://github.com/mcandre/unmake/blob/main/WARNINGS.md
---@source https://github.com/mcandre/unmake/blob/main/SYNTAX.md
--
-- Unmake is a recursive POSIX makefile linter focused on portability and
-- makefile correctness/style issues. It does not evaluate Makefiles, so
-- macro-expansion-dependent behavior remains outside its scope.
--
-- Typical upstream output:
--
--   warning: ./Makefile: MAKEFILE_PRECEDENCE: lowercase Makefile to makefile for launch speed
--
--   warning: ./boilerplate-ats.mk:4: SIMPLIFY_AT: replace individual at (@)
--   signs with .SILENT target declaration(s)
--
-- Tiger policy:
--
--   * lint only the current makefile in editor mode;
--   * preserve upstream warning identifiers as diagnostic codes;
--   * preserve approximate upstream line numbers;
--   * treat portability warnings as WARN diagnostics;
--   * distinguish parser/runtime failures as ERROR diagnostics;
--   * bound line length, message size, total output, and diagnostic count;
--   * avoid shell interpolation;
--   * use real filenames because unmake is path-based;
--   * remain compatible with Neovim's Lua 5.1 language contract;
--   * use only current vim.fs / vim.diagnostic APIs.
--
-- For full repository analysis, run:
--
--   unmake .
--
-- separately from editor linting.
--
-- Upstream explicitly documents rules such as:
--
--   CURDIR_ASSIGNMENT_NOP
--   GLOBAL_IGNORE
--   MAKEFILE_PRECEDENCE
--   MISSING_FINAL_EOL
--   PHONY_NOP
--   PHONY_TARGET
--   REDUNDANT_IGNORE_MINUS
--   REDUNDANT_NOTPARALLEL_WAIT
--   REDUNDANT_SILENT_AT
--   STRICT_POSIX
--   WAIT_NOP
--   WD_NOP
--
-- Rule policy is owned by unmake itself; this Lua module only executes and
-- translates diagnostics.

local diagnostic = vim.diagnostic
local fs = vim.fs

local MAX_DIAGNOSTICS = 512
local MAX_LINE_BYTES = 16 * 1024
local MAX_MESSAGE_BYTES = 2048
local MAX_OUTPUT_BYTES = 8 * 1024 * 1024
local SOURCE = 'unmake'

---@type string[]
local ROOT_MARKERS = {
  'GNUmakefile',
  'makefile',
  'Makefile',
  '.git',
  '.hg',
  '.svn',
}

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
local function compact(value)
  return vim.trim(
    value:gsub(
      '%s+',
      ' '
    )
  )
end

---@param value string
---@param limit integer
---@return string
local function truncate(value, limit)
  if #value <= limit then
    return value
  end

  if limit <= 3 then
    return value:sub(
      1,
      limit
    )
  end

  return value:sub(
    1,
    limit - 3
  ) .. '...'
end

---@param value any
---@return integer
local function zero_based_line(value)
  local number = tonumber(value)

  if number == nil then
    return 0
  end

  local line = math.floor(number)

  if line <= 1 then
    return 0
  end

  return line - 1
end

---@param output string
---@return string
local function strip_ansi(output)
  return output:gsub(
    '\27%[[%d;]*[mK]',
    ''
  )
end

---@param context LintContext
---@return string
local function project_root(context)
  local context_root = string_value(
    context.root
  )

  if context_root ~= nil then
    return fs.normalize(
      context_root
    )
  end

  local filename = string_value(
    context.filename
  )

  if filename ~= nil then
    local detected = fs.root(
      filename,
      ROOT_MARKERS
    )

    if
      type(detected) == 'string'
      and detected ~= ''
    then
      return fs.normalize(
        detected
      )
    end

    local parent = fs.dirname(
      filename
    )

    if
      type(parent) == 'string'
      and parent ~= ''
    then
      return fs.normalize(
        parent
      )
    end
  end

  local cwd = string_value(
    context.cwd
  )

  if cwd ~= nil then
    return fs.normalize(
      cwd
    )
  end

  return fs.normalize(
    vim.fn.getcwd()
  )
end

---@param path string
---@param context LintContext
---@return string
local function absolute_path(
  path,
  context
)
  if path == '' then
    return ''
  end

  if fs.isabs(path) then
    return fs.normalize(
      path
    )
  end

  return fs.normalize(
    fs.joinpath(
      project_root(context),
      path
    )
  )
end

---@param left string
---@param right string
---@return boolean
local function same_path(left, right)
  if
    left == ''
    or right == ''
  then
    return false
  end

  return fs.normalize(left)
    == fs.normalize(right)
end

---@param level string?
---@return integer
local function severity(level)
  if level == nil then
    return diagnostic.severity.WARN
  end

  local normalized = level:lower()

  if
    normalized == 'error'
    or normalized == 'fatal'
  then
    return diagnostic.severity.ERROR
  end

  if
    normalized == 'warning'
    or normalized == 'warn'
  then
    return diagnostic.severity.WARN
  end

  if
    normalized == 'info'
    or normalized == 'information'
  then
    return diagnostic.severity.INFO
  end

  if normalized == 'hint' then
    return diagnostic.severity.HINT
  end

  return diagnostic.severity.WARN
end

---@class UnmakeFinding
---@field code string
---@field line integer
---@field message string
---@field path string
---@field severity string

---@param line string
---@return UnmakeFinding?
local function parse_finding(line)
  if
    line == ''
    or #line > MAX_LINE_BYTES
  then
    return nil
  end

  local level
  local path
  local line_number
  local code
  local message

  --
  -- Line-aware form:
  --
  --   warning: ./foo.mk:4: SIMPLIFY_AT: replace ...
  --
  level,
    path,
    line_number,
    code,
    message =
    line:match(
      '^([%a]+):%s+(.+):(%d+):%s+([A-Z][A-Z0-9_]+):%s+(.+)$'
    )

  if
    level ~= nil
    and path ~= nil
    and line_number ~= nil
    and code ~= nil
    and message ~= nil
  then
    return {
      code = code,

      line = tonumber(line_number) or 1,

      message = message,

      path = path,

      severity = level,
    }
  end

  --
  -- File-level form:
  --
  --   warning: ./Makefile: MAKEFILE_PRECEDENCE: lowercase ...
  --
  level,
    path,
    code,
    message =
    line:match(
      '^([%a]+):%s+(.+):%s+([A-Z][A-Z0-9_]+):%s+(.+)$'
    )

  if
    level == nil
    or path == nil
    or code == nil
    or message == nil
  then
    return nil
  end

  return {
    code = code,

    line = 1,

    message = message,

    path = path,

    severity = level,
  }
end

---@param finding UnmakeFinding
---@param context LintContext
---@return vim.Diagnostic
local function finding_diagnostic(
  finding,
  context
)
  local lnum = zero_based_line(
    finding.line
  )

  local message = compact(
    finding.message
  )

  local filename = string_value(
    context.filename
  )

  if filename ~= nil then
    local absolute = absolute_path(
      finding.path,
      context
    )

    if not same_path(
      absolute,
      fs.normalize(filename)
    )
    then
      --
      -- Editor mode should normally lint only the current file, but unmake is
      -- recursive by design and future CLI behavior may still surface another
      -- path. Never attach another file's coordinates to this buffer.
      --
      message = string.format(
        '%s: %s',
        finding.path,
        message
      )

      lnum = 0
    end
  end

  return {
    bufnr = context.bufnr,

    code = finding.code,

    col = 0,

    end_col = 0,

    end_lnum = lnum,

    lnum = lnum,

    message = truncate(
      message,
      MAX_MESSAGE_BYTES
    ),

    severity = severity(
      finding.severity
    ),

    source = SOURCE,

    user_data = {
      path = finding.path,

      rule = finding.code,

      unmake_severity = finding.severity,
    },
  }
end

---@param line string
---@return boolean
local function operational_error(line)
  local lower = line:lower()

  return lower:find(
    'error:',
    1,
    true
  ) ~= nil
    or lower:find(
      'fatal:',
      1,
      true
    ) ~= nil
    or lower:find(
      'failed',
      1,
      true
    ) ~= nil
    or lower:find(
      'cannot',
      1,
      true
    ) ~= nil
    or lower:find(
      'invalid',
      1,
      true
    ) ~= nil
    or lower:find(
      'parse',
      1,
      true
    ) ~= nil
end

---@param output string
---@return string?
local function error_message(output)
  local text = strip_ansi(
    vim.trim(output)
  )

  if text == '' then
    return nil
  end

  for raw_line in text:gmatch(
    '[^\r\n]+'
  ) do
    local line = compact(
      raw_line
    )

    if operational_error(line) then
      return truncate(
        line,
        MAX_MESSAGE_BYTES
      )
    end
  end

  return nil
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse_failure(
  output,
  context
)
  local message = error_message(
    output
  )

  if message == nil then
    return {}
  end

  local line_number =
    output:match(
      ':(%d+):'
    )
      or output:match(
        '[Ll]ine%s+(%d+)'
      )

  local lnum = zero_based_line(
    line_number
  )

  return {
    {
      bufnr = context.bufnr,

      code = 'unmake-error',

      col = 0,

      end_col = 0,

      end_lnum = lnum,

      lnum = lnum,

      message = message,

      severity = diagnostic.severity.ERROR,

      source = SOURCE,
    },
  }
end

---@param context LintContext
---@return vim.Diagnostic[]
local function oversized_output(context)
  return {
    {
      bufnr = context.bufnr,

      code = 'output-limit',

      col = 0,

      end_col = 0,

      end_lnum = 0,

      lnum = 0,

      message = string.format(
        'unmake output exceeded the %d-byte parser limit',
        MAX_OUTPUT_BYTES
      ),

      severity = diagnostic.severity.WARN,

      source = SOURCE,
    },
  }
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse(output, context)
  assert(
    type(context) == 'table',
    'unmake parser requires LintContext'
  )

  assert(
    type(context.bufnr) == 'number',
    'unmake parser requires context.bufnr'
  )

  if output == '' then
    return {}
  end

  if #output > MAX_OUTPUT_BYTES then
    return oversized_output(
      context
    )
  end

  local text = strip_ansi(
    output
  )

  ---@type vim.Diagnostic[]
  local diagnostics = {}

  ---@type string[]
  local failures = {}

  for raw_line in text:gmatch(
    '[^\r\n]+'
  ) do
    if
      #diagnostics
      >= MAX_DIAGNOSTICS
    then
      break
    end

    local line = vim.trim(
      raw_line
    )

    if line ~= '' then
      local finding = parse_finding(
        line
      )

      if finding ~= nil then
        diagnostics[
          #diagnostics + 1
        ] = finding_diagnostic(
          finding,
          context
        )
      elseif operational_error(line) then
        failures[
          #failures + 1
        ] = line
      end
    end
  end

  if
    #diagnostics == 0
    and #failures > 0
  then
    return parse_failure(
      table.concat(
        failures,
        '\n'
      ),
      context
    )
  end

  return diagnostics
end

---@param context LintContext
---@return string[]
local function arguments(context)
  assert(
    type(context) == 'table',
    'unmake arguments require LintContext'
  )

  local filename = string_value(
    context.filename
  )

  if filename == nil then
    return {}
  end

  return {
    --
    -- Upstream accepts paths and recursively scans directories. Supplying the
    -- actual current file keeps editor linting bounded.
    --
    filename,
  }
end

---@type Linter
return {
  args = arguments,

  append_fname = false,

  --
  -- Unmake performs parser-backed portability analysis. Running it on save or
  -- on demand is preferable to invoking it for every text change.
  --
  automatic = false,

  cmd = 'unmake',

  cwd = project_root,

  --
  -- Findings may produce a non-zero status depending on the build/version.
  -- Emitted diagnostics remain authoritative.
  --
  ignore_exitcode = true,

  parser = parse,

  root_markers = ROOT_MARKERS,

  --
  -- unmake is path-oriented, and some checks concern filenames/final-EOL and
  -- relationships that are better represented by the real file.
  --
  stdin = false,

  stream = 'both',

  timeout = 30000,
}