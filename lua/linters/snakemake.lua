-- /qompassai/lua/linters/snakemake.lua
-- Qompass AI Diver Native Snakemake Linter
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
---@source https://snakemake.readthedocs.io/en/stable/snakefiles/best_practices.html
---@source https://snakemake.readthedocs.io/en/stable/executing/cli.html
--
-- Snakemake includes a workflow code-quality linter:
--
--   snakemake --lint
--
-- This Diver integration scopes linting to the active Snakefile:
--
--   snakemake --lint --snakefile <filename>
--
-- The linter checks Snakemake workflow quality and best practices.  It is not
-- a formatter; use lua/linters/snakefmt.lua for formatting conformance.
--
-- Snakemake's documented linter invocation does not expose a stable,
-- machine-readable diagnostics format.  This parser therefore accepts common
-- file:line and rule-oriented output, while safely surfacing operational
-- failures as one `snakemake-error` diagnostic.
--
-- For complete workflow analysis, run:
--
--   snakemake --lint
--
-- separately from editor linting.  Run from a project root where Snakefile,
-- workflow/Snakefile, or another workflow entrypoint is available.
--
local diagnostic = vim.diagnostic
local fs = vim.fs

local MAX_DIAGNOSTICS = 512
local MAX_LINE_BYTES = 16 * 1024
local MAX_MESSAGE_BYTES = 2048
local MAX_OUTPUT_BYTES = 8 * 1024 * 1024
local SOURCE = 'snakemake'

---@type string[]
local ROOT_MARKERS = {
  'Snakefile',
  'workflow/Snakefile',
  'snakefile',
  'workflow',
  'config',
  'pyproject.toml',
  'environment.yaml',
  'environment.yml',
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
  return vim.trim(value:gsub('%s+', ' '))
end

---@param value string
---@param limit integer
---@return string
local function truncate(value, limit)
  if #value <= limit then
    return value
  end

  if limit <= 3 then
    return value:sub(1, limit)
  end

  return value:sub(1, limit - 3) .. '...'
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
  return output:gsub('\u0017%[[%d;]*[mK]', '')
end

---@param context LintContext
---@return string
local function project_root(context)
  local context_root = string_value(context.root)

  if context_root ~= nil then
    return fs.normalize(context_root)
  end

  local filename = string_value(context.filename)

  if filename ~= nil then
    local detected = fs.root(filename, ROOT_MARKERS)

    if type(detected) == 'string' and detected ~= '' then
      return fs.normalize(detected)
    end

    local parent = fs.dirname(filename)

    if type(parent) == 'string' and parent ~= '' then
      return fs.normalize(parent)
    end
  end

  local cwd = string_value(context.cwd)

  if cwd ~= nil then
    return fs.normalize(cwd)
  end

  return fs.normalize(vim.fn.getcwd())
end

---@param path string
---@param context LintContext
---@return string
local function absolute_path(path, context)
  if path == '' then
    return ''
  end

  if fs.isabs(path) then
    return fs.normalize(path)
  end

  return fs.normalize(fs.joinpath(project_root(context), path))
end

---@param left string
---@param right string
---@return boolean
local function same_path(left, right)
  if left == '' or right == '' then
    return false
  end

  return fs.normalize(left) == fs.normalize(right)
end

---@param level string?
---@return integer
local function severity(level)
  if level == nil then
    return diagnostic.severity.WARN
  end

  local normalized = level:lower()

  if normalized == 'error' or normalized == 'fatal' then
    return diagnostic.severity.ERROR
  end

  if normalized == 'info' or normalized == 'information' then
    return diagnostic.severity.INFO
  end

  if normalized == 'hint' then
    return diagnostic.severity.HINT
  end

  return diagnostic.severity.WARN
end

---@class SnakemakeFinding
---@field line integer
---@field message string
---@field path string
---@field rule string
---@field severity string

---@param line string
---@return SnakemakeFinding?
local function parse_finding(line)
  if line == '' or #line > MAX_LINE_BYTES then
    return nil
  end

  local path
  local line_number
  local level
  local message

  path, line_number, level, message =
    line:match('^(.+):(%d+):%s*([Ee]rror|[Ww]arning|[Ii]nfo|[Hh]int):%s*(.+)$')

  if path ~= nil and line_number ~= nil and level ~= nil and message ~= nil then
    return {
      line = tonumber(line_number) or 1,

      message = message,

      path = path,

      rule = 'lint',

      severity = level,
    }
  end

  path, line_number, message = line:match('^(.+):(%d+):%s*(.+)$')

  if path ~= nil and line_number ~= nil and message ~= nil then
    return {
      line = tonumber(line_number) or 1,

      message = message,

      path = path,

      rule = 'lint',

      severity = 'warning',
    }
  end

  local rule_name

  rule_name, message = line:match('^[Rr]ule%s+["' .. "'" .. ']?([^:"' .. "'" .. ']+)["' .. "'" .. ']?%s*:%s*(.+)$')

  if rule_name ~= nil and message ~= nil then
    return {
      line = 1,

      message = message,

      path = '',

      rule = rule_name,

      severity = 'warning',
    }
  end

  return nil
end

---@param finding SnakemakeFinding
---@param context LintContext
---@return vim.Diagnostic
local function finding_diagnostic(finding, context)
  local lnum = zero_based_line(finding.line)
  local message = compact(finding.message)
  local filename = string_value(context.filename)

  if filename ~= nil and finding.path ~= '' then
    local absolute = absolute_path(finding.path, context)

    if not same_path(absolute, fs.normalize(filename)) then
      message = string.format('%s: %s', finding.path, message)

      lnum = 0
    end
  end

  return {
    bufnr = context.bufnr,

    code = finding.rule,

    col = 0,

    end_col = 0,

    end_lnum = lnum,

    lnum = lnum,

    message = truncate(message, MAX_MESSAGE_BYTES),

    severity = severity(finding.severity),

    source = SOURCE,

    user_data = {
      path = finding.path,

      rule = finding.rule,

      snakemake_severity = finding.severity,
    },
  }
end

---@param line string
---@return boolean
local function operational_error(line)
  local lower = line:lower()

  return lower:find('error:', 1, true) ~= nil
    or lower:find('fatal:', 1, true) ~= nil
    or lower:find('failed', 1, true) ~= nil
    or lower:find('cannot', 1, true) ~= nil
    or lower:find('invalid', 1, true) ~= nil
    or lower:find('traceback', 1, true) ~= nil
    or lower:find('exception', 1, true) ~= nil
    or lower:find('no snakefile specified', 1, true) ~= nil
    or lower:find('file not found', 1, true) ~= nil
end

---@param output string
---@return string?
local function error_message(output)
  local text = strip_ansi(vim.trim(output))

  if text == '' then
    return nil
  end

  for raw_line in text:gmatch('[^
]+') do
    local line = compact(raw_line)

    if line ~= '' and operational_error(line) then
      return truncate(line, MAX_MESSAGE_BYTES)
    end
  end

  return nil
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse_failure(output, context)
  local message = error_message(output)

  if message == nil then
    return {}
  end

  return {
    {
      bufnr = context.bufnr,

      code = 'snakemake-error',

      col = 0,

      end_col = 0,

      end_lnum = 0,

      lnum = 0,

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
        'snakemake --lint output exceeded the %d-byte parser limit',
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
  assert(type(context) == 'table', 'snakemake parser requires LintContext')

  assert(type(context.bufnr) == 'number', 'snakemake parser requires context.bufnr')

  if output == '' then
    return {}
  end

  if #output > MAX_OUTPUT_BYTES then
    return oversized_output(context)
  end

  local text = strip_ansi(output)

  ---@type vim.Diagnostic[]
  local diagnostics = {}

  ---@type string[]
  local failures = {}

  for raw_line in text:gmatch('[^
]+') do
    if #diagnostics >= MAX_DIAGNOSTICS then
      break
    end

    local line = vim.trim(raw_line)

    if line ~= '' then
      local finding = parse_finding(line)

      if finding ~= nil then
        diagnostics[#diagnostics + 1] = finding_diagnostic(finding, context)
      elseif operational_error(line) then
        failures[#failures + 1] = line
      end
    end
  end

  if #diagnostics == 0 and #failures > 0 then
    return parse_failure(table.concat(failures, '
'), context)
  end

  return diagnostics
end

---@param context LintContext
---@return string[]
local function arguments(context)
  assert(type(context) == 'table', 'snakemake arguments require LintContext')

  local filename = string_value(context.filename)

  if filename == nil then
    return {}
  end

  return {
    '--lint',

    '--snakefile',
    filename,
  }
end

---@type Linter
return {
  args = arguments,

  append_fname = false,

  automatic = false,

  cmd = 'snakemake',

  cwd = project_root,

  ignore_exitcode = true,

  parser = parse,

  root_markers = ROOT_MARKERS,

  stdin = false,

  stream = 'both',

  timeout = 30000,
}