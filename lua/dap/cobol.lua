-- #################################################################
-- ~/.config/nvim/lua/dap/cobol.lua
-- Qompass AI Diver Native COBOL Debug Adapter Configuration
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0
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
---@source https://gnucobol.sourceforge.io/
---@source https://sourceware.org/gdb/current/onlinedocs/gdb.html/Debugger-Adapter-Protocol.html

--- COBOL debugging via GnuCOBOL and the GDB DAP foundation.
---
--- Plain-language version: GnuCOBOL compiles COBOL into native machine code,
--- so there is no COBOL-specific debug adapter to install. This module
--- compiles your program with debug symbols (`cobc -g`) and hands the
--- result to the shared GDB foundation. Editor extensions like Rech and
--- SuperBOL exist, but they are VS Code extensions, not DAP servers, so
--- they cannot plug in here.
---@module 'dap.cobol'

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local uv = vim.uv
local levels = vim.log.levels

local M = {}

local SOURCE = 'cobol'
local PROBE_TIMEOUT_MS = 30000
local MAX_OUTPUT_BYTES = 65536

---@type string[]
local ROOT_MARKERS = {
    '.git',
}

---@class CobolState
---@field cobc string?
local state = {
    cobc = nil,
}

---@param message string
---@param level? integer
local function notify(message, level)
    vim.notify(('[%s] %s'):format(SOURCE, message), level or levels.INFO)
end

---@param value unknown
---@return boolean
local function nonempty_string(value)
    return type(value) == 'string' and value ~= ''
end

---@param path string
---@return boolean
local function executable(path)
    return nonempty_string(path) and fn.executable(path) == 1
end

---@param path string
---@return string
local function normalize(path)
    if path == '' then
        return ''
    end

    return fs.normalize(fn.fnamemodify(path, ':p'))
end

---@param value string?
---@return string
local function trim(value)
    return type(value) == 'string' and vim.trim(value) or ''
end

---@param bufnr? integer
---@return string
local function buffer_filename(bufnr)
    bufnr = bufnr or api.nvim_get_current_buf()

    if not api.nvim_buf_is_valid(bufnr) then
        return ''
    end

    local name = api.nvim_buf_get_name(bufnr)

    if name == '' then
        return ''
    end

    return normalize(name)
end

---@param bufnr? integer
---@return string
local function project_root(bufnr)
    bufnr = bufnr or api.nvim_get_current_buf()

    local filename = buffer_filename(bufnr)

    if filename ~= '' then
        local detected = fs.root(filename, ROOT_MARKERS)

        if type(detected) == 'string' and detected ~= '' then
            return fs.normalize(detected)
        end

        local parent = fs.dirname(filename)

        if type(parent) == 'string' and parent ~= '' then
            return fs.normalize(parent)
        end
    end

    return fs.normalize(fn.getcwd())
end

---@param command string[]
---@return vim.SystemCompleted?
local function system(command)
    local ok, result = pcall(function()
        return vim.system(command, {
            text = true,
        }):wait(PROBE_TIMEOUT_MS)
    end)

    if not ok then
        return nil
    end

    return result
end

---@return string?
local function find_cobc()
    if state.cobc ~= nil then
        return state.cobc
    end

    local configured = vim.env.NVIM_COBC_PATH

    if executable(configured or '') then
        state.cobc = normalize(fn.expand(configured))

        return state.cobc
    end

    local on_path = fn.exepath('cobc')

    if nonempty_string(on_path) then
        state.cobc = fs.normalize(on_path)

        return state.cobc
    end

    return nil
end

---@return string?
local function cobc_version()
    local cobc = find_cobc()

    if cobc == nil then
        return nil
    end

    local result = system({ cobc, '--version' })

    if result == nil or result.code ~= 0 or type(result.stdout) ~= 'string' then
        return nil
    end

    return trim(result.stdout:match('[^\r\n]*') or '')
end

---@return table?
local function gdb_foundation()
    local ok, gdb = pcall(require, 'dap.gdb')

    if not ok or gdb == nil then
        return nil
    end

    return gdb
end

---@param source string
---@param output string
---@return boolean
local function compile_debug(source, output)
    local cobc = find_cobc()

    if cobc == nil then
        notify('cobc was not found', levels.ERROR)

        return false
    end

    --
    -- -x builds an executable, -g keeps debug symbols for the debugger.
    --
    local result = system({ cobc, '-x', '-g', '-o', output, source })

    if result == nil then
        notify('cobc could not be started', levels.ERROR)

        return false
    end

    if result.code ~= 0 then
        local detail = trim(result.stderr)

        if #detail > MAX_OUTPUT_BYTES then
            detail = detail:sub(1, MAX_OUTPUT_BYTES) .. '\n... truncated'
        end

        notify(('cobc failed:\n%s'):format(detail), levels.ERROR)

        return false
    end

    return true
end

---@param source string
---@return string?
local function compile_current(source)
    local root = project_root()
    local stem = fn.fnamemodify(source, ':t:r')
    local output = root .. '/' .. stem

    if not compile_debug(source, output) then
        return nil
    end

    local stat = uv.fs_stat(output)

    if stat == nil or stat.type ~= 'file' then
        notify('compiled program was not created: ' .. output, levels.ERROR)

        return nil
    end

    return output
end

---@return table?
function M.resolve_adapter()
    local gdb = gdb_foundation()

    if gdb == nil or type(gdb.resolve_adapter) ~= 'function' then
        return nil
    end

    return gdb.resolve_adapter()
end

---@type table
M.adapter = {
    name = 'gdb',
    type = 'executable',
    command = 'gdb',
    args = {
        '-q',
        '-i=dap',
    },
    options = {
        source_filetype = 'cobol',
    },
}

---@type table<string, table[]>
M.configurations = {
    cobol = {
        {
            name = 'COBOL: Compile and Debug Current File',
            type = 'gdb',
            request = 'launch',
            program = function()
                local filename = buffer_filename()

                if filename == '' then
                    notify('save the COBOL file first', levels.ERROR)

                    return nil
                end

                return compile_current(filename)
            end,
            cwd = function()
                return project_root()
            end,
            stopAtEntry = false,
        },
        {
            name = 'COBOL: Debug Compiled Program',
            type = 'gdb',
            request = 'launch',
            program = function()
                local input = fn.input('Program: ', project_root() .. '/', 'file')

                if input == '' then
                    return nil
                end

                return normalize(fn.expand(input))
            end,
            cwd = function()
                return project_root()
            end,
            stopAtEntry = false,
        },
        {
            name = 'COBOL: Attach to Process',
            type = 'gdb',
            request = 'attach',
            pid = function()
                local input = fn.input('Process ID: ')

                if input == '' then
                    return nil
                end

                local pid = tonumber(input)

                if pid == nil or pid < 1 or pid % 1 ~= 0 then
                    notify('process ID must be a positive integer', levels.ERROR)

                    return nil
                end

                return math.floor(pid)
            end,
        },
    },
}

local function check_health()
    local cobc = find_cobc()
    local version = cobc_version()
    local gdb = gdb_foundation()
    local gdb_ok = gdb ~= nil and type(gdb.dap_supported) == 'function' and gdb.dap_supported()

    local messages = {
        'COBOL DAP (GnuCOBOL via GDB)',
        '',
        'cobc: ' .. (cobc or 'not found'),
        'cobc version: ' .. (version or 'unknown'),
        'gdb native DAP: ' .. (gdb_ok and 'available' or 'missing (need gdb 14+)'),
        '',
        'note: Rech / SuperBOL are VS Code extensions, not DAP servers,',
        'so they cannot serve as debug adapters here.',
    }

    if cobc == nil then
        messages[#messages + 1] = ''
        messages[#messages + 1] = 'install GnuCOBOL or set NVIM_COBC_PATH=/path/to/cobc'
    end

    notify(table.concat(messages, '\n'), (cobc ~= nil and gdb_ok) and levels.INFO or levels.WARN)
end

---@type table<string, DebugCommand>
M.commands = {
    CobolCheck = {
        callback = function()
            check_health()
        end,
        desc = 'Check COBOL DAP configuration',
    },

    CobolCompile = {
        callback = function()
            local filename = buffer_filename()

            if filename == '' then
                notify('save the COBOL file first', levels.ERROR)

                return
            end

            local output = compile_current(filename)

            if output ~= nil then
                notify('compiled: ' .. output)
            end
        end,
        desc = 'Compile current COBOL file with debug symbols',
    },
}

---@type table<string, DebugMapping>
M.mappings = {
    cobol_check = {
        lhs = '<leader>dCc',
        mode = 'n',
        rhs = function()
            check_health()
        end,
        desc = 'COBOL DAP: Check configuration',
    },

    cobol_compile = {
        lhs = '<leader>dCb',
        mode = 'n',
        rhs = function()
            local cmd = M.commands.CobolCompile

            if cmd ~= nil and type(cmd.callback) == 'function' then
                cmd.callback()
            end
        end,
        desc = 'COBOL DAP: Compile with debug symbols',
    },
}

---@param opts? table user overrides; honours `opts.cobc`
function M.setup(opts)
    opts = opts or {}

    if nonempty_string(opts.cobc) then
        state.cobc = normalize(fn.expand(opts.cobc))
    end

    -- cobc is resolved again when compiling for a debug session; the
    -- compile step reports a missing compiler then, so no setup nag.
    local gdb = gdb_foundation()

    if gdb ~= nil and type(gdb.dap_supported) == 'function' and not gdb.dap_supported() then
        -- Defer the nag: surfaced by Session.spawn when a session starts.
        -- The command is cleared so the precheck blocks the spawn with this
        -- message instead of launching an unsuitable gdb.
        M.adapter.missing_message = 'gdb 14+ is required for COBOL debugging via native DAP'
        M.adapter.command = nil
    else
        M.adapter.command = 'gdb'
        M.adapter.missing_message = nil
    end
end

---@return string?
function M.cobc_path()
    return find_cobc()
end

return M
