-- #################################################################
-- ~/.config/nvim/lua/linters/systemdlint.lua
-- Qompass AI Diver Native SystemdLint Linter
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
---@source https://github.com/priv-kweihmann/systemdlint
---@source https://pypi.org/project/systemdlint/
--
-- systemdlint validates systemd unit files independently of the systemd
-- version running on the host. This makes it particularly useful for
-- cross-version, container, image, and embedded-system validation.
--
-- Upstream installation:
--
--   python -m pip install --user systemdlint
--
-- Verify:
--
--   systemdlint --help
--
-- Tiger-style policy:
--
--   * lint the actual unit file rather than stdin;
--   * request a deterministic message format;
--   * retain systemdlint rule IDs as diagnostic codes;
--   * retain upstream severity;
--   * bound output and diagnostic volume;
--   * tolerate non-zero lint exit status;
--   * never execute shell commands;
--   * never mutate the unit being inspected;
--   * use Lua 5.1-compatible syntax;
--   * use only non-deprecated Neovim APIs.
--
-- Unlike `systemd-analyze verify`, systemdlint does not depend on the
-- currently running systemd version and performs additional policy and
-- hardening checks.

local diagnostic = vim.diagnostic
local fs = vim.fs

local MAX_DIAGNOSTICS = 256
local MAX_LINE_BYTES = 16 * 1024
local MAX_MESSAGE_BYTES = 2048
local MAX_OUTPUT_BYTES = 4 * 1024 * 1024
local SOURCE = 'systemdlint'

---@type string[]
local ROOT_MARKERS = {
  '.git',
  '.hg',
  '.svn',
}

---@type table<string, boolean>
local SYSTEMD_DIRECTORIES = {
  ['etc/systemd/system'] = true,
  ['lib/systemd/system'] = true,
  ['usr/lib/systemd/system'] = true,
  ['usr/local/lib/systemd/system'] = true,
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
  return output:gsub('\27%[[%d;]*[mK]', '')
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

  if normalized == 'info' or normalized == 'information' then
    return diagnostic.severity.INFO
  end

  if normalized == 'hint' then
    return diagnostic.severity.HINT
  end

  return diagnostic.severity.WARN
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
    local detected = fs.root(
      filename,
      ROOT_MARKERS
    )

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

---@param filename string
---@return boolean
local function system_unit_path(filename)
  local normalized = fs.normalize(filename)

  for directory in pairs(SYSTEMD_DIRECTORIES) do
    if
      normalized:find(
        '/' .. directory .. '/',
        1,
        true
      ) ~= nil
    then
      return true
    end
  end

  return false
end

---@param filename string
---@return boolean
local function unit_extension(filename)
  local basename = fs.basename(filename)

  if basename == nil then
    return false
  end

  return basename:match('%.service$') ~= nil
    or basename:match('%.socket$') ~= nil
    or basename:match('%.target$') ~= nil
    or basename:match('%.device$') ~= nil
    or basename:match('%.mount$') ~= nil
    or basename:match('%.automount$') ~= nil
    or basename:match('%.swap$') ~= nil
    or basename:match('%.timer$') ~= nil
    or basename:match('%.path$') ~= nil
    or basename:match('%.slice$') ~= nil
    or basename:match('%.scope$') ~= nil
end

---@param context LintContext
---@return boolean
local function applicable(context)
  local filename = string_value(context.filename)

  if filename == nil then
    return false
  end

  if unit_extension(filename) then
    return true
  end

  return system_unit_path(filename)
end

---@param line string
---@return table?
local function parse_line(line)
  if line == '' or #line > MAX_LINE_BYTES then
    return nil
  end

  --
  -- Requested format:
  --
  --   {path}:{line}:{severity} [{id}] - {message}
  --
  -- We intentionally allow ':' inside the path prefix so this remains
  -- reasonably tolerant of unusual filenames.
  --
  local path, line_number, level, code, message =
    line:match(
      '^(.-):(%d+):([^%s]+)%s+%[([^%]]+)%]%s+%-%s+(.+)$'
    )

  if
    path == nil
    or line_number == nil
    or level == nil
    or code == nil
    or message == nil
  then
    return nil
  end

  return {
    code = code,

    line = line_number,

    message = message,

    path = path,

    severity = level,
  }
end

---@param finding table
---@param context LintContext
---@return vim.Diagnostic
local function finding_diagnostic(
  finding,
  context
)
  local lnum = zero_based_line(
    finding.line
  )

  return {
    bufnr = context.bufnr,

    code = string_value(
      finding.code
    ),

    col = 0,

    end_col = 0,

    end_lnum = lnum,

    lnum = lnum,

    message = truncate(
      compact(finding.message),
      MAX_MESSAGE_BYTES
    ),

    severity = severity(
      string_value(finding.severity)
    ),

    source = SOURCE,

    user_data = {
      path = finding.path,

      rule = finding.code,

      severity = finding.severity,
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
        'systemdlint output exceeded the %d-byte parser limit',
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
    'systemdlint parser requires LintContext'
  )

  assert(
    type(context.bufnr) == 'number',
    'systemdlint parser requires context.bufnr'
  )

  if output == '' then
    return {}
  end

  if #output > MAX_OUTPUT_BYTES then
    return oversized_output(context)
  end

  local text = strip_ansi(output)

  ---@type vim.Diagnostic[]
  local diagnostics = {}

  for line in text:gmatch('[^\r\n]+') do
    if #diagnostics >= MAX_DIAGNOSTICS then
      break
    end

    local finding = parse_line(
      vim.trim(line)
    )

    if finding ~= nil then
      diagnostics[#diagnostics + 1] =
        finding_diagnostic(
          finding,
          context
        )
    end
  end

  return diagnostics
end

---@param context LintContext
---@return string[]
local function arguments(context)
  assert(
    type(context) == 'table',
    'systemdlint arguments require LintContext'
  )

  local filename = string_value(
    context.filename
  )

  if filename == nil then
    return {}
  end

  return {
    '--messageformat',
    '{path}:{line}:{severity} [{id}] - {msg}',

    filename,
  }
end

---@type Linter
return {
  args = arguments,

  --
  -- `arguments()` supplies the filename because it must occur after the
  -- systemdlint options.
  --
  append_fname = false,

  automatic = true,

  cmd = 'systemdlint',

  cwd = project_root,

  --
  -- Findings may result in a non-zero process status. The diagnostic stream
  -- remains authoritative.
  --
  ignore_exitcode = true,

  parser = parse,

  root_markers = ROOT_MARKERS,

  --
  -- systemdlint operates on real unit paths and may inspect referenced
  -- units/executables. Supplying unsaved buffer contents through stdin would
  -- therefore give it a different view of the unit than its filesystem
  -- checks.
  --
  stdin = false,

  stream = 'both',

  timeout = 30000,

  --
  -- Optional extension understood by Diver's native lint dispatcher. If your
  -- current Linter type does not yet expose `condition`, either add:
  --
  --   ---@field condition? fun(context: LintContext): boolean
  --
  -- or remove this member and control invocation through linters_by_ft.
  --
  condition = applicable,
}