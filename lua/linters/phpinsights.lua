-- #################################################################
-- /qompassai/lua/linters/phpinsights.lua
-- Qompass AI PHPInsights
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
-- PHPInsights reports at the project level (Code, Complexity,
-- Architecture, Style categories) rather than a single per-line
-- severity. There is exactly one recognized project config name,
-- `phpinsights.php` (no dotfile/.dist variants, unlike phpstan.neon).
-- When no config is present, phpinsights falls back to its own
-- 'default' preset auto-detection; this module does not bundle a
-- replacement config and simply omits --config in that case.
--
-- Runner owns cancellation, stale-job suppression, stderr and
-- process failures. This module only declares cmd/args/parser.
--
-- ASSUMPTION (unverified against a live --format=json sample):
-- the JSON shape is assumed to be
--   { files: { [absolute_path]: { issues: [ {title|message, line,
--     insightClass}, ... ] } }, summary: {...} }
-- The parser below is defensive about missing/renamed keys: any
-- record that doesn't match a recognized shape is skipped and
-- counted as malformed rather than raising. Verify against a real
-- `vendor/bin/phpinsights analyse --format=json` run on this repo
-- and adjust the field lookups in `parser` if the keys differ.

local fs = vim.fs
local uv = vim.uv
local SOURCE = 'phpinsights'
local PHP = '/usr/bin/php'
local VENDOR_BINARY = 'vendor/bin/phpinsights'
local CACHE = fs.joinpath(vim.fn.stdpath('cache'), 'phpinsights')

-- Explicit bounds. No unbounded loop or unbounded buffer anywhere
-- in this module; every collection this file walks has a ceiling.
local MAX_OUTPUT = 16 * 1024 * 1024
local MAX_DIAGNOSTICS = 512
local MAX_FILES = 1024
local MAX_RECORDS = 10000

local CONFIG_NAMES = {
  'phpinsights.php',
}

-- Category -> vim.diagnostic.severity. PHPInsights does not emit a
-- per-issue severity; it emits a category. This mapping is a
-- deliberate editorial choice, not a value from the tool, and is
-- the piece most likely to want tuning per-project.
local CATEGORY_SEVERITY = {
  Code = vim.diagnostic.severity.WARN,
  Architecture = vim.diagnostic.severity.WARN,
  Complexity = vim.diagnostic.severity.INFO,
  Style = vim.diagnostic.severity.HINT,
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

---@param category string?
---@param insight_class string?
---@return integer
local function severity_for(category, insight_class)
  if type(insight_class) == 'string' and insight_class:find('Security', 1, true) then
    return vim.diagnostic.severity.ERROR
  end
  return CATEGORY_SEVERITY[category] or DEFAULT_SEVERITY
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

    if type(entry) ~= 'table' or type(entry.issues) ~= 'table' then
      malformed = true
    elseif canonical(path, context.cwd) == target then
      for _, issue in ipairs(entry.issues) do
        records = records + 1
        if records > MAX_RECORDS or #result >= MAX_DIAGNOSTICS then
          break
        end

        if type(issue) ~= 'table' then
          malformed = true
        else
          local message = issue.message or issue.title
          local line = issue.line or issue.lineNumber or 1
          if type(message) ~= 'string' or type(line) ~= 'number' then
            malformed = true
          else
            table.insert(result, {
              lnum = math.max(line - 1, 0),
              col = 0,
              severity = severity_for(entry.category, issue.insightClass),
              message = message,
              source = SOURCE,
              code = issue.insightClass,
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
      '[phpinsights] received an unrecognized JSON shape; skipping diagnostics for this run',
      vim.log.levels.WARN
    )
  end

  return result
end

---@param context LintContext
---@return string[]
local function args(context)
  local out = {
    'analyse',
    context.filename,
    '--format=json',
    '--no-interaction',
  }
  local config = find_config(context.cwd)
  if config then
    table.insert(out, '--config=' .. config)
  end
  return out
end

---@type Linter
local M = {
  cmd = { PHP, VENDOR_BINARY },
  args = args,
  stdin = false,
  ignore_exitcode = true, -- phpinsights exits non-zero whenever issues are found
  root_markers = { 'composer.json' },
  parser = parser,
}

require('linters').register('phpinsights', M)

return M