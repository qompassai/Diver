-- #################################################################
-- /qompassai/lua/linters/phpmd.lua
-- Qompass AI PHPMD
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
-- PHPMD's CLI is positional, not flag-based: `phpmd <path> <format>
-- <ruleset>`. Report format and ruleset are the 2nd/3rd positional
-- args, confirmed against phpmd/phpmd's README. There is no single
-- canonical project ruleset filename the tool enforces; this module
-- checks a handful of community conventions and falls back to
-- PHPMD's own bundled rule sets (comma-joined) if none are found,
-- mirroring the phpstan module's "bundled default when unconfigured"
-- behavior.
--
-- Exit codes are meaningful and distinct (confirmed from README):
--   0 = clean run, no violations
--   1 = PHPMD itself crashed/threw during execution
--   2 = clean run, violations found (the expected "lint hit" case)
--   3 = one or more files could not be processed; others may still
--       have valid results
-- Only 0 and 2 are declared as non-error exits below. 1 and 3
-- surface through the runner's normal failure path instead of being
-- silently swallowed by a blanket ignore_exitcode.
--
-- Runner owns cancellation, stale-job suppression, stderr and
-- process failures. This module only declares cmd/args/parser.
--
-- ASSUMPTION (unverified against a live --format=json sample):
-- PHPMD's JSON renderer is assumed to emit
--   { files: [ { file: string, violations: [ { beginLine, endLine,
--     description, rule, ruleSet, priority, externalInfoUrl }, ... ] }, ... ] }
-- based on the documented XML renderer's field names (the JSON
-- renderer mirrors XMLRenderer's fields 1:1 in PHPMD's own source).
-- The parser is defensive about missing/renamed keys: any record
-- that doesn't match a recognized shape is skipped and counted as
-- malformed rather than raising. Verify against a real
-- `vendor/bin/phpmd <file> json <ruleset>` run and adjust the field
-- lookups in `parser` if the keys differ.

local fs = vim.fs
local uv = vim.uv
local SOURCE = 'phpmd'
local PHP = '/usr/bin/php'
local VENDOR_BINARY = 'vendor/bin/phpmd'
local CACHE = fs.joinpath(vim.fn.stdpath('cache'), 'phpmd')

-- Explicit bounds. No unbounded loop or unbounded buffer anywhere
-- in this module; every collection this file walks has a ceiling.
local MAX_OUTPUT = 16 * 1024 * 1024
local MAX_DIAGNOSTICS = 512
local MAX_FILES = 1024
local MAX_RECORDS = 10000

local CONFIG_NAMES = {
    'phpmd.xml',
    'phpmd.xml.dist',
    '.phpmd.xml',
    '.phpmd.xml.dist',
}

-- PHPMD has no project config file that implies a ruleset the way
-- phpstan.neon implies a level; if no config file is found, this is
-- the built-in ruleset list passed positionally instead.
local DEFAULT_RULESETS = 'cleancode,codesize,controversial,design,naming,unusedcode'

-- PHPMD priority -> vim.diagnostic.severity. 1 is most severe, 5 is
-- least severe, per PHPMD's own priority documentation.
local PRIORITY_SEVERITY = {
    [1] = vim.diagnostic.severity.ERROR,
    [2] = vim.diagnostic.severity.WARN,
    [3] = vim.diagnostic.severity.WARN,
    [4] = vim.diagnostic.severity.INFO,
    [5] = vim.diagnostic.severity.HINT,
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

---@param priority integer?
---@return integer
local function severity_for(priority)
    if type(priority) ~= 'number' then
        return DEFAULT_SEVERITY
    end
    return PRIORITY_SEVERITY[priority] or DEFAULT_SEVERITY
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

    for _, entry in ipairs(decoded.files) do
        file_count = file_count + 1
        if file_count > MAX_FILES then
            break
        end

        if type(entry) ~= 'table' or type(entry.file) ~= 'string' or type(entry.violations) ~= 'table' then
            malformed = true
        elseif canonical(entry.file, context.cwd) == target then
            for _, violation in ipairs(entry.violations) do
                records = records + 1
                if records > MAX_RECORDS or #result >= MAX_DIAGNOSTICS then
                    break
                end

                if type(violation) ~= 'table' then
                    malformed = true
                else
                    local message = violation.description
                    local line = violation.beginLine
                    if type(message) ~= 'string' or type(line) ~= 'number' then
                        malformed = true
                    else
                        table.insert(result, {
                            lnum = math.max(line - 1, 0),
                            col = 0,
                            severity = severity_for(violation.priority),
                            message = message,
                            source = SOURCE,
                            code = violation.rule,
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
            '[phpmd] received an unrecognized JSON shape; skipping diagnostics for this run',
            vim.log.levels.WARN
        )
    end

    return result
end

---@param context LintContext
---@return string[]
local function args(context)
    local ruleset = find_config(context.cwd) or DEFAULT_RULESETS
    return {
        context.filename,
        'json',
        ruleset,
        '--cache',
        '--cache-file=' .. fs.joinpath(CACHE, 'cache.php'),
    }
end

---@type Linter
local M = {
    cmd = { PHP, VENDOR_BINARY },
    args = args,
    stdin = false,
    -- 0 = clean, 2 = violations found; both carry valid JSON on stdout.
    -- 1 (crash) and 3 (unprocessable file) are real failures and are
    -- deliberately left out so the runner's normal error path handles them.
    exit_codes = { 0, 2 },
    root_markers = { 'composer.json' },
    parser = parser,
}

require('linters').register('phpmd', M)

return M
