-- #################################################################
-- ~/.config/nvim/lua/dap/cortex-debug.lua
-- Qompass AI Diver Cortex-Debug GDB Server Matrix Configuration
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
---@source https://github.com/mason-org/mason-registry/blob/main/packages/cortex-debug/package.yaml
---@source https://github.com/Marus/cortex-debug
---@source https://openocd.org/doc/html/index.html
---@source https://www.segger.com/products/debug-probes/j-link/technology/gdb-server/
---@source https://pyocd.io/docs/gdbserver.html
---@source https://github.com/stlink-org/stlink/blob/master/doc/tutorial.md

--- Cortex-M GDB/OpenOCD server matrix for ARM firmware debugging.
---
--- Plain-language version: this module knows how to start the four GDB
--- servers that the Cortex-Debug ecosystem uses (OpenOCD, SEGGER J-Link,
--- pyOCD, ST-Link), and hands out debug recipes for firmware written in C,
--- C++, or Rust. The actual debugging still runs through GDB, which this
--- module borrows from the shared `dap.gdb` foundation (GDB 14 or newer).
---
--- EXPLICIT SCOPE NOTE: the Cortex-Debug VS Code extension is NOT a
--- standalone program. The mason-registry `cortex-debug` package ships a
--- `.vsix` extension bundle (`source: pkg:openvsx/marus25/cortex-debug`,
--- `share: cortex-debug/: extension/`) with no standalone executable entry
--- point, so there is no Cortex-Debug binary to wire as a DAP adapter.
--- This module therefore implements the Cortex-Debug *server matrix*: it
--- builds the exact, vendor-verified command lines for the underlying GDB
--- servers and delegates the DAP adapter to the `dap.gdb` foundation.
---
--- WORKFLOW: the GDB server must be running before GDB can talk to the
--- chip. `M.build_server_config()` returns a recipe with the exact server
--- command (`server_argv`) and the GDB-side connection string
--- (`gdb_target`, e.g. `127.0.0.1:3333` for `(gdb) target extended-remote`).
--- Start the server in a terminal, then debug the firmware ELF with the
--- `c`/`cpp`/`rust` configurations below (type `gdb`, served by the
--- dap.gdb foundation adapter) and connect GDB to the server.
---
--- Verified command templates (never invented):
---   OpenOCD : `openocd -f interface/<cfg> -f target/<cfg>` (GDB on 3333)
---   J-Link  : `JLinkGDBServerCLExe -device <dev> -if SWD` (GDB on 2331;
---             the CLI executable is preferred; the GUI `JLinkGDBServer`
---             is the fallback discovery candidate)
---   pyOCD   : `pyocd gdbserver` (GDB on 3333, `-p`/`--port` to change)
---   ST-Link : `st-util` (GDB on 4242, `-p`/`--listen_port` to change)
---@module 'dap.cortex-debug'

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local levels = vim.log.levels

local M = {}

local SOURCE = 'cortex-debug'
local DEFAULT_HOST = '127.0.0.1'
local PORT_MIN = 1
local PORT_MAX = 65535

---@type string[]
local ROOT_MARKERS = {
    'CMakeLists.txt',
    'Makefile',
    'makefile',
    'Cargo.toml',
    '.git',
}

---@class CortexDebugServer
---@field label string human-readable name
---@field binaries string[] discovery candidates, preferred first
---@field default_port integer GDB server port when the vendor default is used
---@field gdb_server_cmd string verified command template for documentation

---@type table<string, CortexDebugServer>
M.servers = {
    openocd = {
        label = 'OpenOCD',
        binaries = { 'openocd' },
        default_port = 3333,
        gdb_server_cmd = 'openocd -f interface/<interface>.cfg -f target/<target>.cfg',
    },
    jlink = {
        label = 'SEGGER J-Link GDB Server',
        binaries = { 'JLinkGDBServerCLExe', 'JLinkGDBServer' },
        default_port = 2331,
        gdb_server_cmd = 'JLinkGDBServerCLExe -device <device> -if <interface>',
    },
    pyocd = {
        label = 'pyOCD',
        binaries = { 'pyocd' },
        default_port = 3333,
        gdb_server_cmd = 'pyocd gdbserver [--target <target>] [-p <port>]',
    },
    stlink = {
        label = 'ST-Link (st-util)',
        binaries = { 'st-util' },
        default_port = 4242,
        gdb_server_cmd = 'st-util [-p <port>]',
    },
}

---@type string[]
local SERVER_KEYS = { 'openocd', 'jlink', 'pyocd', 'stlink' }

---@class CortexDebugState
---@field binaries table<string, string> per-server path overrides
---@field default_server string
local state = {
    binaries = {},
    default_server = 'openocd',
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

---@param port unknown
---@return integer?, string?
local function validate_port(port)
    if type(port) ~= 'number' or port % 1 ~= 0 or port < PORT_MIN or port > PORT_MAX then
        return nil, 'port must be an integer between 1 and 65535'
    end

    return math.floor(port)
end

---@param speed unknown
---@return integer?, string?
local function validate_speed(speed)
    if type(speed) ~= 'number' or speed < 1 or speed % 1 ~= 0 then
        return nil, 'speed must be a positive integer (kHz)'
    end

    return math.floor(speed)
end

---@param server string matrix key
---@return string?
local function find_server_binary(server)
    local entry = M.servers[server]

    if entry == nil then
        return nil
    end

    local override = state.binaries[server]

    if nonempty_string(override) and fn.executable(override) == 1 then
        return override
    end

    for _, binary in ipairs(entry.binaries) do
        local on_path = fn.exepath(binary)

        if nonempty_string(on_path) and fn.executable(on_path) == 1 then
            return fs.normalize(on_path)
        end
    end

    return nil
end

---@param bufnr? integer
---@return string
local function project_root(bufnr)
    bufnr = bufnr or api.nvim_get_current_buf()

    if api.nvim_buf_is_valid(bufnr) then
        local name = api.nvim_buf_get_name(bufnr)

        if name ~= '' then
            local detected = fs.root(name, ROOT_MARKERS)

            if type(detected) == 'string' and detected ~= '' then
                return fs.normalize(detected)
            end
        end
    end

    return fs.normalize(fn.getcwd())
end

---@param default string
---@return string?
local function prompt_program(default)
    --
    -- The firmware ELF may not exist yet (built later), so this prompt does
    -- not require the file to exist.
    --
    local input = fn.input('Firmware (ELF): ', default, 'file')

    if input == '' then
        return nil
    end

    return fs.normalize(fn.fnamemodify(fn.expand(input), ':p'))
end

---Ask the shared gdb foundation for a resolved DAP adapter, or nil when
---the foundation is unavailable. Mirrors the delegation pattern used by
---dap.lldb-dap: this module owns the server matrix, dap.gdb owns GDB.
---@return table?
function M.gdb_adapter()
    local ok, foundation = pcall(require, 'dap.gdb')

    if not ok or type(foundation) ~= 'table' then
        return nil
    end

    if type(foundation.resolve_adapter) ~= 'function' then
        return nil
    end

    local resolved_ok, adapter = pcall(foundation.resolve_adapter)

    if not resolved_ok or type(adapter) ~= 'table' then
        return nil
    end

    if type(adapter.command) ~= 'string' or adapter.command == '' then
        return nil
    end

    return adapter
end

---Build the exact argv needed to start one matrix GDB server.
---
---Per-server required options (all other fields optional):
---  openocd: `interface_cfg`, `target_cfg` (e.g. `stlink.cfg`, `stm32f4x.cfg`)
---  jlink:   `device` (or `device_or_config`), e.g. `STM32F427VI`
---  pyocd:   `target` (or `device_or_config`), e.g. `stm32f401xc`
---  stlink:  none (`device_or_config` is ignored; st-util takes no device)
---
---opts: `{ interface_cfg?: string, target_cfg?: string, device?: string,
---  device_or_config?: string, interface?: string, target?: string,
---  speed?: integer, port?: integer }`
---@param server string one of: openocd, jlink, pyocd, stlink
---@param opts table
---@return string[]?, string?
---@param opts table
---@return integer?, string?
local function resolve_speed(opts)
    if opts.speed == nil then
        return nil
    end

    local speed, err = validate_speed(opts.speed)

    if speed == nil then
        return nil, ('build_server_argv: %s'):format(err)
    end

    return speed
end

---@param binary string
---@param opts table
---@param speed integer?
---@return string[]?, string?
local function openocd_argv(binary, opts, speed)
    if not nonempty_string(opts.interface_cfg) then
        return nil, 'build_server_argv: openocd requires opts.interface_cfg (e.g. stlink.cfg)'
    end

    if not nonempty_string(opts.target_cfg) then
        return nil, 'build_server_argv: openocd requires opts.target_cfg (e.g. stm32f4x.cfg)'
    end

    local argv = {
        binary,
        '-f',
        'interface/' .. opts.interface_cfg,
        '-f',
        'target/' .. opts.target_cfg,
    }

    if speed ~= nil then
        argv[#argv + 1] = '-c'
        argv[#argv + 1] = ('adapter speed %d'):format(speed)
    end

    return argv
end

---@param binary string
---@param opts table
---@param speed integer?
---@return string[]?, string?
local function jlink_argv(binary, opts, speed)
    local device = opts.device or opts.device_or_config

    if not nonempty_string(device) then
        return nil, 'build_server_argv: jlink requires opts.device (e.g. STM32F427VI)'
    end

    local interface = opts.interface or 'SWD'

    if not nonempty_string(interface) then
        return nil, 'build_server_argv requires opts.interface to be a non-empty string'
    end

    local argv = { binary, '-device', device, '-if', interface }

    if speed ~= nil then
        argv[#argv + 1] = '-speed'
        argv[#argv + 1] = tostring(speed)
    end

    return argv
end

---@param binary string
---@param opts table
---@return string[]?, string?
local function pyocd_argv(binary, opts)
    --
    -- pyocd gdbserver has no speed flag; resolve_speed() already rejected
    -- garbage, so a valid speed is silently unused here.
    --
    local argv = { binary, 'gdbserver' }
    local target = opts.target or opts.device_or_config

    if target ~= nil then
        if not nonempty_string(target) then
            return nil, 'build_server_argv requires opts.target to be a non-empty string'
        end

        argv[#argv + 1] = '--target'
        argv[#argv + 1] = target
    end

    if opts.port ~= nil then
        local port, err = validate_port(opts.port)

        if port == nil then
            return nil, ('build_server_argv: %s'):format(err)
        end

        argv[#argv + 1] = '-p'
        argv[#argv + 1] = tostring(port)
    end

    return argv
end

---@param binary string
---@param opts table
---@return string[]?, string?
local function stlink_argv(binary, opts)
    --
    -- st-util takes no device argument; it is ignored here (documented in
    -- the M.build_server_argv docstring).
    --
    local argv = { binary }

    if opts.port ~= nil then
        local port, err = validate_port(opts.port)

        if port == nil then
            return nil, ('build_server_argv: %s'):format(err)
        end

        argv[#argv + 1] = '-p'
        argv[#argv + 1] = tostring(port)
    end

    return argv
end

function M.build_server_argv(server, opts)
    opts = opts or {}

    local entry = M.servers[server]

    if entry == nil then
        return nil,
            ("build_server_argv: unknown server '%s' (expected one of: %s)"):format(
                tostring(server),
                table.concat(SERVER_KEYS, ', ')
            )
    end

    local binary = find_server_binary(server) or entry.binaries[1]
    local speed, err = resolve_speed(opts)

    if err ~= nil then
        return nil, err
    end

    if server == 'openocd' then
        return openocd_argv(binary, opts, speed)
    end

    if server == 'jlink' then
        return jlink_argv(binary, opts, speed)
    end

    if server == 'pyocd' then
        return pyocd_argv(binary, opts)
    end

    return stlink_argv(binary, opts)
end

---Build a complete Cortex-Debug server recipe: the exact command to start
---the GDB server plus the connection details GDB needs.
---
---NOTE: `dap.gdb` exposes no remote-target builder (verified: it ships
---`build_launch`/`build_attach`/`build_core` only), so this returns a
---recipe rather than an nvim-dap configuration. The caller starts
---`server_argv` in a terminal, then points GDB at `gdb_target` with
---`(gdb) target extended-remote <host>:<port>`.
---
---opts: `{ server: string, device_or_config?: string, host?: string,
---  port?: integer, program?: string, name?: string, interface_cfg?: string,
---  target_cfg?: string, device?: string, interface?: string,
---  target?: string, speed?: integer }`
---@param opts table
---@return table?, string?
function M.build_server_config(opts)
    opts = opts or {}

    local entry = M.servers[opts.server]

    if entry == nil then
        return nil,
            ("build_server_config: unknown server '%s' (expected one of: %s)"):format(
                tostring(opts.server),
                table.concat(SERVER_KEYS, ', ')
            )
    end

    local host = opts.host or DEFAULT_HOST

    if not nonempty_string(host) then
        return nil, 'build_server_config requires opts.host to be a non-empty string'
    end

    local port, port_err = validate_port(opts.port or entry.default_port)

    if port == nil then
        return nil, ('build_server_config: %s'):format(port_err)
    end

    if opts.program ~= nil and not nonempty_string(opts.program) then
        return nil, 'build_server_config requires opts.program to be a non-empty string'
    end

    local argv, argv_err = M.build_server_argv(opts.server, opts)

    if argv == nil then
        return nil, argv_err
    end

    return {
        name = opts.name or ('Cortex-Debug: %s'):format(entry.label),
        server = opts.server,
        server_argv = argv,
        host = host,
        port = port,
        program = opts.program,
        gdb_target = ('%s:%d'):format(host, port),
        next_steps = table.concat({
            '1. Start the GDB server in a terminal:',
            '   ' .. table.concat(argv, ' '),
            ('2. In GDB (or the DAP REPL): target extended-remote %s:%d'):format(host, port),
        }, '\n'),
    }
end

---@return table[]
local function firmware_configurations()
    local configurations = {}

    --
    -- Sorted keys keep the configuration order deterministic.
    --
    for _, key in ipairs(SERVER_KEYS) do
        local entry = M.servers[key]

        configurations[#configurations + 1] = {
            --
            -- type 'gdb' routes through the dap.gdb foundation adapter.
            -- Start the GDB server first (see :CortexDebugServerCommand),
            -- then connect GDB with `target extended-remote`.
            --
            name = ('Cortex-Debug (%s): Debug firmware'):format(entry.label),
            type = 'gdb',
            request = 'launch',
            program = function()
                return prompt_program(project_root() .. '/')
            end,
            cwd = function()
                return project_root()
            end,
        }
    end

    return configurations
end

---@type table<string, table[]>
M.configurations = {
    c = firmware_configurations(),
    cpp = firmware_configurations(),
    rust = firmware_configurations(),
}

local function server_summary_lines()
    local lines = { 'Cortex-Debug GDB server matrix', '' }

    for _, key in ipairs(SERVER_KEYS) do
        local entry = M.servers[key]
        local binary = find_server_binary(key)

        lines[#lines + 1] = ('%s (%s)'):format(entry.label, key)
        lines[#lines + 1] = ('  binary: %s'):format(binary or 'not found')
        lines[#lines + 1] = ('  default GDB port: %d'):format(entry.default_port)
        lines[#lines + 1] = ('  command: %s'):format(entry.gdb_server_cmd)
    end

    return lines
end

local function check_health()
    local lines = server_summary_lines()
    local adapter = M.gdb_adapter()

    lines[#lines + 1] = ''
    lines[#lines + 1] = 'GDB DAP foundation (dap.gdb): ' .. (adapter ~= nil and 'available' or 'unavailable')
    lines[#lines + 1] = ''
    lines[#lines + 1] = 'NOTE: Cortex-Debug is a VS Code extension, not a standalone'
    lines[#lines + 1] = 'binary (mason ships a .vsix). This module drives its GDB'
    lines[#lines + 1] = 'servers directly; start one before debugging.'

    local missing = 0

    for _, key in ipairs(SERVER_KEYS) do
        if find_server_binary(key) == nil then
            missing = missing + 1
        end
    end

    notify(table.concat(lines, '\n'), (missing == 0 and adapter ~= nil) and levels.INFO or levels.WARN)
end

---@type table<string, DebugCommand>
M.commands = {
    CortexDebugCheck = {
        callback = function()
            check_health()
        end,
        desc = 'Check Cortex-Debug GDB server matrix',
    },

    CortexDebugServers = {
        callback = function()
            notify(table.concat(server_summary_lines(), '\n'))
        end,
        desc = 'List Cortex-Debug GDB servers and their commands',
    },

    CortexDebugServerCommand = {
        callback = function()
            local lines = { 'Start one of these GDB servers in a terminal:', '' }

            for _, key in ipairs(SERVER_KEYS) do
                local entry = M.servers[key]

                lines[#lines + 1] = ('%s:'):format(entry.label)
                lines[#lines + 1] = ('  %s'):format(entry.gdb_server_cmd)
                lines[#lines + 1] = ('  GDB connects with: target extended-remote %s:%d'):format(
                    DEFAULT_HOST,
                    entry.default_port
                )
            end

            notify(table.concat(lines, '\n'))
        end,
        desc = 'Show Cortex-Debug GDB server start commands',
    },
}

---@type table<string, DebugMapping>
M.mappings = {
    cortex_debug_check = {
        lhs = '<leader>dCc',
        mode = 'n',
        rhs = function()
            check_health()
        end,
        desc = 'Cortex-Debug: Check configuration',
    },

    cortex_debug_servers = {
        lhs = '<leader>dCs',
        mode = 'n',
        rhs = function()
            notify(table.concat(server_summary_lines(), '\n'))
        end,
        desc = 'Cortex-Debug: List GDB servers',
    },
}

---@param opts? table user overrides; honours `opts.default_server` and `opts.binaries`
function M.setup(opts)
    opts = opts or {}

    if opts.default_server ~= nil then
        if M.servers[opts.default_server] == nil then
            vim.schedule(function()
                notify(
                    ("unknown default_server '%s' (expected one of: %s)"):format(
                        tostring(opts.default_server),
                        table.concat(SERVER_KEYS, ', ')
                    ),
                    levels.ERROR
                )
            end)
        else
            state.default_server = opts.default_server
        end
    end

    if type(opts.binaries) == 'table' then
        for key, path in pairs(opts.binaries) do
            if M.servers[key] ~= nil and nonempty_string(path) then
                state.binaries[key] = path
            end
        end
    end

    local adapter = M.gdb_adapter()

    if adapter == nil then
        vim.schedule(function()
            notify(
                table.concat({
                    'dap.gdb foundation is unavailable.',
                    '',
                    'Cortex-Debug firmware configurations need the gdb',
                    'foundation (GDB 14+ with native DAP).',
                }, '\n'),
                levels.WARN
            )
        end)
    end
end

---@return string?
function M.default_server()
    return state.default_server
end

return M
