-- #################################################################
-- /qompassai/lua/linters/betterleaks.lua
-- Qompass AI Betterleaks
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

local diagnostic = vim.diagnostic
local fs = vim.fs

local ERROR = diagnostic.severity.ERROR
local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 4096
local OUTPUT_LENGTH_MAX = 16 * 1024 * 1024
local RUNS_MAX = 64
local RESULTS_MAX = 4096

---@class BetterleaksSarifMessage
---@field text? string

---@class BetterleaksSarifArtifactLocation
---@field uri? string

---@class BetterleaksSarifRegion
---@field startLine? integer
---@field startColumn? integer
---@field endLine? integer
---@field endColumn? integer

---@class BetterleaksSarifPhysicalLocation
---@field artifactLocation? BetterleaksSarifArtifactLocation
---@field region? BetterleaksSarifRegion

---@class BetterleaksSarifLocation
---@field physicalLocation? BetterleaksSarifPhysicalLocation

---@class BetterleaksSarifResult
---@field level? string
---@field locations? BetterleaksSarifLocation[]
---@field message? BetterleaksSarifMessage
---@field ruleId? string

---@class BetterleaksSarifRun
---@field results? BetterleaksSarifResult[]

---@class BetterleaksSarif
---@field runs? BetterleaksSarifRun[]

---@param value integer|number|string|nil
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

---@param value string|nil
---@return integer
local function severity(value)
        if value == 'error' then
                return ERROR
        end

        return WARN
end

---@param path string
---@param filename string
---@param root string
---@return boolean
local function belongs_to_buffer(path, filename, root)
        assert(path ~= '')
        assert(filename ~= '')
        assert(root ~= '')

        local candidate

        if fs.is_absolute(path) then
                candidate = fs.normalize(path)
        else
                candidate = fs.normalize(fs.joinpath(root, path))
        end

        return candidate == filename
end

---@param result BetterleaksSarifResult
---@param filename string
---@param root string
---@return vim.Diagnostic?
local function diagnostic_from_result(result, filename, root)
        local locations = result.locations
        if type(locations) ~= 'table' or #locations == 0 then
                return nil
        end

        local physical = locations[1].physicalLocation
        if type(physical) ~= 'table' then
                return nil
        end

        local artifact = physical.artifactLocation
        local region = physical.region

        if type(artifact) ~= 'table' or type(region) ~= 'table' then
                return nil
        end

        local path = artifact.uri
        if type(path) ~= 'string' or path == '' then
                return nil
        end

        if not belongs_to_buffer(path, filename, root) then
                return nil
        end

        local message_table = result.message
        local message = type(message_table) == 'table'
                        and message_table.text
                or nil

        if type(message) ~= 'string' or message == '' then
                message = 'Potential secret detected'
        end

        local start_line = math.max(integer(region.startLine, 1) - 1, 0)
        local start_column = math.max(integer(region.startColumn, 1) - 1, 0)

        local end_line = math.max(
                integer(region.endLine, start_line + 1) - 1,
                start_line
        )

        local end_column = math.max(
                integer(region.endColumn, start_column + 2) - 1,
                end_line == start_line and start_column + 1 or 0
        )

        return {
                lnum = start_line,
                end_lnum = end_line,
                col = start_column,
                end_col = end_column,
                message = message,
                severity = severity(result.level),
                source = 'betterleaks',
                code = result.ruleId,
        }
end

---@param output string
---@param context LintContext|integer
---@return vim.Diagnostic.Set[]
local function parse(output, context)
        if output == '' then
                return {}
        end

        assert(
                type(context) == 'table',
                'betterleaks parser requires a LintContext'
        )

        ---@cast context LintContext

        assert(context.filename ~= '')
        assert(context.root ~= '')
        assert(#output <= OUTPUT_LENGTH_MAX, 'betterleaks output exceeded limit')

        local ok, decoded = pcall(vim.json.decode, output)

        if not ok or type(decoded) ~= 'table' then
                return {}
        end

        ---@cast decoded BetterleaksSarif

        local runs = decoded.runs
        if type(runs) ~= 'table' then
                return {}
        end

        local filename = fs.normalize(context.filename)
        local root = context.root

        ---@type vim.Diagnostic.Set[]
        local diagnostics = {}
        local diagnostics_count = 0
        local runs_count = math.min(#runs, RUNS_MAX)

        for run_index = 1, runs_count do
                local results = runs[run_index].results

                if type(results) == 'table' then
                        local results_count = math.min(#results, RESULTS_MAX)

                        for result_index = 1, results_count do
                                if diagnostics_count >= DIAGNOSTICS_MAX then
                                        break
                                end

                                local entry = diagnostic_from_result(
                                        results[result_index],
                                        filename,
                                        root
                                )

                                if entry ~= nil then
                                        diagnostics_count = diagnostics_count + 1
                                        diagnostics[diagnostics_count] = entry
                                end
                        end
                end

                if diagnostics_count >= DIAGNOSTICS_MAX then
                        break
                end
        end

        assert(diagnostics_count <= DIAGNOSTICS_MAX)
        assert(diagnostics_count == #diagnostics)

        return diagnostics
end

return ---@type Linter
{
        automatic = false,

        cmd = 'betterleaks',

        args = function(context)
                assert(context.filename ~= '')

                return {
                        'dir',
                        context.filename,
                        '--no-banner',
                        '--no-color',
                        '--report-format=sarif',
                        '--report-path=-',
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
                '.betterleaks.toml',
                'betterleaks.toml',
                '.betterleaksignore',
                '.git',
        },

        stdin = false,
        stream = 'stdout',
        timeout = 30000,
}