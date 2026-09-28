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
    local major = first:match('%(.-GDB.-%) (%d+)%.') or first:match('GDB%s+(%d+)%.')

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

    if opts.args ~= nil and type(opts.args) ~= 'table' then
        return nil, 'build_launch requires opts.args to be a list of strings'
    end

    if opts.cwd ~= nil and not nonempty_string(opts.cwd) then
        return nil, 'build_launch requires opts.cwd to be a non-empty string'
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

    if type(opts.pid) ~= 'number' or opts.pid < 1 or opts.pid % 1 ~= 0 then
        return nil, 'build_attach requires opts.pid to be a positive integer'
    end

    return {
        name = opts.name or ('GDB: Attach %d'):format(opts.pid),
        type = SOURCE,
        request = 'attach',
        pid = math.floor(opts.pid),
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

    if M.remote_targets ~= nil then
        --
        -- One line: which remote templates are usable with this gdb.
        -- check_health is defined before the remote section, so the
        -- names are collected inline from the module table.
        --
        local names = {}

        for name in pairs(M.remote_targets) do
            names[#names + 1] = name
        end

        table.sort(names)

        messages[#messages + 1] = ('remote template (attach target=host:port): %s'):format(
            dap_ok and table.concat(names, ', ') or 'unavailable (GDB DAP missing)'
        )
    end

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

-- #################################################################
-- Remote-target template: GDB as protocol concentrator.
--
-- VERDICT (2026-09-28, verified against the GDB manual's DAP page):
-- GDB expresses a remote target in the *attach* request's `target`
-- parameter: "The target to which GDB should connect. This is a
-- string and is passed to the `target remote` command." There is no
-- launch-request field for `target remote`, so every remote config
-- below is { request = 'attach', target = 'host:port' }. The same
-- page recommends supplying `program` for remote targets ("for many
-- remote targets, this is not the case, and so this should be
-- supplied"). Deliberately rejected: `stop_at_entry` (stopOnEntry
-- is launch-only in GDB DAP) and `sysroot` / `solib_search_path`
-- (GDB defines no DAP attach parameter for them; set them with GDB
-- commands instead, e.g. via the DAP evaluate/repl or a .gdbinit).
-- rr's debug-server port is set with --dbgport (verified against
-- rr-debugger/rr#1990: `rr replay --dbgport 50505 ...`); there is no
-- well-known default, so the rr entry carries no default_port and
-- build_remote_target requires an explicit one.
---@source https://sourceware.org/gdb/current/onlinedocs/gdb.html/Debugger-Adapter-Protocol.html
---@source https://github.com/qemu/qemu/blob/HEAD/docs/system/gdb.rst
---@source https://allstar.jhuapl.edu/repo/p4/amd64/openocd/doc/openocd.html/GDB-and-OpenOCD.html
---@source https://lldb.llvm.org/resources/debugging.html

local PORT_MIN = 1
local PORT_MAX = 65535
local DEFAULT_HOST = '127.0.0.1'

---@class GdbRemoteTargetEntry
---@field label string
---@field default_port integer? well-known stub port; nil means the caller must pass opts.port
---@field spawn_hint string exact command that starts the stub
---@field description string

---@type table<string, GdbRemoteTargetEntry>
M.remote_targets = {
    gdbserver = {
        label = 'gdbserver',
        default_port = nil,
        spawn_hint = 'gdbserver :1234 ./prog',
        description = 'Remote program under gdbserver: Neovim -> GDB DAP -> GDB RSP -> gdbserver.',
    },
    qemu = {
        label = 'QEMU gdbstub',
        default_port = 1234,
        spawn_hint = 'qemu-system-x86_64 -s -S ...',
        description = 'QEMU user/system emulation: Neovim -> GDB DAP -> QEMU gdbstub'
            .. ' (-s listens on TCP 1234, -S freezes the guest at startup).',
    },
    openocd = {
        label = 'OpenOCD',
        default_port = 3333,
        spawn_hint = 'openocd -f interface/<cfg> -f target/<cfg>',
        description = 'OpenOCD GDB server for JTAG/SWD targets: Neovim -> GDB DAP -> OpenOCD GDB server.',
    },
    rr = {
        label = 'rr replay',
        default_port = nil,
        spawn_hint = 'rr replay --dbgport <port> <trace>',
        description = 'Deterministic replay: rr runs its own RSP debug server and GDB DAP'
            .. ' attaches to it via target remote host:port (set the port with --dbgport).',
    },
    ['lldb-server'] = {
        label = 'lldb-server',
        default_port = nil,
        spawn_hint = 'lldb-server gdbserver 127.0.0.1:1234 -- <prog>',
        description = 'Remote LLDB: Neovim -> lldb-dap -> LLDB -> lldb-server speaking gdb-remote over TCP.',
    },
}

---@return string[] sorted M.remote_targets keys, for deterministic output
local function remote_target_names()
    local names = {}

    for name in pairs(M.remote_targets) do
        names[#names + 1] = name
    end

    table.sort(names)

    return names
end

---@class GdbRemoteTargetOpts
---@field target string one of the M.remote_targets keys (required)
---@field host? string stub host; defaults to 127.0.0.1; passed through as DAP data, never shell-interpolated
---@field port? integer stub TCP port; required unless the target defines default_port
---@field program? string local symbol file; recommended for remote targets
---@field name? string configuration name override
---@field sysroot? string rejected: no GDB-DAP attach parameter exists for it
---@field solib_search_path? string rejected: no GDB-DAP attach parameter exists for it
---@field stop_at_entry? boolean rejected: stopOnEntry is launch-only in GDB DAP

---@param opts GdbRemoteTargetOpts
---@return table?, string?
function M.build_remote_target(opts)
    opts = opts or {}

    local entry = nil

    if type(opts.target) == 'string' then
        entry = M.remote_targets[opts.target]
    end

    if entry == nil then
        return nil,
            ('build_remote_target requires opts.target to be one of: %s'):format(
                table.concat(remote_target_names(), ', ')
            )
    end

    --
    -- These have no expression in GDB DAP's attach parameters; fail
    -- loudly instead of silently dropping them.
    --
    if opts.sysroot ~= nil then
        return nil,
            'build_remote_target: sysroot has no GDB-DAP attach expression; use `set sysroot` via evaluate/repl'
    end

    if opts.solib_search_path ~= nil then
        return nil,
            'build_remote_target: solib_search_path has no GDB-DAP attach expression;'
                .. ' use `set solib-search-path` via evaluate/repl'
    end

    if opts.stop_at_entry ~= nil then
        return nil,
            'build_remote_target: stop_at_entry is launch-only in GDB DAP; remote attach has no such field'
    end

    local host = DEFAULT_HOST

    if opts.host ~= nil then
        if not nonempty_string(opts.host) then
            return nil, 'build_remote_target requires opts.host to be a non-empty string'
        end

        host = opts.host
    end

    local port = opts.port

    if port == nil then
        port = entry.default_port

        if port == nil then
            return nil,
                ('build_remote_target: %s defines no default port; pass opts.port'):format(opts.target)
        end
    end

    if type(port) ~= 'number' or port % 1 ~= 0 or port < PORT_MIN or port > PORT_MAX then
        return nil,
            ('build_remote_target requires opts.port to be an integer in %d-%d'):format(
                PORT_MIN,
                PORT_MAX
            )
    end

    port = math.floor(port)

    local program = nil

    if opts.program ~= nil then
        if not nonempty_string(opts.program) then
            return nil, 'build_remote_target requires opts.program to be a non-empty string'
        end

        local path = normalize(fn.expand(opts.program))
        local stat = uv.fs_stat(path)

        if stat == nil or stat.type ~= 'file' then
            return nil, ('build_remote_target: program is not a file: %s'):format(path)
        end

        program = path
    end

    local config = {
        name = opts.name or ('GDB: Remote %s'):format(entry.label),
        type = SOURCE,
        request = 'attach',
        target = ('%s:%d'):format(host, port),
    }

    if program ~= nil then
        config.program = program
    end

    return config
end

return M
