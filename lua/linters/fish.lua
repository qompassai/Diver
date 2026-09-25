-- #################################################################
-- /qompassai/Diver/lua/linters/fish.lua
-- Qompass AI Diver Native fish Syntax Linter
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
---@source https://github.com/fish-shell/fish-shell
---
--- ELI5: This asks the fish shell to read your script without running it
--- and report syntax mistakes. `--no-execute` means "check only, don't run
--- anything" and the `-` reads the buffer from stdin. Errors look like
--- `fish: Unknown command: xyz` on stderr followed by the offending line
--- and a caret marking the bad spot:
---
---     fish: Unknown command: xyz
---     xyz
---     ^~
---

local diagnostic = vim.diagnostic
local fs = vim.fs

local ERROR = diagnostic.severity.ERROR

local DIAGNOSTICS_MAX = 1024
local LINE_LENGTH_MAX = 64 * 1024
local MESSAGE_LENGTH_MAX = 16 * 1024
local OUTPUT_BYTES_MAX = 4 * 1024 * 1024
local TIMEOUT_MS = 15000

local type = type

local SOURCE = 'fish'

-- `fish: Unknown command: xyz`
local MESSAGE_PATTERN = '^fish:%s*(.+)$'

---@param value string
---@return string?
local function clean_message(value)
    assert(type(value) == 'string')

    local message = vim.trim(value:gsub('[%z\1-\8\11-\31\127]', ' '))

    if message == '' then
        return nil
    end

    if #message > MESSAGE_LENGTH_MAX then
        message = message:sub(1, MESSAGE_LENGTH_MAX) .. '…'
    end

    return message
end

---@param output string
---@param _ LintContext|integer
---@return vim.Diagnostic.Set[]
local function parse(output, _)
    ---@type vim.Diagnostic.Set[]
    local diagnostics = {}

    if output == '' then
        return diagnostics
    end

    assert(#output <= OUTPUT_BYTES_MAX, 'fish output exceeded maximum size')

    -- Buffer the lines so a diagnostic can look at its neighbours.
    ---@type string[]
    local lines = {}
    for line in output:gmatch('[^\r\n]+') do
        if #line <= LINE_LENGTH_MAX then
            lines[#lines + 1] = line
        end
        if #lines > DIAGNOSTICS_MAX * 4 then
            break
        end
    end

    local index = 1
    while index <= #lines and #diagnostics < DIAGNOSTICS_MAX do
        local message = lines[index]:match(MESSAGE_PATTERN)

        if message ~= nil then
            local cleaned = clean_message(message)

            if cleaned ~= nil then
                -- fish prints the offending source line and a caret line
                -- after the message; use the caret to narrow the column.
                local column = 0
                local end_column = 1
                local caret = index + 2 <= #lines and lines[index + 2] or nil
                if caret ~= nil then
                    local caret_start = caret:find('%^')
                    if caret_start ~= nil then
                        column = caret_start - 1
                        local tilde_end = caret:find('~+$')
                        end_column = tilde_end ~= nil and (tilde_end + 1) or (caret_start + 1)
                    end
                end

                diagnostics[#diagnostics + 1] = {
                    -- fish does not report a line number with `--no-execute`
                    -- on stdin; do not invent one.
                    lnum = 0,
                    end_lnum = 0,
                    col = column,
                    end_col = end_column,
                    severity = ERROR,
                    source = SOURCE,
                    code = 'syntax',
                    message = cleaned,
                }
            end
        end

        index = index + 1
    end

    assert(#diagnostics <= DIAGNOSTICS_MAX)

    return diagnostics
end

---@param context LintContext
---@return string
local function cwd(context)
    assert(context.root ~= '')

    return fs.normalize(context.root)
end

return ---@type Linter
{
    automatic = true,

    cmd = 'fish',

    args = {
        -- Parse the script but execute nothing.
        '--no-execute',
        -- Read the buffer from stdin.
        '-',
    },

    append_fname = false,

    cwd = cwd,

    -- A syntax error exits nonzero; that is the normal diagnostic path.
    ignore_exitcode = true,

    parser = parse,

    root_markers = {
        '.git',
    },

    stdin = true,

    -- fish writes syntax errors to stderr.
    stream = 'stderr',

    timeout = TIMEOUT_MS,
}
