-- #################################################################
-- /qompassai/diver/lua/linters/hadolint.lua
-- Qompass AI Hadolint
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
---@source https://github.com/hadolint/hadolint

local diagnostic = vim.diagnostic
local fs = vim.fs

local ERROR = diagnostic.severity.ERROR
local HINT = diagnostic.severity.HINT
local INFO = diagnostic.severity.INFO
local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 4096
local OUTPUT_LENGTH_MAX = 16 * 1024 * 1024

---@class HadolintViolation
---@field code? string
---@field column? integer
---@field file? string
---@field level? string
---@field line? integer
---@field message? string

---@type table<string, integer>
local severities = {
        error = ERROR,
        warning = WARN,
        info = INFO,
        style = HINT,
        ignore = HINT,
}

---@type string[]
local error_rules = {
        'DL3000',
        'DL3002',
        'DL3004',
        'DL3006',
        'DL3007',
        'DL3008',
        'DL3011',
        'DL3012',
        'DL3013',
        'DL3016',
        'DL3018',
        'DL3020',
        'DL3021',
        'DL3022',
        'DL3023',
        'DL3024',
        'DL3025',
        'DL3026',
        'DL3027',
        'DL3028',
        'DL3029',
        'DL3033',
        'DL3037',
        'DL3041',
        'DL3043',
        'DL3044',
        'DL3045',
        'DL3048',
        'DL3049',
        'DL3051',
        'DL3052',
        'DL3053',
        'DL3054',
        'DL3055',
        'DL3056',
        'DL3057',
        'DL3058',
        'DL3061',
        'DL3062',
        'DL3063',
        'DL3064',
        'DL3067',
        'DL4000',
        'DL4004',
        'DL4006',
}

---@type string[]
local warning_rules = {
        'DL3001',
        'DL3003',
        'DL3009',
        'DL3014',
        'DL3015',
        'DL3019',
        'DL3030',
        'DL3032',
        'DL3034',
        'DL3035',
        'DL3036',
        'DL3038',
        'DL3040',
        'DL3042',
        'DL3046',
        'DL3047',
        'DL3059',
        'DL3060',
        'DL3066',
        'DL4001',
        'DL4003',
        'DL4005',
}

---@type string[]
local required_labels = {
        'org.opencontainers.image.authors:text',
        'org.opencontainers.image.created:text',
        'org.opencontainers.image.description:text',
        'org.opencontainers.image.documentation:text',
        'org.opencontainers.image.licenses:text',
        'org.opencontainers.image.revision:text',
        'org.opencontainers.image.source:text',
        'org.opencontainers.image.title:text',
        'org.opencontainers.image.url:text',
        'org.opencontainers.image.vendor:text',
        'org.opencontainers.image.version:text',
}

---@type string[]
local trusted_registries = {
        'cgr.dev',
        'docker.io',
        'ghcr.io',
        'mcr.microsoft.com',
        'public.ecr.aws',
        'quay.io',
        'registry.access.redhat.com',
        'registry.gitlab.com',
}

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

---@param level string|nil
---@return integer
local function severity(level)
        if level == nil then
                return WARN
        end

        return severities[level:lower()] or WARN
end

---@param path string
---@param filename string
---@param root string
---@return boolean
local function belongs_to_buffer(path, filename, root)
        assert(path ~= '')
        assert(filename ~= '')
        assert(root ~= '')

        if path == '-' then
                return true
        end

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

---@param violation HadolintViolation
---@param filename string
---@param root string
---@return vim.Diagnostic?
local function diagnostic_from_violation(
        violation,
        filename,
        root
)
        local path = violation.file

        if type(path) ~= 'string' or path == '' then
                return nil
        end

        if not belongs_to_buffer(path, filename, root) then
                return nil
        end

        local start_line =
                math.max(
                        integer(violation.line, 1) - 1,
                        0
                )

        local start_column =
                math.max(
                        integer(violation.column, 1) - 1,
                        0
                )

        local message = violation.message

        if type(message) ~= 'string' or message == '' then
                message = 'Hadolint Dockerfile violation'
        end

        local code = violation.code

        if type(code) ~= 'string' or code == '' then
                code = nil
        end

        return {
                lnum = start_line,
                end_lnum = start_line,
                col = start_column,
                end_col = start_column + 1,
                message = message,
                severity = severity(violation.level),
                source = 'hadolint',
                code = code,
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
                'hadolint parser requires a LintContext'
        )

        ---@cast context LintContext

        assert(context.filename ~= '')
        assert(context.root ~= '')
        assert(
                #output <= OUTPUT_LENGTH_MAX,
                'hadolint output exceeded maximum size'
        )

        local ok, decoded = pcall(vim.json.decode, output)

        if not ok or type(decoded) ~= 'table' then
                return {}
        end

        ---@cast decoded HadolintViolation[]

        local filename = fs.normalize(context.filename)
        local root = fs.normalize(context.root)

        ---@type vim.Diagnostic.Set[]
        local diagnostics = {}
        local diagnostics_count = 0

        local violations_count =
                math.min(#decoded, DIAGNOSTICS_MAX)

        for index = 1, violations_count do
                local violation = decoded[index]

                if type(violation) == 'table' then
                        local entry =
                                diagnostic_from_violation(
                                        violation,
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

        assert(diagnostics_count <= DIAGNOSTICS_MAX)
        assert(diagnostics_count == #diagnostics)

        return diagnostics
end

---@param args string[]
---@param flag string
---@param values string[]
local function append_repeated(args, flag, values)
        assert(flag ~= '')

        for index = 1, #values do
                local value = values[index]

                assert(value ~= '')

                args[#args + 1] = flag
                args[#args + 1] = value
        end
end

---@param context LintContext
---@return string[]
local function args(context)
        assert(context.filename ~= '')

        local argv = {
                '--disable-ignore-pragma',
                '--failure-threshold',
                'style',
                '--format',
                'json',
                '--no-color',
                '--strict-labels',
        }

        append_repeated(
                argv,
                '--error',
                error_rules
        )

        append_repeated(
                argv,
                '--warning',
                warning_rules
        )

        append_repeated(
                argv,
                '--require-label',
                required_labels
        )

        append_repeated(
                argv,
                '--trusted-registry',
                trusted_registries
        )

        argv[#argv + 1] = context.filename

        return argv
end

return ---@type Linter
{
        automatic = false,

        cmd = 'hadolint',

        args = args,

        append_fname = false,

        cwd = function(context)
                assert(context.root ~= '')

                return context.root
        end,

        ignore_exitcode = true,

        parser = parse,

        root_markers = {
                '.hadolint.yaml',
                '.hadolint.yml',
                'compose.yaml',
                'compose.yml',
                'docker-compose.yaml',
                'docker-compose.yml',
                'Dockerfile',
                '.git',
        },

        stdin = false,
        stream = 'stdout',
        timeout = 30000,
}