-- #################################################################
-- /qompassai/lua/linters/detect_secrets.lua
-- Qompass AI Detect Secrets
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

---@source https://github.com/Yelp/detect-secrets

local diagnostic = vim.diagnostic
local fs = vim.fs
local uv = vim.uv

local ERROR = diagnostic.severity.ERROR

local DIAGNOSTICS_MAX = 4096
local OUTPUT_LENGTH_MAX = 16 * 1024 * 1024
local RESULTS_PER_FILE_MAX = 4096

---@class DetectSecretsFinding
---@field filename? string
---@field line_number? integer
---@field type? string
---@field hashed_secret? string
---@field is_verified? boolean

---@type table<string, string|false>
local baseline_cache = {}

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
---@return boolean
local function is_file(path)
        assert(path ~= '')

        local stat = uv.fs_stat(path)

        return stat ~= nil and stat.type == 'file'
end

---@param root string
---@return string?
local function baseline(root)
        assert(root ~= '')

        local cached = baseline_cache[root]

        if cached ~= nil then
                return cached ~= false and cached or nil
        end

        local path = fs.joinpath(
                root,
                '.secrets.baseline'
        )

        if is_file(path) then
                baseline_cache[root] = path
                return path
        end

        baseline_cache[root] = false

        return nil
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
                candidate = fs.normalize(
                        fs.joinpath(root, path)
                )
        end

        return candidate == filename
end

---@param finding DetectSecretsFinding
---@param filename string
---@param root string
---@return vim.Diagnostic?
local function diagnostic_from_finding(
        finding,
        filename,
        root
)
        local path = finding.filename

        if type(path) ~= 'string' or path == '' then
                return nil
        end

        if not belongs_to_buffer(path, filename, root) then
                return nil
        end

        local secret_type = finding.type

        if type(secret_type) ~= 'string' or secret_type == '' then
                secret_type = 'Potential secret'
        end

        local row = math.max(
                integer(finding.line_number, 1) - 1,
                0
        )

        return {
                lnum = row,
                end_lnum = row,
                col = 0,
                end_col = 1,
                message = secret_type,
                severity = ERROR,
                source = 'detect-secrets',
                code = secret_type,
                user_data = {
                        is_verified = finding.is_verified,
                },
        }
end

---@param value table
---@param filename string
---@param root string
---@param diagnostics vim.Diagnostic.Set[]
---@param diagnostics_count integer
---@return integer
local function append_findings(
        value,
        filename,
        root,
        diagnostics,
        diagnostics_count
)
        assert(filename ~= '')
        assert(root ~= '')
        assert(diagnostics_count >= 0)
        assert(diagnostics_count <= DIAGNOSTICS_MAX)

        local count = math.min(
                #value,
                RESULTS_PER_FILE_MAX
        )

        for index = 1, count do
                if diagnostics_count >= DIAGNOSTICS_MAX then
                        break
                end

                local finding = value[index]

                if type(finding) == 'table' then
                        ---@cast finding DetectSecretsFinding

                        local entry = diagnostic_from_finding(
                                finding,
                                filename,
                                root
                        )

                        if entry ~= nil then
                                diagnostics_count =
                                        diagnostics_count + 1

                                diagnostics[diagnostics_count] =
                                        entry
                        end
                end
        end

        return diagnostics_count
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
                'detect-secrets parser requires a LintContext'
        )

        ---@cast context LintContext

        assert(context.filename ~= '')
        assert(context.root ~= '')

        assert(
                #output <= OUTPUT_LENGTH_MAX,
                'detect-secrets output exceeded maximum size'
        )

        local ok, decoded = pcall(
                vim.json.decode,
                output
        )

        if not ok or type(decoded) ~= 'table' then
                return {}
        end

        local filename = fs.normalize(
                context.filename
        )

        local root = context.root

        ---@type vim.Diagnostic.Set[]
        local diagnostics = {}
        local diagnostics_count = 0

        --
        -- detect-secrets-hook --json may expose findings either as a
        -- top-level list or grouped by filename. Support both shapes
        -- defensively without guessing about secret values.
        --
        if #decoded > 0 then
                diagnostics_count = append_findings(
                        decoded,
                        filename,
                        root,
                        diagnostics,
                        diagnostics_count
                )
        else
                for _, findings in pairs(decoded) do
                        if diagnostics_count >= DIAGNOSTICS_MAX then
                                break
                        end

                        if type(findings) == 'table' then
                                diagnostics_count = append_findings(
                                        findings,
                                        filename,
                                        root,
                                        diagnostics,
                                        diagnostics_count
                                )
                        end
                end
        end

        assert(
                diagnostics_count <= DIAGNOSTICS_MAX
        )

        assert(
                diagnostics_count == #diagnostics
        )

        return diagnostics
end

return ---@type Linter
{
        automatic = false,

        cmd = 'detect-secrets-hook',

        args = function(context)
                assert(context.filename ~= '')
                assert(context.root ~= '')

                local args = {
                        '--json',
                        '--no-verify',
                }

                local baseline_path = baseline(
                        context.root
                )

                if baseline_path ~= nil then
                        args[#args + 1] = '--baseline'
                        args[#args + 1] = baseline_path
                end

                args[#args + 1] = context.filename

                return args
        end,

        append_fname = false,

        cwd = function(context)
                assert(context.root ~= '')

                return context.root
        end,

        ignore_exitcode = true,

        parser = parse,

        root_markers = {
                '.secrets.baseline',
                '.git',
        },

        stdin = false,
        stream = 'stdout',
        timeout = 30000,
}