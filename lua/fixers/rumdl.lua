-- #################################################################
-- /qompassai/lua/fixers/rumdl.lua
-- Qompass AI Rumdl Fixer
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
-- /qompassai/Diver/lua/fixers/rumdl.lua
-- Qompass AI Diver Native rumdl Markdown Fixer
-- SPDX-License-Identifier: Apache-2.0
--
-- Native Neovim 0.13 fixer configuration.
--
-- This module deliberately uses:
--
--     rumdl fmt --silent --stdin
--
-- instead of:
--
--     rumdl check --fix
--
-- The linter is therefore responsible only for diagnostics, while this
-- module is responsible only for returning corrected Markdown.
--
-- No Neovim formatting or linting plugin is required.
-- #################################################################

local fs = vim.fs

---@class RumdlFixerContext
---@field bufnr integer Buffer being formatted.
---@field cwd? string Working directory supplied by the fixer runner.
---@field filename string Absolute or relative source filename.
---@field root? string Detected project root.

---@class RumdlFixer
---@field append_fname boolean Whether the fixer runner appends the filename.
---@field args string[]|fun(context: RumdlFixerContext): string[] Command arguments.
---@field cmd string Executable name.
---@field cwd? string|fun(context: RumdlFixerContext): string Working directory.
---@field exit_codes table<integer, boolean> Successful command exit codes.
---@field stdin boolean Whether the current buffer is written to stdin.
---@field stream 'stdout'|'stderr'|'both' Stream containing replacement text.
---@field timeout integer Command timeout in milliseconds.

---@type string[]
local config_names = {
        '.rumdl.toml',
        'pyproject.toml',
        'rumdl.toml',
}

---@type string[]
local root_markers = {
        '.git',
        '.rumdl.toml',
        'pyproject.toml',
        'rumdl.toml',
}

---Determine whether a path exists.
---
---This is used only for local configuration discovery. It does not mutate the
---filesystem and does not follow any fixer-specific state.
---
---@param path string
---@return boolean
local function exists(path)
        return vim.uv.fs_stat(path) ~= nil
end

---Return the nearest directory that contains a rumdl configuration.
---
---rumdl already performs its own configuration discovery. This helper is used
---only to choose an appropriate cwd so that the formatter and linter resolve
---the same repository-local configuration when possible.
---
---@param filename string
---@return string?
local function config_root(filename)
        local start = fs.dirname(filename)

        if start == nil then
                return nil
        end

        for _, name in ipairs(config_names) do
                local matches = fs.find(name, {
                        path = start,
                        upward = true,
                })

                if matches[1] ~= nil then
                        return fs.dirname(matches[1])
                end
        end

        return nil
end

---Return the nearest general project root.
---
---This is a fallback for repositories without an explicit rumdl configuration.
---It keeps execution scoped to the current project instead of Neovim's global
---working directory.
---
---@param filename string
---@return string?
local function project_root(filename)
        local start = fs.dirname(filename)

        if start == nil then
                return nil
        end

        local matches = fs.find(root_markers, {
                path = start,
                upward = true,
        })

        if matches[1] == nil then
                return nil
        end

        return fs.dirname(matches[1])
end

---Resolve the working directory used by rumdl.
---
---Precedence:
---
---1. Directory containing the nearest rumdl configuration.
---2. Root supplied by the native fixer runner.
---3. Nearest detected project root.
---4. Directory containing the current Markdown file.
---5. Runner-provided cwd.
---6. Neovim's current working directory.
---
---Using the configuration directory first allows rumdl's native configuration
---discovery to behave identically whether invoked as a linter or as a fixer.
---
---@param context RumdlFixerContext
---@return string
local function cwd(context)
        local detected_config_root = config_root(context.filename)

        if detected_config_root ~= nil then
                return detected_config_root
        end

        if
                type(context.root) == 'string'
                and context.root ~= ''
                and exists(context.root)
        then
                return context.root
        end

        local detected_project_root = project_root(context.filename)

        if detected_project_root ~= nil then
                return detected_project_root
        end

        local directory = fs.dirname(context.filename)

        if directory ~= nil then
                return directory
        end

        if type(context.cwd) == 'string' and context.cwd ~= '' then
                return context.cwd
        end

        return vim.fn.getcwd()
end

---Build the rumdl formatter arguments.
---
---`fmt`
---    Selects rumdl's dedicated formatter mode.
---
---`--silent`
---    Suppresses diagnostic and summary output so stdout contains only the
---    formatted Markdown returned to the fixer engine.
---
---`--stdin`
---    Reads the current Neovim buffer from stdin rather than modifying the file
---    on disk directly.
---
---The filename is intentionally not appended. The formatter consumes the
---buffer through stdin, preventing it from racing with Neovim writes or with
---the independent rumdl linter.
---
---@param _context RumdlFixerContext
---@return string[]
local function args(_context)
        return {
                'fmt',
                '--silent',
                '--stdin',
        }
end

return ---@type RumdlFixer
{
        -- The filename must not be appended because the current buffer is sent
        -- to rumdl through stdin.
        append_fname = false,

        -- Arguments are generated separately to keep this module compatible
        -- with context-aware native fixer runners.
        args = args,

        -- Use the installed rumdl executable directly.
        cmd = 'rumdl',

        -- Run from the configuration/project root so rumdl can discover
        -- .rumdl.toml, rumdl.toml, or pyproject.toml naturally.
        cwd = cwd,

        -- `rumdl fmt` uses formatter-style success semantics. Tool failures
        -- should remain failures instead of being silently accepted.
        exit_codes = {
                [0] = true,
        },

        -- Current buffer contents are supplied directly to rumdl.
        stdin = true,

        -- `--silent` guarantees that stdout is replacement Markdown rather
        -- than diagnostic prose.
        stream = 'stdout',

        -- Markdown formatting should normally be very fast, but a moderately
        -- generous timeout avoids terminating rumdl on large documentation
        -- trees or slower filesystems.
        timeout = 15000,
}