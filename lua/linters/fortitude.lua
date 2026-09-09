-- #################################################################
-- ~/.config/nvim/lua/linters/fortitude.lua
-- Qompass AI Diver Native Fortitude Fortran Linter
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
---@source https://github.com/PlasmaFAIR/fortitude
---@source https://github.com/PlasmaFAIR/fortitude/blob/main/docs/configuration.md
---@source https://github.com/PlasmaFAIR/fortitude/blob/main/crates/fortitude_linter/src/diagnostics/message/json.rs
---@source https://neovim.io/doc/user/diagnostic/
---@source https://neovim.io/doc/user/lua/
--
-- Arch Linux installation:
--
--   uv tool install fortitude-lint
--
-- Verify:
--
--   fortitude --version
--
-- Tiger policy:
--
--   * lint the current Fortran buffer through stdin;
--   * pass argv directly without shell interpolation;
--   * force non-mutating operation even when project config enables fixes;
--   * request Fortitude's machine-readable JSON output;
--   * retain project rule selection, exclusions, target standard, and preview policy;
--   * retain rule codes, names, documentation URLs, filenames, and fix summaries;
--   * convert one-based Fortitude ranges to zero-based Neovim ranges;
--   * bound output, diagnostic count, and message size;
--   * remain compatible with Neovim's LuaJIT language contract.
--
-- Optional environment overrides:
--
--   NVIM_FORTITUDE_EXTEND_SELECT='OB,PORT'
--   NVIM_FORTITUDE_PREVIEW=1
--   NVIM_FORTITUDE_TARGET_STD=f2023
local diagnostic = vim.diagnostic
local fs = vim.fs
local json = vim.json

local MAX_DECODED_FINDINGS = 4096
local MAX_DIAGNOSTICS = 1024
local MAX_MESSAGE_BYTES = 4096
local MAX_OPERATIONAL_LINES = 32
local MAX_OUTPUT_BYTES = 16 * 1024 * 1024
local SOURCE = 'fortitude'
local STDIN_FILENAME = 'stdin.f90'

---@type string[]
local ROOT_MARKERS = {
  'fortitude.toml',
  '.fortitude.toml',
  'fpm.toml',
  'pyproject.toml',
  '.git',
}

---@type table<string, boolean>
local TARGET_STANDARDS = {
  f95 = true,
  f2003 = true,
  f2008 = true,
  f2018 = true,
  f2023 = true,
}

---@class FortitudeLocation
---@field column? integer
---@field row? integer

---@class FortitudeEdit
---@field content? string
---@field end_location? FortitudeLocation
---@field location? FortitudeLocation

---@class FortitudeFix
---@field applicability? string
---@field edits? FortitudeEdit[]
---@field message? string

---@class FortitudeFinding
---@field code? string
---@field end_location? FortitudeLocation
---@field filename? string
---@field fix? FortitudeFix
---@field location? FortitudeLocation
---@field message? string
---@field name? string
---@field severity? string
---@field url? string

---@class FortitudeFixSummary
---@field applicability? string
---@field edit_count integer
---@field message? string

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
  return output:gsub('\27%[[%d;]*[mK]', '')
end

---@param value string?
---@return boolean
local function truthy(value)
  if value == nil then
    return false
  end

  local normalized = value:lower()

  return normalized == '1' or normalized == 'true' or normalized == 'yes' or normalized == 'on'
end

---@param value string?
---@return string[]
local function split_csv(value)
  ---@type string[]
  local result = {}

  if value == nil or value == '' then
    return result
  end

  for item in value:gmatch('[^,]+') do
    local normalized = vim.trim(item)

    if normalized ~= '' then
      result[#result + 1] = normalized
    end
  end

  return result
end

---@param value any
---@return integer
local function zero_based(value)
  ---@type number?
  local number = tonumber(value)

  if number == nil or number ~= number or number == math.huge or number == -math.huge then
    return 0
  end

  local integer = math.floor(number)

  if integer <= 1 then
    return 0
  end

  return integer - 1
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

---@param level string?
---@return integer
local function severity(level)
  if level == nil then
    return diagnostic.severity.WARN
  end

  local normalized = level:lower()

  if normalized == 'error' then
    return diagnostic.severity.ERROR
  end

  if normalized == 'warning' or normalized == 'warn' then
    return diagnostic.severity.WARN
  end

  if normalized == 'information' or normalized == 'info' then
    return diagnostic.severity.INFO
  end

  if normalized == 'hint' then
    return diagnostic.severity.HINT
  end

  return diagnostic.severity.WARN
end

---@param location FortitudeLocation?
---@return integer, integer
local function position(location)
  if type(location) ~= 'table' then
    return 0, 0
  end

  return zero_based(location.row), zero_based(location.column)
end

---@param start_location FortitudeLocation?
---@param finish_location FortitudeLocation?
---@return integer, integer, integer, integer
local function diagnostic_range(start_location, finish_location)
  local lnum, col = position(start_location)
  local end_lnum = lnum
  local end_col = col

  if type(finish_location) == 'table' then
    end_lnum, end_col = position(finish_location)
  end

  if end_lnum < lnum or (end_lnum == lnum and end_col < col) then
    end_lnum = lnum
    end_col = col
  end

  return lnum, col, end_lnum, end_col
end

---@param fix FortitudeFix?
---@return FortitudeFixSummary?
local function fix_summary(fix)
  if type(fix) ~= 'table' then
    return nil
  end

  local edit_count = 0

  if type(fix.edits) == 'table' then
    edit_count = #fix.edits
  end

  local message = string_value(fix.message)

  if message ~= nil then
    message = truncate(compact(message), MAX_MESSAGE_BYTES)
  end

  return {
    applicability = string_value(fix.applicability),
    edit_count = edit_count,
    message = message,
  }
end

---@param finding FortitudeFinding
---@param context LintContext
---@return vim.Diagnostic?
local function finding_diagnostic(finding, context)
  local message = string_value(finding.message)

  if message == nil then
    return nil
  end

  local name = string_value(finding.name)
  local code = string_value(finding.code) or name
  local lnum, col, end_lnum, end_col = diagnostic_range(finding.location, finding.end_location)

  return {
    bufnr = context.bufnr,

    code = code,

    col = col,

    end_col = end_col,

    end_lnum = end_lnum,

    lnum = lnum,

    message = truncate(compact(message), MAX_MESSAGE_BYTES),

    severity = severity(string_value(finding.severity)),

    source = SOURCE,

    user_data = {
      filename = string_value(finding.filename),

      fix = fix_summary(finding.fix),

      name = name,

      url = string_value(finding.url),
    },
  }
end

---@param output string
---@return FortitudeFinding[]?
local function decode_findings(output)
  local text = vim.trim(output)

  if text == '' then
    return {}
  end

  local ok, decoded = pcall(json.decode, text)

  if not ok or type(decoded) ~= 'table' then
    return nil
  end

  local finding_count = #decoded

  if finding_count > MAX_DECODED_FINDINGS then
    finding_count = MAX_DECODED_FINDINGS
  end

  ---@type FortitudeFinding[]
  local findings = {}

  for index = 1, finding_count do
    local finding = decoded[index]

    if type(finding) == 'table' then
      ---@cast finding FortitudeFinding
      findings[#findings + 1] = finding
    end
  end

  return findings
end

---@param output string
---@return string?
local function operational_message(output)
  local text = strip_ansi(vim.trim(output))

  if text == '' then
    return nil
  end

  ---@type string?
  local fallback = nil
  local line_count = 0

  for raw_line in text:gmatch('[^\r\n]+') do
    line_count = line_count + 1

    if line_count > MAX_OPERATIONAL_LINES then
      break
    end

    local line = compact(raw_line)

    if line ~= '' then
      if fallback == nil then
        fallback = line
      end

      local lower = line:lower()

      if
        lower:find('error', 1, true) ~= nil
        or lower:find('failed', 1, true) ~= nil
        or lower:find('cannot', 1, true) ~= nil
        or lower:find('invalid', 1, true) ~= nil
        or lower:find('configuration', 1, true) ~= nil
        or lower:find('panicked', 1, true) ~= nil
      then
        return truncate(line, MAX_MESSAGE_BYTES)
      end
    end
  end

  if fallback == nil then
    return nil
  end

  return truncate(fallback, MAX_MESSAGE_BYTES)
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse_failure(output, context)
  local message = operational_message(output)

  if message == nil then
    return {}
  end

  return {
    {
      bufnr = context.bufnr,

      code = 'fortitude-error',

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

      message = string.format('Fortitude output exceeded the %d-byte parser limit', MAX_OUTPUT_BYTES),

      severity = diagnostic.severity.WARN,

      source = SOURCE,
    },
  }
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse(output, context)
  assert(type(context) == 'table', 'Fortitude parser requires LintContext')

  assert(type(context.bufnr) == 'number', 'Fortitude parser requires context.bufnr')

  if output == '' then
    return {}
  end

  if #output > MAX_OUTPUT_BYTES then
    return oversized_output(context)
  end

  local findings = decode_findings(output)

  if findings == nil then
    return parse_failure(output, context)
  end

  local finding_count = #findings

  if finding_count > MAX_DIAGNOSTICS then
    finding_count = MAX_DIAGNOSTICS
  end

  ---@type vim.Diagnostic[]
  local diagnostics = {}

  for index = 1, finding_count do
    local item = finding_diagnostic(findings[index], context)

    if item ~= nil then
      diagnostics[#diagnostics + 1] = item
    end
  end

  return diagnostics
end

---@param context LintContext
---@return string
local function input_filename(context)
  local filename = string_value(context.filename)

  if filename ~= nil then
    return fs.normalize(filename)
  end

  return STDIN_FILENAME
end

---@param context LintContext
---@return string[]
local function arguments(context)
  assert(type(context) == 'table', 'Fortitude arguments require LintContext')

  ---@type string[]
  local args = {
    'check',
    '--output-format',
    'json',
    '--quiet',
    '--progress-bar',
    'off',
    '--no-fix',
    '--no-fix-only',
    '--no-show-fixes',
  }

  if truthy(string_value(vim.env.NVIM_FORTITUDE_PREVIEW)) then
    args[#args + 1] = '--preview'
  end

  local target_std = string_value(vim.env.NVIM_FORTITUDE_TARGET_STD)

  if target_std ~= nil then
    target_std = target_std:lower()

    if TARGET_STANDARDS[target_std] == true then
      args[#args + 1] = '--target-std'
      args[#args + 1] = target_std
    end
  end

  local extra_rules = split_csv(string_value(vim.env.NVIM_FORTITUDE_EXTEND_SELECT))

  if #extra_rules > 0 then
    args[#args + 1] = '--extend-select'
    args[#args + 1] = table.concat(extra_rules, ',')
  end

  args[#args + 1] = '--stdin-filename'
  args[#args + 1] = input_filename(context)
  args[#args + 1] = '-'

  return args
end

---@type Linter
return {
  args = arguments,

  append_fname = false,

  automatic = true,

  cmd = 'fortitude',

  cwd = project_root,

  ignore_exitcode = true,

  parser = parse,

  root_markers = ROOT_MARKERS,

  stdin = true,

  stream = 'both',

  timeout = 60000,
}

