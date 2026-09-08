-- #################################################################
-- /qompassai/lua/linters/systemd_analyze.lua
-- Qompass AI Systemd Analyze
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
---@source https://www.freedesktop.org/software/systemd/man/latest/systemd-analyze.html?__goaway_challenge=meta-refresh&__goaway_id=44caed9f263ef250d456ec4937eacebb&__goaway_referer=https%3A%2F%2Fwww.google.com%2F
local diagnostic = vim.diagnostic
local fs = vim.fs

local ERROR = diagnostic.severity.ERROR
local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 1024
local LINE_LENGTH_MAX = 16384

---@param value string|number|nil
---@param fallback integer
---@return integer
local function integer(value, fallback)
  assert(fallback >= 0)

  local parsed = tonumber(value)
  if parsed == nil then
    return fallback
  end

  return math.floor(parsed)
end
---@param path string
---@param filename string
---@param root string
---@param basename string
---@return boolean
local function belongs_to_buffer(path, filename, root, basename)
  assert(path ~= '')
  assert(filename ~= '')
  assert(root ~= '')
  assert(basename ~= '')

  if path == basename then
    return true
  end

  local candidate

  if fs.is_absolute(path) then
    candidate = fs.normalize(path)
  else
    candidate = fs.normalize(fs.joinpath(root, path))
  end

  return candidate == filename or fs.basename(candidate) == basename
end

---@param message string
---@return integer
local function severity(message)
  --
  -- systemd-analyze does not emit machine-readable severity metadata
  -- for verify diagnostics. Classify messages that clearly represent
  -- invalid unit syntax/load failures as errors and everything else
  -- conservatively as a warning.
  --
  if
    message:find('Unknown ', 1, true) ~= nil
    or message:find('Invalid ', 1, true) ~= nil
    or message:find('Failed ', 1, true) ~= nil
    or message:find('not executable', 1, true) ~= nil
  then
    return ERROR
  end

  return WARN
end

---@param line string
---@return string?, integer?, string?
local function parse_line(line)
  assert(#line <= LINE_LENGTH_MAX)

  --
  -- Current systemd-analyze verify output can use:
  --
  --   [./foo.service:9] Unknown lvalue 'Foo' in section 'Unit'
  --
  -- or:
  --
  --   foo.service:9: Unknown key name 'Foo' in section 'Service',
  --                  ignoring.
  --

  local path
  local line_number
  local message

  path, line_number, message = line:match('^%[(.-):(%d+)%]%s+(.+)$')

  if path ~= nil then
    return path, integer(line_number, 1), message
  end

  path, line_number, message = line:match('^(.-):(%d+):%s+(.+)$')

  if path ~= nil then
    return path, integer(line_number, 1), message
  end

  return nil
end

---@param output string
---@param context LintContext|integer
---@return vim.Diagnostic.Set[]
local function parse(output, context)
  if output == '' then
    return {}
  end

  assert(type(context) == 'table', 'systemd-analyze parser requires a LintContext')

  ---@cast context LintContext

  assert(context.filename ~= '')
  assert(context.root ~= '')

  local filename = fs.normalize(context.filename)
  local basename = fs.basename(filename)
  local root = context.root

  ---@type vim.Diagnostic.Set[]
  local diagnostics = {}
  local diagnostics_count = 0

  for line in output:gmatch('[^\r\n]+') do
    if diagnostics_count >= DIAGNOSTICS_MAX then
      break
    end

    if #line <= LINE_LENGTH_MAX then
      local path
      local line_number
      local message

      path, line_number, message = parse_line(line)

      if
        path ~= nil
        and line_number ~= nil
        and message ~= nil
        and belongs_to_buffer(path, filename, root, basename)
      then
        local row = math.max(line_number - 1, 0)

        diagnostics_count = diagnostics_count + 1

        diagnostics[diagnostics_count] = {
          lnum = row,
          end_lnum = row,
          col = 0,
          end_col = 1,
          message = message,
          severity = severity(message),
          source = 'systemd-analyze',
        }
      end
    end
  end

  assert(diagnostics_count <= DIAGNOSTICS_MAX)
  assert(diagnostics_count == #diagnostics)

  return diagnostics
end

return ---@type Linter
{
  automatic = false,

  cmd = 'systemd-analyze',

  args = function(context)
    assert(context.filename ~= '')

    return {
      'verify',
      '--generators=no',
      '--man=no',
      '--recursive-errors=no',
      context.filename,
    }
  end,

  append_fname = false,

  cwd = function(context)
    assert(context.root ~= '')

    return context.root
  end,

  ignore_exitcode = true,

  parser = parse,

  root_markers = {
    '.git',
  },

  stdin = false,
  stream = 'stderr',
  timeout = 30000,
}