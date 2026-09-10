-- /qompassai/lua/linters/typos.lua
-- Qompass AI Diver Native Typos Linter
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
---@source https://github.com/crate-ci/typos
---@source https://github.com/crate-ci/typos/blob/master/docs/reference.md
---@source https://github.com/crate-ci/typos/blob/master/config.schema.json
--
-- typos is a source-code spell checker.  This native integration uses
-- `typos --format json <filename>` because upstream emits JSON Lines:
--
--   {"type":"typo","context":{"path":"lua/example.lua","line_num":12},...}
--
-- A successful spell-check exits with status 0.  Detected typos exit with
-- status 2, which is expected and handled by `ignore_exitcode = true`.
-- Any other failure is surfaced as one `typos-error` diagnostic.
--
-- Project configuration discovery remains upstream-owned.  Run from the
-- detected project root so `_typos.toml`, `typos.toml`, Cargo.toml `[typos]`,
-- pyproject.toml `[tool.typos]`, and parent configuration work normally.
--
-- For complete project analysis, run:
--
--   typos --format json .
--
-- separately from per-buffer editor linting.
--
-- Useful upstream inspection commands:
--
--   typos --dump-config -
--   typos --files
--   typos --identifiers
--   typos --words
--
-- Do not add `--write-changes`, `--diff`, `--no-ignore`, `--hidden`, or
-- `--force-exclude` here.  Editor linting must be read-only, scoped to the
-- active buffer, and must preserve typos' normal project configuration and
-- VCS-ignore behavior.
--
local diagnostic = vim.diagnostic
local fs = vim.fs

local MAX_DIAGNOSTICS = 512
local MAX_LINE_BYTES = 64 * 1024
local MAX_MESSAGE_BYTES = 2048
local MAX_OUTPUT_BYTES = 8 * 1024 * 1024
local MAX_PREVIEW_BYTES = 512
local SOURCE = 'typos'

---@type string[]
local ROOT_MARKERS = {
  '_typos.toml',
  'typos.toml',
  'Cargo.toml',
  'pyproject.toml',
  'package.json',
  'go.mod',
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

---@param value any
---@return integer?
local function integer_value(value)
  local number = tonumber(value)

  if number == nil then
    return nil
  end

  return math.floor(number)
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
  local number = integer_value(value)

  if number == nil or number <= 1 then
    return 0
  end

  return number - 1
end

---@param value any
---@return integer
local function zero_based_column(value)
  local number = integer_value(value)

  if number == nil or number <= 1 then
    return 0
  end

  return number - 1
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

---@param value any
---@return string[]
local function string_list(value)
  if type(value) ~= 'table' then
    return {}
  end

  local values = {}

  for _, item in ipairs(value) do
    local text = string_value(item)

    if text ~= nil then
      values[#values + 1] = text
    end
  end

  return values
end

---@param corrections string[]
---@return string
local function correction_text(corrections)
  if #corrections == 0 then
    return ''
  end

  if #corrections == 1 then
    return string.format(' should be `%s`', corrections[1])
  end

  return string.format(' may be `%s`', table.concat(corrections, '`, `'))
end

---@param typo string
---@param corrections string[]
---@return string
local function finding_message(typo, corrections)
  local word = typo

  if word == '' then
    word = 'spelling'
  end

  return truncate(string.format('`%s`%s', word, correction_text(corrections)), MAX_MESSAGE_BYTES)
end

---@class TyposContext
---@field line_num? integer
---@field path? string

---@class TyposFinding
---@field buffer? string
---@field byte_offset? integer
---@field context? TyposContext
---@field corrections? string[]|{ [string]: any }
---@field typo? string
---@field type? string

---@param raw string
---@return TyposFinding?
local function decode_finding(raw)
  if raw == '' or #raw > MAX_LINE_BYTES then
    return nil
  end

  local ok, decoded = pcall(vim.json.decode, raw)

  if not ok or type(decoded) ~= 'table' then
    return nil
  end

  if decoded.type ~= 'typo' then
    return nil
  end

  return decoded
end

---@param finding TyposFinding
---@param context LintContext
---@return vim.Diagnostic
local function finding_diagnostic(finding, context)
  local finding_context = type(finding.context) == 'table' and finding.context or {}

  local path = string_value(finding_context.path) or ''
  local filename = string_value(context.filename)
  local lnum = zero_based_line(finding_context.line_num)
  local col = zero_based_column(finding.byte_offset)
  local typo = string_value(finding.typo) or ''
  local corrections = string_list(finding.corrections)
  local preview = string_value(finding.buffer) or ''
  local message = finding_message(typo, corrections)

  if filename ~= nil and path ~= '' then
    local absolute = absolute_path(path, context)

    if not same_path(absolute, fs.normalize(filename)) then
      message = truncate(
        string.format('%s: %s', path, message),
        MAX_MESSAGE_BYTES
      )

      lnum = 0
      col = 0
    end
  end

  local end_col = col + #typo

  if end_col < col then
    end_col = col
  end

  return {
    bufnr = context.bufnr,

    code = typo ~= '' and typo or 'typo',

    col = col,

    end_col = end_col,

    end_lnum = lnum,

    lnum = lnum,

    message = message,

    severity = diagnostic.severity.WARN,

    source = SOURCE,

    user_data = {
      byte_offset = integer_value(finding.byte_offset) or 0,

      corrections = corrections,

      path = path,

      preview = truncate(compact(preview), MAX_PREVIEW_BYTES),

      rule = 'typo',

      typo = typo,
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
    or lower:find('unknown argument', 1, true) ~= nil
    or lower:find('could not', 1, true) ~= nil
    or lower:find('permission denied', 1, true) ~= nil
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

      code = 'typos-error',

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
        'typos output exceeded the %d-byte parser limit',
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
  assert(type(context) == 'table', 'typos parser requires LintContext')

  assert(type(context.bufnr) == 'number', 'typos parser requires context.bufnr')

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
      local finding = decode_finding(line)

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
  assert(type(context) == 'table', 'typos arguments require LintContext')

  local filename = string_value(context.filename)

  if filename == nil then
    return {}
  end

  return {
    '--format',
    'json',
    filename,
  }
end

---@type Linter
return {
  args = arguments,

  append_fname = false,

  automatic = false,

  cmd = 'typos',

  cwd = project_root,

  ignore_exitcode = true,

  parser = parse,

  root_markers = ROOT_MARKERS,

  stdin = false,

  stream = 'both',

  timeout = 30000,
}