-- /qompassai/lua/linters/snakefmt.lua
-- Qompass AI Diver Native Snakefmt Linter
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
---@source https://github.com/snakemake/snakefmt
---@source https://github.com/snakemake/snakefmt/blob/master/README.md
--
-- snakefmt is the separate, opinionated formatter for Snakemake workflows.
-- It is not Snakemake's built-in `snakemake --lint` best-practice checker.
--
-- snakefmt writes files in-place by default.  This Diver linter is deliberately
-- read-only and always uses `--check`:
--
--   snakefmt --check --line-length 88 --quiet <filename>
--
-- `--check` exit status:
--
--   0   File is already formatted.
--   1   File would be reformatted.
--   123 Operational/configuration/parse failure.
--
-- The linter produces one file-level warning for a formatting mismatch because
-- snakefmt's check output is intentionally summary-oriented and does not offer
-- a documented structured diagnostic format.  Use a dedicated formatting
-- action, not this linter, to apply formatting.
--
-- Project defaults may be defined in pyproject.toml.  CLI arguments supplied
-- here intentionally take precedence so editor linting remains non-mutating
-- and has a stable line-length policy.
--
local diagnostic = vim.diagnostic
local fs = vim.fs

local MAX_LINE_BYTES = 16 * 1024
local MAX_MESSAGE_BYTES = 2048
local MAX_OUTPUT_BYTES = 2 * 1024 * 1024
local SOURCE = 'snakefmt'

local LINE_LENGTH = 88

---@type string[]
local ROOT_MARKERS = {
  'Snakefile',
  'workflow/Snakefile',
  'snakefile',
  'workflow',
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
    or lower:find('file not found', 1, true) ~= nil
    or lower:find('parseerror', 1, true) ~= nil
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

---@param context LintContext
---@param code string
---@param message string
---@param severity integer
---@return vim.Diagnostic[]
local function single_diagnostic(context, code, message, severity)
  return {
    {
      bufnr = context.bufnr,

      code = code,

      col = 0,

      end_col = 0,

      end_lnum = 0,

      lnum = 0,

      message = truncate(message, MAX_MESSAGE_BYTES),

      severity = severity,

      source = SOURCE,
    },
  }
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse(output, context)
  assert(type(context) == 'table', 'snakefmt parser requires LintContext')

  assert(type(context.bufnr) == 'number', 'snakefmt parser requires context.bufnr')

  if #output > MAX_OUTPUT_BYTES then
    return single_diagnostic(
      context,
      'output-limit',
      string.format(
        'snakefmt output exceeded the %d-byte parser limit',
        MAX_OUTPUT_BYTES
      ),
      diagnostic.severity.WARN
    )
  end

  local text = strip_ansi(output)
  local failure = error_message(text)

  if failure ~= nil then
    return single_diagnostic(
      context,
      'snakefmt-error',
      failure,
      diagnostic.severity.ERROR
    )
  end

  return single_diagnostic(
    context,
    'format',
    string.format(
      'Snakefile is not formatted according to snakefmt (line length: %d)',
      LINE_LENGTH
    ),
    diagnostic.severity.WARN
  )
end

---@param context LintContext
---@return string[]
local function arguments(context)
  assert(type(context) == 'table', 'snakefmt arguments require LintContext')

  local filename = string_value(context.filename)

  if filename == nil then
    return {}
  end

  return {
    '--check',

    '--line-length',
    tostring(LINE_LENGTH),

    '--quiet',

    filename,
  }
end

---@type Linter
return {
  args = arguments,

  append_fname = false,

  automatic = false,

  cmd = 'snakefmt',

  cwd = project_root,

  ignore_exitcode = true,

  parser = parse,

  root_markers = ROOT_MARKERS,

  stdin = false,

  stream = 'both',

  timeout = 30000,
}