-- #################################################################
-- /qompassai/lua/linters/android_lint.lua
-- Qompass AI Android Lint linter adapter
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
--- Android Lint via the Gradle wrapper, reported through SARIF.
---
--- Runs `./gradlew lintDebug` in the project root and parses every
--- `<module>/build/reports/lint-results-debug.sarif` report the run
--- produced, keeping only diagnostics for the buffer being linted.
---
--- Facts verified 2026-09-27 against AGP docs and a real report:
--- - AGP always writes SARIF when `lint.reportFormats` includes sarif;
---   since AGP 8.x SARIF is a default alongside HTML and text.
--- - Runs write to `<module>/build/reports/lint-results-debug.sarif`.
--- - artifactLocation.uri entries are paths relative to the module
---   directory; result levels are none/note/warning/error.
---
--- ELI5: Android Lint is the spell-checker Android ships for its own
--- code. It runs through your project's Gradle wrapper, so results
--- match exactly what CI would find.
local fs = vim.fs
local json = vim.json

---@type integer Hard cap on decoded report bytes.
local OUTPUT_LENGTH_MAX = 10 * 1024 * 1024
---@type integer Hard cap on diagnostics from one lint run.
local DIAGNOSTICS_MAX = 1000
---@type integer Lint is slow; allow five minutes before giving up.
local TIMEOUT_MS = 300000
---@type integer Max SARIF reports to scan (multi-module builds).
local REPORTS_MAX = 16

---@type table<string, vim.Diagnostic.Severity> Maps SARIF levels to Neovim severities.
local SEVERITY = {
    none = vim.diagnostic.severity.HINT,
    note = vim.diagnostic.severity.INFO,
    warning = vim.diagnostic.severity.WARN,
    error = vim.diagnostic.severity.ERROR,
}

---@class AndroidLintSarifRegion
---@field startLine? integer
---@field startColumn? integer
---@field endLine? integer
---@field endColumn? integer

---@class AndroidLintSarifPhysicalLocation
---@field artifactLocation? { uri?: string }
---@field region? AndroidLintSarifRegion

---@class AndroidLintSarifLocation
---@field physicalLocation? AndroidLintSarifPhysicalLocation

---@class AndroidLintSarifResult
---@field ruleId? string
---@field level? string
---@field message? { text?: string }
---@field locations? AndroidLintSarifLocation[]

---@class AndroidLintSarifRun
---@field results? AndroidLintSarifResult[]

---@class AndroidLintSarifReport
---@field runs? AndroidLintSarifRun[]

---Build a diagnostic from one SARIF result, or nil when unusable.
---@param result AndroidLintSarifResult
---@param module_dir string Module directory the report belongs to.
---@param bufnr integer Buffer being linted.
---@param want_path string Normalized path of the buffer being linted.
---@return vim.Diagnostic.Set?
local function diagnostic_from_result(result, module_dir, bufnr, want_path)
    local locations = result.locations
    if type(locations) ~= 'table' or #locations == 0 then
        return nil
    end

    local location = locations[1].physicalLocation
    if type(location) ~= 'table' then
        return nil
    end

    local artifact = location.artifactLocation or {}
    local uri = type(artifact.uri) == 'string' and artifact.uri or ''
    if uri == '' then
        return nil
    end

    local path = uri
    if not fs.normalize(path):find('^/') and not path:find('^%a:[/\\]') then
        path = fs.joinpath(module_dir, uri)
    end

    if fs.normalize(path) ~= want_path then
        return nil
    end

    local region = location.region or {}
    local lnum = math.max((region.startLine or 1) - 1, 0)
    local end_lnum = math.max((region.endLine or (region.startLine or 1)) - 1, lnum)
    local col = math.max((region.startColumn or 1) - 1, 0)
    local end_col = math.max((region.endColumn or (region.startColumn or 1)) - 1, col)

    local text = (result.message and type(result.message.text) == 'string' and result.message.text) or ''
    local message = (result.ruleId or 'lint') .. ': ' .. text

    return {
        bufnr = bufnr,
        lnum = lnum,
        end_lnum = end_lnum,
        col = col,
        end_col = end_col,
        severity = SEVERITY[result.level or ''] or vim.diagnostic.severity.WARN,
        message = message,
        source = 'android_lint',
    }
end

---Find SARIF reports under the project root, bounded.
---@param root string Project root.
---@return string[] report paths
local function find_reports(root)
    local pattern = fs.joinpath(root, '**', 'build', 'reports', 'lint-results-debug.sarif')
    local ok, paths = pcall(vim.fn.glob, pattern, false, true)
    if not ok or type(paths) ~= 'table' then
        return {}
    end

    local reports = {}
    for i = 1, math.min(#paths, REPORTS_MAX) do
        reports[#reports + 1] = paths[i]
    end

    return reports
end

---The module directory a SARIF report belongs to (strip build/reports).
---@param report string Report path.
---@return string
local function module_dir_of(report)
    local dir = fs.dirname(report) -- build/reports
    dir = fs.dirname(dir) -- build
    return fs.dirname(dir) -- module
end

---Parse every SARIF report for diagnostics on the current buffer.
---
--- The lint run's stdout carries no diagnostics; results come from the
--- SARIF files the Gradle task writes.
---@param _output string Stdout of the lint run (unused; results come from files).
---@param context LintContext|integer
---@return vim.Diagnostic.Set[]
local function parse(_output, context)
    assert(type(context) == 'table', 'android_lint parser requires a LintContext')
    ---@cast context LintContext

    assert(context.bufnr ~= nil)
    assert(context.filename ~= '')
    assert(context.root ~= '')

    local want_path = fs.normalize(context.filename)
    local module_dir_unknown = fs.normalize(context.root)

    ---@type vim.Diagnostic.Set[]
    local diagnostics = {}
    local diagnostics_count = 0

    for _, report in ipairs(find_reports(module_dir_unknown)) do
        local module_dir = module_dir_of(report)
        local file = io.open(report, 'r')

        if file ~= nil then
            local content = file:read('a')
            file:close()

            if type(content) == 'string' and content ~= '' and #content <= OUTPUT_LENGTH_MAX then
                local ok, decoded = pcall(json.decode, content)

                if ok and type(decoded) == 'table' then
                    ---@cast decoded AndroidLintSarifReport

                    local runs = decoded.runs
                    if type(runs) == 'table' then
                        for run_index = 1, #runs do
                            if diagnostics_count >= DIAGNOSTICS_MAX then
                                break
                            end

                            local run = runs[run_index]
                            if type(run) == 'table' and type(run.results) == 'table' then
                                for result_index = 1, #run.results do
                                    if diagnostics_count >= DIAGNOSTICS_MAX then
                                        break
                                    end

                                    local result = run.results[result_index]
                                    local diagnostic =
                                        diagnostic_from_result(result, module_dir, context.bufnr, want_path)
                                    if diagnostic ~= nil then
                                        diagnostics_count = diagnostics_count + 1
                                        diagnostics[#diagnostics + 1] = diagnostic
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return diagnostics
end

---@param context LintContext
---@return string
local function cmd(context)
    assert(context.root ~= '', 'android_lint requires a project root')

    local bat = fs.joinpath(context.root, 'gradlew.bat')
    if vim.fn.executable(bat) == 1 then
        return bat
    end

    return fs.joinpath(context.root, 'gradlew')
end

---@param _context LintContext
---@return string[]
local function args(_context)
    return { 'lintDebug' }
end

---@type LinterDefinition
local linter = {
    ---@diagnostic disable-next-line: unused-local
    schema = 1,
    name = 'android_lint',
    meta = {
        url = 'https://developer.android.com/studio/write/lint',
        description = 'Android Lint via ./gradlew lintDebug; parses SARIF reports.',
    },
    ---@diagnostic disable-next-line: unused-local
    cmd = cmd,
    args = args,
    stdin = false,
    append_fname = false,
    stream = 'stdout',
    ignore_exitcode = true,
    timeout = TIMEOUT_MS,
    automatic = false,
    root_markers = { 'settings.gradle', 'settings.gradle.kts', 'gradlew' },
    ---@diagnostic disable-next-line: unused-local
    parse = parse,
}

return linter
