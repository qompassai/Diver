-- #################################################################
-- ~/.config/nvim/lua/dap/gdb.lua
-- Qompass AI Diver Native GDB DAP Foundation Configuration
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
---@source https://sourceware.org/gdb/current/onlinedocs/gdb.html/Debugger-Adapter-Protocol.html
---@source https://github.com/bminor/binutils-gdb

--- Reusable GDB DAP foundation for compiled languages.
---
--- Plain-language version: this module finds the `gdb` program, checks that
--- it is new enough to speak the Debug Adapter Protocol (GDB 14 or newer),
--- and hands out ready-made debug recipes (launch, attach, core dump) that
--- other language modules reuse. GNU GDB compiles with native DAP support
--- behind `-i=dap`, so no separate adapter program is needed.
---@module 'dap.gdb'

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local uv = vim.uv
local levels = vim.log.levels

local M = {}

local SOURCE = 'gdb'
local PROBE_TIMEOUT_MS = 5000
local MIN_MAJOR = 14

---@type string[]
local ROOT_MARKERS = {
    'compile_commands.json',
    'CMakeLists.txt',
    'CMakePresets.json',
    'meson.build',
    'Makefile',
    'makefile',
    'build.ninja',
    '.git',
}

---@type string[]
local FILETYPES = {
    'c',
    'cpp',
    'objc',
    'objcpp',
    'asm',
    'd',
    'fortran',
    'rust',
}

---@type string[]
local WELL_KNOWN_PATHS = {
    '/usr/bin/gdb',
    '/opt/homebrew/bin/gdb',
    '/usr/local/bin/gdb',
}

---@class GdbFoundationState
---@field adapter_path string?
local state = {
    adapter_path = nil,
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
local function find_gdb()
    if state.adapter_path ~= nil then
        return state.adapter_path
    end

    local candidates = {}

    local configured = vim.env.NVIM_GDB_PATH

    if nonempty_string(configured) then
        candidates[#candidates + 1] = normalize(fn.expand(configured))
    end

    local global = vim.g.gdb_path

    if nonempty_string(global) then
        candidates[#candidates + 1] = normalize(fn.expand(global))
    end

    local on_path = fn.exepath('gdb')

    if nonempty_string(on_path) then
        candidates[#candidates + 1] = fs.normalize(on_path)
    end

    for _, path in ipairs(WELL_KNOWN_PATHS) do
        candidates[#candidates + 1] = path
    end

    for _, candidate in ipairs(candidates) do
        if executable(candidate) then
            state.adapter_path = fs.normalize(candidate)

            return state.adapter_path
        end
    end

    return nil
end

---@param path string
---@return integer?
local function gdb_major_version(path)
    local result = system({ path, '--version' })

    if result == nil or result.code ~= 0 or type(result.stdout) ~= 'string' then
        return nil
    end

    --
    -- Typical first line: "GNU gdb (GDB) 15.2".
    --
    local first = trim(result.stdout:match('[^\r\n]*') or '')
    local major = first:match('%((.-GDB.-)%) (%d+)%.') or first:match('GDB%s+(%d+)%.')

    if major == nil then
        major = first:match('(%d+)%.%d+')
    end

    if major == nil then
        return nil
    end

    return tonumber(major)
end

---@param path string
---@return string?
local function gdb_version_line(path)
    local result = system({ path, '--version' })

    if result == nil or result.code ~= 0 or type(result.stdout) ~= 'string' then
        return nil
    end

    return trim(result.stdout:match('[^\r\n]*') or '')
end

---@return boolean
local function supports_dap(path)
    local major = gdb_major_version(path)

    return major ~= nil and major >= MIN_MAJOR
end

---@return table?
function M.resolve_adapter()
    local path = find_gdb()

    if path == nil then
        return nil
    end

    if not supports_dap(path) then
        return nil
    end

    return {
        name = SOURCE,
        type = 'executable',
        command = path,
        args = {
            '-q',
            '-i=dap',
        },
    }
end

---@return string
local function adapter_command()
    local path = find_gdb()

    if path ~= nil then
        return path
    end

    --
    -- Keep the adapter structurally valid when gdb is missing.
    -- setup() warns before any session is attempted.
    --
    return 'gdb'
end

---@return string[]
local function prompt_args()
    local input = fn.input('Program arguments: ')

    if input == '' then
        return {}
    end

    --
    -- shellsplit handles quoted arguments but never runs a shell.
    --
    return fn.shellsplit(input)
end

---@param value string
---@return integer?
local function prompt_pid(value)
    local input = fn.input(value)

    if input == '' then
        return nil
    end

    local pid = tonumber(input)

    if pid == nil or pid < 1 or pid % 1 ~= 0 then
        notify('process ID must be a positive integer', levels.ERROR)

        return nil
    end

    return math.floor(pid)
end

---@param default string
---@return string?
local function prompt_program(default)
    local input = fn.input('Program: ', default, 'file')

    if input == '' then
        return nil
    end

    local path = normalize(fn.expand(input))
    local stat = uv.fs_stat(path)

    if stat == nil or stat.type ~= 'file' then
        notify(('not a file: %s'):format(path), levels.ERROR)

        return nil
    end

    return path
end

---@param opts table
---@return table?, string?
function M.build_launch(opts)
    opts = opts or {}

    if not nonempty_string(opts.program) then
        return nil, 'build_launch requires opts.program'
    end

    return {
        name = opts.name or 'GDB: Launch',
        type = SOURCE,
        request = 'launch',
        program = opts.program,
        args = opts.args or {},
        stopAtEntry = opts.stop_at_entry == true,
        cwd = opts.cwd or project_root(),
    }
end

---@param opts table
---@return table?, string?
function M.build_attach(opts)
    opts = opts or {}

    if opts.pid == nil then
        return nil, 'build_attach requires opts.pid'
    end

    return {
        name = opts.name or ('GDB: Attach %d'):format(opts.pid),
        type = SOURCE,
        request = 'attach',
        pid = opts.pid,
    }
end

---@param opts table
---@return table?, string?
function M.build_core(opts)
    opts = opts or {}

    if not nonempty_string(opts.program) then
        return nil, 'build_core requires opts.program'
    end

    if not nonempty_string(opts.core_file) then
        return nil, 'build_core requires opts.core_file'
    end

    return {
        name = opts.name or 'GDB: Core File',
        type = SOURCE,
        request = 'attach',
        program = opts.program,
        coreFile = opts.core_file,
    }
end

---@return table[]
local function base_configurations()
    return {
        {
            name = 'GDB: Launch Program',
            type = SOURCE,
            request = 'launch',
            program = function()
                return prompt_program(project_root() .. '/')
            end,
            args = prompt_args,
            stopAtEntry = false,
            cwd = function()
                return project_root()
            end,
        },
        {
            name = 'GDB: Launch Program (Stop on Entry)',
            type = SOURCE,
            request = 'launch',
            program = function()
                return prompt_program(project_root() .. '/')
            end,
            args = prompt_args,
            stopAtEntry = true,
            cwd = function()
                return project_root()
            end,
        },
        {
            name = 'GDB: Attach to Process',
            type = SOURCE,
            request = 'attach',
            pid = function()
                return prompt_pid('Process ID: ')
            end,
        },
        {
            name = 'GDB: Inspect Core File',
            type = SOURCE,
            request = 'attach',
            program = function()
                return prompt_program(project_root() .. '/')
            end,
            coreFile = function()
                local input = fn.input('Core file: ', project_root() .. '/', 'file')

                if input == '' then
                    return nil
                end

                return normalize(fn.expand(input))
            end,
        },
    }
end

---@type table
M.adapter = {
    name = SOURCE,
    type = 'executable',
    command = adapter_command(),
    args = {
        '-q',
        '-i=dap',
    },
    options = {
        source_filetype = 'c',
    },
}

---@type table<string, table[]>
M.configurations = {}

for _, filetype in ipairs(FILETYPES) do
    M.configurations[filetype] = base_configurations()
end

local function check_health()
    local path = find_gdb()
    local version = path ~= nil and gdb_version_line(path) or nil
    local dap_ok = path ~= nil and supports_dap(path) or false

    local messages = {
        'GDB DAP foundation',
        '',
        'executable: ' .. (path or 'not found'),
        'version: ' .. (version or 'unknown'),
        ('native DAP (-i=dap): %s (requires GDB %d+)'):format(dap_ok and 'yes' or 'no', MIN_MAJOR),
        'serves: ' .. table.concat(FILETYPES, ', '),
    }

    if path ~= nil and not dap_ok then
        messages[#messages + 1] = ''
        messages[#messages + 1] = ('this gdb is too old for native DAP (need %d+, have %s)'):format(
            MIN_MAJOR,
            version or 'unknown'
        )
    end

    if path == nil then
        messages[#messages + 1] = ''
        messages[#messages + 1] = 'install gdb 14+ or set NVIM_GDB_PATH=/path/to/gdb'
    end

    notify(table.concat(messages, '\n'), (path ~= nil and dap_ok) and levels.INFO or levels.WARN)
end

---@type table<string, DebugCommand>
M.commands = {
    GdbCheck = {
        callback = function()
            check_health()
        end,
        desc = 'Check GDB DAP foundation configuration',
    },

    GdbVersion = {
        callback = function()
            local path = find_gdb()

            if path == nil then
                notify('gdb not found', levels.WARN)

                return
            end

            notify(('%s'):format(gdb_version_line(path) or 'unknown version'))
        end,
        desc = 'Show gdb version',
    },
}

---@type table<string, DebugMapping>
M.mappings = {
    gdb_check = {
        lhs = '<leader>dGc',
        mode = 'n',
        rhs = function()
            check_health()
        end,
        desc = 'GDB DAP: Check configuration',
    },
}

---@param opts? table user overrides; honours `opts.gdb_path`
function M.setup(opts)
    opts = opts or {}

    if nonempty_string(opts.gdb_path) then
        state.adapter_path = normalize(fn.expand(opts.gdb_path))
    end

    local path = find_gdb()

    if path == nil then
        vim.schedule(function()
            notify(
                table.concat({
                    'gdb was not found.',
                    '',
                    'Install GDB 14 or newer, or set:',
                    'NVIM_GDB_PATH=/path/to/gdb',
                }, '\n'),
                levels.WARN
            )
        end)

        return
    end

    if not supports_dap(path) then
        vim.schedule(function()
            notify(
                ('gdb at %s is too old for native DAP (need %d+)'):format(path, MIN_MAJOR),
                levels.WARN
            )
        end)

        return
    end

    --
    -- Keep the adapter command synchronized with discovery.
    --
    M.adapter.command = path
end

---@return string?
function M.adapter_path()
    return find_gdb()
end

---@return boolean
function M.dap_supported()
    local path = find_gdb()

    return path ~= nil and supports_dap(path)
end

return M
