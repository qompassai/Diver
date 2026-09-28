-- #################################################################
-- ~/.config/nvim/lua/dap/perl.lua
-- Qompass AI Diver Native Perl Debug Adapter Configuration
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
---@source https://github.com/Nihilus118/perl-debug-adapter
---@source https://raw.githubusercontent.com/mason-org/mason-registry/main/packages/perl-debug-adapter/package.yaml

--- Perl debugging through the perl-debug-adapter DAP server.
---
--- Plain-language version: this module finds the `perl-debug-adapter`
--- program (a small Node.js server that wraps `perl -d` and speaks the
--- Debug Adapter Protocol), starts it so Neovim can talk to it over its
--- standard input/output, and hands out ready-made debug recipes: run the
--- current Perl file, stop on the first line, or run with arguments. The
--- adapter needs `perl` on your PATH and the PadWalker module installed.
---
--- Verified against upstream (2026-09-28): the Mason package
--- `perl-debug-adapter` builds `Nihilus118/perl-debug-adapter` and installs
--- the bin shim `perl-debug-adapter`, which runs
--- `node -- out/debugAdapter.js`. The adapter takes no CLI arguments; the
--- editor spawns it and speaks DAP over stdio. The `transport` launch option
--- selects how the adapter drives `perl -d` itself: `socket` (default, TCP
--- loopback, supports forked debugging) or `stdio` (legacy fallback).
--- Upstream documents launch requests only, so this module provides no
--- attach builder: perl's own debugger cannot attach to a running process.
---@module 'dap.perl'

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local uv = vim.uv
local levels = vim.log.levels

local M = {}

local SOURCE = 'perl'
local PROBE_TIMEOUT_MS = 5000

---@type string[]
local ROOT_MARKERS = {
    'Makefile.PL',
    'Build.PL',
    'cpanfile',
    'dist.ini',
    '.git',
}

---@type string[]
local FILETYPES = {
    'perl',
}

---@type string[]
local WELL_KNOWN_PATHS = {
    '~/.local/share/nvim/mason/bin/perl-debug-adapter',
    '/usr/local/bin/perl-debug-adapter',
}

---@class PerlState
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

---@param result vim.SystemCompleted?
---@return string
local function first_line(result)
    if result == nil then
        return ''
    end

    for _, stream in ipairs({ result.stdout, result.stderr }) do
        if type(stream) == 'string' then
            local line = trim(stream:match('[^\r\n]*') or '')

            if line ~= '' then
                return line
            end
        end
    end

    return ''
end

---@return string?
local function find_adapter()
    if state.adapter_path ~= nil then
        return state.adapter_path
    end

    local candidates = {}

    local configured = vim.env.NVIM_PERL_DEBUG_ADAPTER_PATH

    if nonempty_string(configured) then
        candidates[#candidates + 1] = normalize(fn.expand(configured))
    end

    local global = vim.g.perl_debug_adapter_path

    if nonempty_string(global) then
        candidates[#candidates + 1] = normalize(fn.expand(global))
    end

    local on_path = fn.exepath('perl-debug-adapter')

    if nonempty_string(on_path) then
        candidates[#candidates + 1] = fs.normalize(on_path)
    end

    for _, path in ipairs(WELL_KNOWN_PATHS) do
        candidates[#candidates + 1] = normalize(fn.expand(path))
    end

    for _, candidate in ipairs(candidates) do
        if executable(candidate) then
            state.adapter_path = fs.normalize(candidate)

            return state.adapter_path
        end
    end

    return nil
end

---@return string?
local function find_perl()
    local configured = vim.env.NVIM_PERL_PATH

    if executable(configured or '') then
        return normalize(fn.expand(configured))
    end

    local global = vim.g.perl_path

    if executable(global or '') then
        return normalize(fn.expand(global))
    end

    local on_path = fn.exepath('perl')

    if nonempty_string(on_path) then
        return fs.normalize(on_path)
    end

    return nil
end

---@param path string
---@return string
local function perl_version_line(path)
    return first_line(system({ path, '-v' }))
end

---@param path string
---@return boolean
local function perl5db_available(path)
    --
    -- `perl -d` loads perl5db.pl internally; requiring it directly is a
    -- safe, non-interactive probe that never starts the debugger REPL.
    --
    local result = system({ path, '-e', 'require "perl5db.pl"' })

    return result ~= nil and result.code == 0
end

---@param path string
---@return boolean
local function padwalker_available(path)
    --
    -- The adapter requires the PadWalker module; `-M` fails fast when it
    -- is missing, so this probe exits immediately either way.
    --
    local result = system({ path, '-MPadWalker', '-e1' })

    return result ~= nil and result.code == 0
end

---@return table?
function M.resolve_adapter()
    local path = find_adapter()

    if path == nil then
        return nil
    end

    --
    -- Upstream takes no CLI arguments: the editor spawns the shim and
    -- speaks DAP over stdio. Verified against the Mason package.yaml bin
    -- entry (`perl-debug-adapter: node:out/debugAdapter.js`) and the
    -- manual-install wrapper (`exec node -- .../out/debugAdapter.js`).
    --
    return {
        name = SOURCE,
        type = 'executable',
        command = path,
        args = {},
    }
end

---@return string
local function adapter_command()
    local path = find_adapter()

    if path ~= nil then
        return path
    end

    --
    -- Keep the adapter structurally valid when the shim is missing.
    -- setup() warns before any session is attempted.
    --
    return 'perl-debug-adapter'
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

---@param args unknown
---@return boolean
local function valid_args(args)
    if type(args) ~= 'table' then
        return false
    end

    for _, value in ipairs(args) do
        if type(value) ~= 'string' then
            return false
        end
    end

    return true
end

---@param opts table
---@return table?, string?
function M.build_launch(opts)
    opts = opts or {}

    if not nonempty_string(opts.program) then
        return nil, 'build_launch requires opts.program'
    end

    if opts.args ~= nil and not valid_args(opts.args) then
        return nil, 'build_launch requires opts.args to be a list of strings'
    end

    if opts.cwd ~= nil and not nonempty_string(opts.cwd) then
        return nil, 'build_launch requires opts.cwd to be a non-empty string'
    end

    local transport = opts.transport or 'socket'

    if transport ~= 'socket' and transport ~= 'stdio' then
        return nil, 'build_launch requires opts.transport to be "socket" or "stdio"'
    end

    return {
        name = opts.name or 'Perl: Launch',
        type = SOURCE,
        request = 'launch',
        program = opts.program,
        args = opts.args or {},
        cwd = opts.cwd or project_root(),
        stopOnEntry = opts.stop_on_entry == true,
        transport = transport,
    }
end

---@return table[]
local function base_configurations()
    return {
        {
            name = 'Perl: Debug Current File',
            type = SOURCE,
            request = 'launch',
            program = function()
                local filename = buffer_filename()

                if filename:match('%.p[lm]$') ~= nil or filename:match('%.t$') ~= nil then
                    return filename
                end

                return prompt_program(project_root() .. '/')
            end,
            args = {},
            stopOnEntry = false,
            transport = 'socket',
            cwd = function()
                return project_root()
            end,
        },
        {
            name = 'Perl: Debug Current File (Stop on Entry)',
            type = SOURCE,
            request = 'launch',
            program = function()
                local filename = buffer_filename()

                if filename:match('%.p[lm]$') ~= nil or filename:match('%.t$') ~= nil then
                    return filename
                end

                return prompt_program(project_root() .. '/')
            end,
            args = {},
            stopOnEntry = true,
            transport = 'socket',
            cwd = function()
                return project_root()
            end,
        },
        {
            name = 'Perl: Debug with Arguments',
            type = SOURCE,
            request = 'launch',
            program = function()
                return prompt_program(project_root() .. '/')
            end,
            args = prompt_args,
            stopOnEntry = false,
            transport = 'socket',
            cwd = function()
                return project_root()
            end,
        },
    }
end

---@type table
M.adapter = {
    name = SOURCE,
    type = 'executable',
    command = adapter_command(),
    args = {},
}

---@type table<string, table[]>
M.configurations = {}

for _, filetype in ipairs(FILETYPES) do
    M.configurations[filetype] = base_configurations()
end

local function check_health()
    local adapter = find_adapter()
    local perl = find_perl()
    local version = perl ~= nil and perl_version_line(perl) or ''
    local debugger_ok = perl ~= nil and perl5db_available(perl) or false
    local padwalker_ok = perl ~= nil and padwalker_available(perl) or false

    local messages = {
        'Perl DAP (perl-debug-adapter)',
        '',
        'adapter: ' .. (adapter or 'not found'),
        'perl: ' .. (perl or 'not found'),
        'perl version: ' .. (version ~= '' and version or 'unknown'),
        'perl -d (perl5db.pl): ' .. (debugger_ok and 'yes' or 'no'),
        'PadWalker (required): ' .. (padwalker_ok and 'yes' or 'no'),
    }

    if padwalker_ok == false and perl ~= nil then
        messages[#messages + 1] = ''
        messages[#messages + 1] = 'install PadWalker, e.g.: cpanm PadWalker'
    end

    if adapter == nil then
        messages[#messages + 1] = ''
        messages[#messages + 1] = 'install the adapter (:MasonInstall perl-debug-adapter)'
        messages[#messages + 1] = 'or set NVIM_PERL_DEBUG_ADAPTER_PATH=/path/to/perl-debug-adapter'
    end

    local healthy = adapter ~= nil and perl ~= nil and debugger_ok and padwalker_ok

    notify(table.concat(messages, '\n'), healthy and levels.INFO or levels.WARN)
end

---@type table<string, DebugCommand>
M.commands = {
    PerlDebugCheck = {
        callback = function()
            check_health()
        end,
        desc = 'Check Perl DAP configuration',
    },

    PerlDebugVersion = {
        callback = function()
            local adapter = find_adapter()
            local perl = find_perl()

            notify(
                ('adapter: %s\nperl: %s'):format(
                    adapter or 'not found',
                    (perl ~= nil and perl_version_line(perl) or 'not found')
                )
            )
        end,
        desc = 'Show perl-debug-adapter and perl versions',
    },
}

---@type table<string, DebugMapping>
M.mappings = {
    perl_debug_check = {
        lhs = '<leader>dPc',
        mode = 'n',
        rhs = function()
            check_health()
        end,
        desc = 'Perl DAP: Check configuration',
    },
}

---@param opts? table user overrides; honours `opts.perl_debug_adapter_path`
function M.setup(opts)
    opts = opts or {}

    if nonempty_string(opts.perl_debug_adapter_path) then
        state.adapter_path = normalize(fn.expand(opts.perl_debug_adapter_path))
    end

    if find_adapter() == nil then
        vim.schedule(function()
            notify(
                table.concat({
                    'perl-debug-adapter was not found.',
                    '',
                    'Install with: :MasonInstall perl-debug-adapter',
                    'Or set: NVIM_PERL_DEBUG_ADAPTER_PATH=/path/to/perl-debug-adapter',
                }, '\n'),
                levels.WARN
            )
        end)

        return
    end

    --
    -- Keep the adapter command synchronized with discovery.
    --
    M.adapter.command = state.adapter_path
end

---@return string?
function M.adapter_path()
    return find_adapter()
end

---@return string?
function M.perl_path()
    return find_perl()
end

return M
