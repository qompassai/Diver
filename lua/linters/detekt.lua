-- #################################################################
-- /qompassai/lua/linters/detekt.lua
-- Qompass AI Detekt
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
-- /qompassai/Diver/lua/linters/detekt.lua
-- Qompass AI Diver Native Detekt Kotlin Linter
-- SPDX-License-Identifier: Apache-2.0

local diagnostic = vim.diagnostic
local fs = vim.fs
local uv = vim.uv

local severities = {
        error = diagnostic.severity.ERROR,
        info = diagnostic.severity.INFO,
        information = diagnostic.severity.INFO,
        warning = diagnostic.severity.WARN,
}

local config_names = {
        '.detekt.yaml',
        '.detekt.yml',
        'config/detekt.yaml',
        'config/detekt.yml',
        'config/detekt/detekt.yaml',
        'config/detekt/detekt.yml',
        'detekt.yaml',
        'detekt.yml',
}

local root_markers = {
        '.git',
        'build.gradle',
        'build.gradle.kts',
        'detekt.yaml',
        'detekt.yml',
        'gradlew',
        'gradlew.bat',
        'pom.xml',
        'settings.gradle',
        'settings.gradle.kts',
}

---@param path string
---@return boolean
local function exists(path)
        return uv.fs_stat(path) ~= nil
end

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

---@param value string
---@return string
local function xml_decode(value)
        return value
                :gsub('&quot;', '"')
                :gsub('&apos;', "'")
                :gsub('&lt;', '<')
                :gsub('&gt;', '>')
                :gsub('&amp;', '&')
end

---@param attributes string
---@param name string
---@return string?
local function attribute(attributes, name)
        local value = attributes:match(name .. '="([^"]*)"')

        if value == nil then
                return nil
        end

        return xml_decode(value)
end

---@param source string?
---@return string?
local function rule_from_source(source)
        if source == nil or source == '' then
                return nil
        end

        return source:match('%.([^%.]+)$') or source
end

---@param root string
---@return string?
local function project_config(root)
        for _, name in ipairs(config_names) do
                local path = fs.joinpath(root, name)

                if exists(path) then
                        return path
                end
        end

        return nil
end

---@return string
local function fallback_config_path()
        return fs.joinpath(
                vim.fn.stdpath('cache'),
                'qompassai',
                'detekt',
                'detekt.yml'
        )
end

---@param path string
---@return boolean
local function generate_fallback_config(path)
        if exists(path) then
                return true
        end

        local parent = fs.dirname(path)

        if parent == nil then
                return false
        end

        local ok, mkdir_error = pcall(vim.fn.mkdir, parent, 'p')

        if not ok then
                vim.notify(
                        ('detekt: unable to create configuration directory: %s'):format(
                                tostring(mkdir_error)
                        ),
                        vim.log.levels.ERROR
                )

                return false
        end

        local result = vim.system({
                'detekt',
                '--generate-config',
                path,
        }, {
                text = true,
        }):wait()

        if result.code ~= 0 then
                local message = result.stderr

                if message == nil or message == '' then
                        message = result.stdout
                end

                if message == nil or message == '' then
                        message = ('detekt exited with status %d'):format(result.code)
                end

                vim.notify(
                        ('detekt: unable to generate fallback configuration:\n%s'):format(
                                vim.trim(message)
                        ),
                        vim.log.levels.ERROR
                )

                return false
        end

        return exists(path)
end

---@param root string
---@return string?
local function resolve_config(root)
        local detected = project_config(root)

        if detected ~= nil then
                return detected
        end

        local fallback = fallback_config_path()

        if generate_fallback_config(fallback) then
                return fallback
        end

        return nil
end

---@param output string
---@param _context LintContext|integer
---@return vim.Diagnostic.Set[]
local function parse(output, _context)
        local diagnostics = {}

        for attributes in output:gmatch('<error%s+([^>]-)/>') do
                local column = attribute(attributes, 'column')
                local line = attribute(attributes, 'line')
                local message = attribute(attributes, 'message')
                local severity = attribute(attributes, 'severity')
                local source = attribute(attributes, 'source')

                if line ~= nil and message ~= nil then
                        local line_number = math.max(integer(line, 1) - 1, 0)
                        local start_column = math.max(integer(column, 1) - 1, 0)
                        local level = (severity or 'warning'):lower()
                        local rule = rule_from_source(source)

                        diagnostics[#diagnostics + 1] = {
                                code = rule,
                                col = start_column,
                                end_col = start_column + 1,
                                end_lnum = line_number,
                                lnum = line_number,
                                message = rule ~= nil
                                                and ('[%s] %s'):format(rule, message)
                                        or message,
                                severity = severities[level]
                                        or diagnostic.severity.WARN,
                                source = 'detekt',
                        }
                end
        end

        return diagnostics
end

---@param context LintContext
---@return string[]
local function args(context)
        local arguments = {
                '--analysis-mode',
                'light',
                '--base-path',
                context.root,
                '--fail-on-severity',
                'Never',
                '--input',
                context.filename,
                '--report',
                'checkstyle:-',
        }

        local config = resolve_config(context.root)

        if config ~= nil then
                arguments[#arguments + 1] = '--config'
                arguments[#arguments + 1] = config

                if project_config(context.root) ~= nil then
                        arguments[#arguments + 1] = '--build-upon-default-config'
                end
        else
                arguments[#arguments + 1] = '--build-upon-default-config'
        end

        return arguments
end

---@param context LintContext
---@return string
local function cwd(context)
        return context.root
end

return ---@type Linter
{
        append_fname = false,
        args = args,
        cmd = 'detekt',
        cwd = cwd,
        exit_codes = {
                [0] = true,
                [2] = true,
        },
        parser = parse,
        root_markers = root_markers,
        stdin = false,
        stream = 'stdout',
        timeout = 60000,
}