-- #################################################################
-- /qompassai/Diver/lua/linters/_salesforce-code-analyzer.lua
-- Qompass AI Diver Native Salesforce Code Analyzer Factory
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
--
-- ELI5: Salesforce Code Analyzer is a bundle of checkers ("engines") for
-- Salesforce code. One engine, "flow", reads Flow metadata XML and flags
-- risky automation patterns: hardcoded IDs, DML or SOQL inside loops,
-- recursion risks, missing fault paths. This module is a factory: give it a
-- name and a rule selector such as 'flow:Recommended' (the flow engine plus
-- its curated Recommended ruleset, which also powers the standalone
-- lightning-flow-scanner project) and it builds a native linter spec that
-- runs `sf code-analyzer run --json --rule-selector <selector>` on the
-- current file and turns the JSON report into editor diagnostics.
--
---@source https://github.com/Flow-Scanner
---@source https://github.com/laywill/megalinter/blob/HEAD/docs/descriptors/salesforce_code_analyzer_flow.md
---@source https://github.com/nayansai/sf-skills
--- (exit-code table in plugins/builder/salesforce-development/skills/dx-code-analyzer-run/SKILL.md)

local diagnostic = vim.diagnostic

local MAX_DIAGNOSTICS = 512
local MAX_MESSAGE_BYTES = 2048
local MAX_OUTPUT_BYTES = 8 * 1024 * 1024
local MAX_ERROR_EXCERPT_BYTES = 300
local FIND_DEPTH_MAX = 6

---@class SalesforceAnalyzerLocation
---@field file? string
---@field startLine? integer
---@field startColumn? integer
---@field endLine? integer
---@field endColumn? integer

---@class SalesforceAnalyzerViolation
---@field engine? string
---@field locations? SalesforceAnalyzerLocation[]
---@field message? string
---@field primaryLocationIndex? integer
---@field rule? string
---@field ruleName? string
---@field severity? integer|string

---@class SalesforceAnalyzerOptions
---@field name string Linter name, used as the diagnostic source.
---@field selector string Rule selector, e.g. 'flow:Recommended'.

local M = {}

---@param value any
---@param fallback integer
---@return integer
local function integer(value, fallback)
    local parsed = tonumber(value)
    if parsed == nil then
        return fallback
    end
    return math.floor(parsed)
end

---@param value any
---@return integer
local function severity(value)
    local number = integer(value, 3)
    if number <= 2 then
        return diagnostic.severity.ERROR
    end
    if number == 3 then
        return diagnostic.severity.WARN
    end
    if number == 4 then
        return diagnostic.severity.INFO
    end
    return diagnostic.severity.HINT
end

---@param value any
---@return boolean
local function looks_like_violation(value)
    if type(value) ~= 'table' then
        return false
    end
    if type(value.severity) ~= 'number' and type(value.severity) ~= 'string' then
        return false
    end
    return value.message ~= nil or value.rule ~= nil or value.ruleName ~= nil
end

---@param value any
---@param depth? integer
---@return SalesforceAnalyzerViolation[]?
local function find_violations(value, depth)
    if type(value) ~= 'table' or (depth or 0) > FIND_DEPTH_MAX then
        return nil
    end
    if type(value.violations) == 'table' then
        return value.violations
    end
    for _, key in ipairs({
        'result',
        'data',
        'output',
    }) do
        local found = find_violations(value[key], (depth or 0) + 1)
        if found ~= nil then
            return found
        end
    end
    -- Reports may wrap engine results in arrays, or print a bare array of
    -- violation objects; scan elements and accept violation-shaped entries.
    ---@type SalesforceAnalyzerViolation[]
    local collected = {}
    for _, element in ipairs(value) do
        if looks_like_violation(element) then
            collected[#collected + 1] = element
        else
            local found = find_violations(element, (depth or 0) + 1)
            if found ~= nil then
                return found
            end
        end
    end
    if #collected > 0 then
        return collected
    end
    return nil
end

---@param path string
---@return boolean
local function is_absolute(path)
    assert(type(path) == 'string', 'is_absolute requires a string path')
    assert(path ~= '', 'is_absolute requires a non-empty path')

    return vim.fn.isabsolutepath(path) == 1
end

---@param context LintContext
---@return boolean
local function buffer_basename_is_ambiguous(context)
    assert(type(context) == 'table', 'buffer_basename_is_ambiguous requires a LintContext')

    local target = vim.fs.basename(vim.fs.normalize(context.filename) or context.filename)
    local matches = 0
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(bufnr) then
            local name = vim.api.nvim_buf_get_name(bufnr)
            if name ~= '' and vim.fs.basename(name) == target then
                matches = matches + 1
                if matches > 1 then
                    return true
                end
            end
        end
    end
    return false
end

---@param filename? string
---@param context LintContext
---@param basename_ambiguous boolean precomputed by buffer_basename_is_ambiguous
---@return boolean
local function belongs_to_buffer(filename, context, basename_ambiguous)
    if filename == nil or filename == '' then
        return true
    end
    filename = filename:gsub('^file://', '')
    if filename == '' then
        -- Stripping the scheme left nothing (e.g. "file://"): no usable
        -- location info, so attribute to the buffer like a missing file.
        return true
    end
    ---@type string
    local buffer_filename = vim.fs.normalize(context.filename) or context.filename
    ---@type string
    local candidate
    if is_absolute(filename) then
        candidate = vim.fs.normalize(filename) or filename
    else
        local joined = vim.fs.joinpath(context.root, filename)
        candidate = vim.fs.normalize(joined) or joined
    end
    local normalized = vim.fs.normalize(candidate) or candidate
    if normalized == buffer_filename then
        return true
    end
    if vim.fs.basename(normalized) ~= vim.fs.basename(buffer_filename) then
        return false
    end
    -- Basename-only match: attribute it only when no other open buffer
    -- shares the basename. When ambiguous, drop the diagnostic instead of
    -- risking attribution to the wrong buffer.
    return not basename_ambiguous
end

---@param record SalesforceAnalyzerViolation
---@param context LintContext
---@param source string
---@param basename_ambiguous boolean precomputed by buffer_basename_is_ambiguous
---@return vim.Diagnostic?
local function diagnostic_from(record, context, source, basename_ambiguous)
    local locations = type(record.locations) == 'table' and record.locations or {}
    local index = math.max(integer(record.primaryLocationIndex, 0), 0) + 1
    ---@type SalesforceAnalyzerLocation
    local location = type(locations[index]) == 'table' and locations[index] or {}
    if not belongs_to_buffer(location.file, context, basename_ambiguous) then
        return nil
    end

    local start_line = math.max(integer(location.startLine, 1) - 1, 0)
    local start_column = math.max(integer(location.startColumn, 1) - 1, 0)
    local end_line = math.max(integer(location.endLine, start_line + 1) - 1, start_line)
    local minimum_end_column = end_line == start_line and start_column + 1 or 0
    local end_column = math.max(integer(location.endColumn, minimum_end_column + 1) - 1, minimum_end_column)
    local engine = tostring(record.engine or '')
    local rule = tostring(record.rule or record.ruleName or '')
    local code = engine ~= '' and rule ~= '' and (engine .. ':' .. rule) or rule
    local message = tostring(record.message or 'Unknown Salesforce Code Analyzer violation')
    if code ~= '' then
        message = ('[%s] %s'):format(code, message)
    end
    if #message > MAX_MESSAGE_BYTES then
        message = message:sub(1, MAX_MESSAGE_BYTES - 3) .. '...'
    end

    return {
        bufnr = context.bufnr,
        lnum = start_line,
        end_lnum = end_line,
        col = start_column,
        end_col = end_column,
        message = message,
        severity = severity(record.severity),
        source = source,
        code = code ~= '' and code or nil,
    }
end

---@param context LintContext
---@return vim.Diagnostic[]
local function oversized_output(context)
    return {
        {
            bufnr = context.bufnr,
            col = 0,
            end_col = 0,
            end_lnum = 0,
            lnum = 0,
            message = ('Salesforce Code Analyzer output exceeded the %d-byte parser limit'):format(MAX_OUTPUT_BYTES),
            severity = diagnostic.severity.WARN,
            source = 'salesforce-code-analyzer',
        },
    }
end

---@param options SalesforceAnalyzerOptions
---@return Linter
function M.new(options)
    assert(type(options) == 'table', 'salesforce factory requires an options table')
    assert(type(options.name) == 'string', 'salesforce factory requires options.name')
    assert(options.name ~= '', 'salesforce factory requires a non-empty options.name')
    assert(type(options.selector) == 'string', 'salesforce factory requires options.selector')
    assert(options.selector ~= '', 'salesforce factory requires a non-empty options.selector')

    -- Rule selectors combine engine, ruleset, severity, rule name or tag
    -- with colons; 'flow:Recommended' is the flow engine's curated ruleset.
    ---@type Linter
    local spec = {
        cmd = 'sf',
        args = function(context)
            return {
                'code-analyzer',
                'run',
                '--json',
                '--rule-selector',
                options.selector,
                '--workspace',
                context.root,
                '--target',
                context.filename,
            }
        end,
        append_fname = false,
        -- Code Analyzer boots every engine at startup and the flow engine
        -- needs Python 3, so runs are manual-only, never on buffer events.
        automatic = false,
        cwd = function(context)
            return context.root
        end,
        -- 0: no violations above the severity threshold.
        -- 2: violations at or above the threshold; the normal "found
        --    issues" signal, still carrying the JSON report on stdout.
        -- Anything else is an analyzer error.
        exit_codes = {
            [0] = true,
            [2] = true,
        },
        parser = function(output, context)
            if vim.trim(output) == '' then
                return {}
            end
            if #output > MAX_OUTPUT_BYTES then
                if type(context) ~= 'table' then
                    error(options.name .. ' parser requires a LintContext', 0)
                end
                ---@cast context LintContext
                return oversized_output(context)
            end
            if type(context) ~= 'table' then
                error(options.name .. ' parser requires a LintContext', 0)
            end
            local ok, decoded = pcall(vim.json.decode, output)
            if not ok or type(decoded) ~= 'table' then
                -- Truncate: the full output (up to MAX_OUTPUT_BYTES) must not
                -- end up inside a notification string.
                local excerpt = vim.trim(output):sub(1, MAX_ERROR_EXCERPT_BYTES)
                error(('invalid Salesforce Code Analyzer JSON: %s'):format(excerpt), 0)
            end
            ---@cast context LintContext
            -- One scan per run: two open buffers sharing a basename make
            -- basename-only attribution ambiguous, so drop those instead
            -- of risking the wrong buffer.
            local basename_ambiguous = buffer_basename_is_ambiguous(context)
            local records = find_violations(decoded) or {}
            ---@type vim.Diagnostic[]
            local diagnostics = {}
            for _, record in ipairs(records) do
                if #diagnostics >= MAX_DIAGNOSTICS then
                    break
                end
                if type(record) == 'table' then
                    local item = diagnostic_from(record, context, options.name, basename_ambiguous)
                    if item ~= nil then
                        diagnostics[#diagnostics + 1] = item
                    end
                end
            end
            return diagnostics
        end,
        root_markers = {
            'code-analyzer.yml',
            'code-analyzer.yaml',
            'sfdx-project.json',
            '.git',
        },
        stdin = false,
        stream = 'stdout',
        timeout = 120000,
    }

    return spec
end

return M
