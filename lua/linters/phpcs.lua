-- #################################################################
-- /qompassai/lua/linters/phpcs.lua
-- Qompass AI PHP_CodeSniffer
-- SPDX-License-Identifier: Apache-2.0
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--
--     https://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
-- implied. See the License for the specific language governing
-- permissions and limitations under the License.
-- #################################################################
--
-- Project configuration is one of the four conventional names below
-- (phpcs.xml[.dist] / .phpcs.xml[.dist]); when present, its absolute
-- path is passed explicitly via --standard rather than relying on
-- phpcs's own upward directory search, so behavior is identical
-- regardless of cwd. When absent, PSR12 is the explicit fallback
-- standard -- there is no bundled ruleset shipped by this module.
--
-- --severity=1 is passed explicitly because phpcs's own default
-- reporting threshold is 5 (confirmed from the CLI help text), which
-- silently hides lower-severity sniff violations. This module always
-- asks for everything and lets diagnostic severity mapping (below)
-- decide what surfaces, rather than letting phpcs pre-filter.
--
-- Exit codes (confirmed from the current squizlabs/PHP_CodeSniffer
-- docs): 0 = no violations, 1 = violations found, none fixable,
-- 2 = violations found, some fixable by phpcbf. All three are valid
-- "ran successfully and produced JSON" outcomes; anything else is a
-- genuine crash and is deliberately left for the runner's normal
-- failure path. NOTE: exit code semantics have changed across major
-- PHPCS versions historically -- if the project pins an old phpcs,
-- double check this against `phpcs -h` output.
--
-- Runner owns cancellation, stale-job suppression, stderr and
-- process failures. This module only declares cmd/args/parser.
--
-- JSON shape confirmed directly from the squizlabs Reporting wiki
-- page's own documented example:
--   { totals: { errors, warnings, fixable },
--     files: { [path]: { errors, warnings,
--       messages: [ { message, source, severity, type, line,
--         column, fixable }, ... ] } } }
-- This is the one PHP linter of the four written so far where the
-- JSON schema itself is directly documented rather than inferred.

local fs = vim.fs
local uv = vim.uv
local SOURCE = 'phpcs'
local PHP = '/usr/bin/php'
local VENDOR_BINARY = 'vendor/bin/phpcs'
local DEFAULT_STANDARD = 'PSR12'

-- Explicit bounds. No unbounded loop or unbounded buffer anywhere
-- in this module; every collection this file walks has a ceiling.
local MAX_OUTPUT = 16 * 1024 * 1024
local MAX_DIAGNOSTICS = 512
local MAX_FILES = 1024
local MAX_RECORDS = 10000

local CONFIG_NAMES = {
  'phpcs.xml',
  'phpcs.xml.dist',
  '.phpcs.xml',
  '.phpcs.xml.dist',
}

-- phpcs's own "type" field is authoritative and documented (ERROR
-- or WARNING); this is a direct mapping, not an editorial guess
-- the way phpmd's priority or phpinsights's category were.
local TYPE_SEVERITY = {
  ERROR = vim.diagnostic.severity.ERROR,
  WARNING = vim.diagnostic.severity.WARN,
}
local DEFAULT_SEVERITY = vim.diagnostic.severity.WARN

---@param path string
---@param cwd string
---@return string
local function canonical(path, cwd)
  if path:sub(1, 1) ~= '/' then
    path = fs.joinpath(cwd, path)
  end
  return vim.fs.normalize(path)
end

---@param cwd string
---@return string?
local function find_config(cwd)
  for _, name in ipairs(CONFIG_NAMES) do
    local candidate = fs.joinpath(cwd, name)
    if uv.fs_stat(candidate) then
      return candidate
    end
  end
  return nil
end

---@param message_type string?
---@return integer
local function severity_for(message_type)
  if type(message_type) ~= 'string' then
    return DEFAULT_SEVERITY
  end
  return TYPE_SEVERITY[message_type] or DEFAULT_SEVERITY
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic.Set[]
local function parser(output, context)
  local result = {}
  if #output == 0 or #output > MAX_OUTPUT then
    return result
  end

  local ok, decoded = pcall(vim.json.decode, output, { luanil = { object = true, array = true } })
  if not ok or type(decoded) ~= 'table' or type(decoded.files) ~= 'table' then
    return result
  end

  local target = canonical(context.filename, context.cwd)
  local malformed = false
  local file_count = 0
  local records = 0

  for path, entry in pairs(decoded.files) do
    file_count = file_count + 1
    if file_count > MAX_FILES then
      break
    end

    if type(entry) ~= 'table' or type(entry.messages) ~= 'table' then
      malformed = true
    elseif canonical(path, context.cwd) == target then
      for _, msg in ipairs(entry.messages) do
        records = records + 1
        if records > MAX_RECORDS or #result >= MAX_DIAGNOSTICS then
          break
        end

        if type(msg) ~= 'table' then
          malformed = true
        else
          local text = msg.message
          local line = msg.line
          if type(text) ~= 'string' or type(line) ~= 'number' then
            malformed = true
          else
            if msg.fixable then
              text = text .. ' (auto-fixable via phpcbf)'
            end
            table.insert(result, {
              lnum = math.max(line - 1, 0),
              col = math.max((msg.column or 1) - 1, 0),
              severity = severity_for(msg.type),
              message = text,
              source = SOURCE,
              code = msg.source,
            })
          end
        end
      end
    end

    if records > MAX_RECORDS or #result >= MAX_DIAGNOSTICS then
      break
    end
  end

  if malformed and #result == 0 then
    vim.notify_once(
      '[phpcs] received an unrecognized JSON shape; skipping diagnostics for this run',
      vim.log.levels.WARN
    )
  end

  return result
end

---@param context LintContext
---@return string[]
local function args(context)
  local standard = find_config(context.cwd) or DEFAULT_STANDARD
  return {
    '--report=json',
    '-q',
    '--no-colors',
    '--severity=1',
    '--standard=' .. standard,
    context.filename,
  }
end

---@type Linter
local M = {
  cmd = { PHP, VENDOR_BINARY },
  args = args,
  stdin = false,
  -- 0 = clean, 1 = violations (none fixable), 2 = violations (some
  -- fixable); all three carry valid JSON on stdout.
  exit_codes = { 0, 1, 2 },
  root_markers = { 'composer.json' },
  parser = parser,
}

require('linters').register('phpcs', M)

return M