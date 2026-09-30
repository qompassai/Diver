-- #################################################################
-- ~/.config/nvim/lua/dap/probe-rs.lua
-- Qompass AI Diver probe-rs DAP Configuration
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
---@source https://probe.rs/docs/tools/debugger/
---@source https://github.com/probe-rs/probe-rs

--- Native probe-rs DAP support for embedded Rust/ARM/RISC-V targets.
---
--- Plain-language version: this module finds the `probe-rs` program, picks a
--- free TCP port for its built-in debug server, and hands out ready-made
--- debug recipes (flash + debug, attach without flashing) for firmware
--- written in Rust. probe-rs speaks the Debug Adapter Protocol natively, so
--- no separate adapter program is needed.
---
--- The standalone server command below is verified against the probe-rs
--- debugger documentation ("Connecting to a standalone `probe-rs dap-server`
--- server"): `probe-rs dap-server --port 50000`. TCP is used because this
--- module drives nvim-dap server adapters, which connect to a host:port.
--- (probe-rs 0.32.0 also speaks DAP over stdin/stdout when `--port` is
--- omitted; this module does not use that mode.)
---
--- nvim-dap server adapters need a concrete port when the session starts,
--- so this module has no `${port}` placeholder: callers resolve a port first
--- with `M.find_free_port()` and pass it to `M.build_dap_server()` (or to
--- `M.setup({ port = ... })`, which stores the resolved adapter in
--- `M.adapter`).
---@module 'dap.probe-rs'

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local uv = vim.uv
local levels = vim.log.levels

local M = {}

local SOURCE = 'probe-rs'
local DEFAULT_HOST = '127.0.0.1'
local PORT_MIN = 1
local PORT_MAX = 65535
local PROBE_TIMEOUT_MS = 5000

---@type string[]
local ROOT_MARKERS = {
    'Cargo.toml',
    'Cargo.lock',
    '.git',
}

---@type string[]
local WELL_KNOWN_PATHS = {
    '/usr/bin/probe-rs',
    '/usr/local/bin/probe-rs',
    '~/.cargo/bin/probe-rs',
}

---@class ProbeRsState
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

    return fs.normalize(fn.fnamemodify(fn.expand(path), ':p'))
end

---@return string?
local function find_probe_rs()
    if state.adapter_path ~= nil then
        return state.adapter_path
    end

    local candidates = {}

    local configured = vim.env.NVIM_PROBE_RS_PATH

    if nonempty_string(configured) then
        candidates[#candidates + 1] = normalize(configured)
    end

    local global = vim.g.probe_rs_path

    if nonempty_string(global) then
        candidates[#candidates + 1] = normalize(global)
    end

    local on_path = fn.exepath('probe-rs')

    if nonempty_string(on_path) then
        candidates[#candidates + 1] = fs.normalize(on_path)
    end

    for _, path in ipairs(WELL_KNOWN_PATHS) do
        candidates[#candidates + 1] = normalize(path)
    end

    for _, candidate in ipairs(candidates) do
        if executable(candidate) then
            state.adapter_path = fs.normalize(candidate)

            return state.adapter_path
        end
    end

    return nil
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

---@param path string
---@return string?
local function version_line(path)
    local result = system({ path, '--version' })

    if result == nil or result.code ~= 0 or type(result.stdout) ~= 'string' then
        return nil
    end

    local first = result.stdout:match('[^\r\n]*') or ''

    return vim.trim(first)
end

---@return string
local function adapter_command()
    local path = find_probe_rs()

    if path ~= nil then
        return path
    end

    --
    -- Keep the adapter structurally valid when probe-rs is missing.
    -- setup() warns before any session is attempted.
    --
    return 'probe-rs'
end

---@param port unknown
---@return integer?, string?
local function validate_port(port)
    if type(port) ~= 'number' or port % 1 ~= 0 or port < PORT_MIN or port > PORT_MAX then
        return nil, 'port must be an integer between 1 and 65535'
    end

    return math.floor(port)
end

---@param bufnr? integer
---@return string
local function project_root(bufnr)
    bufnr = bufnr or api.nvim_get_current_buf()

    if api.nvim_buf_is_valid(bufnr) then
        local name = api.nvim_buf_get_name(bufnr)

        if name ~= '' then
            local filename = normalize(name)
            local detected = fs.root(filename, ROOT_MARKERS)

            if type(detected) == 'string' and detected ~= '' then
                return fs.normalize(detected)
            end
        end
    end

    return fs.normalize(fn.getcwd())
end

---@return string?
local function prompt_chip()
    local input = fn.input('Chip (e.g. nRF52840_xxAA): ')

    if input == '' then
        return nil
    end

    return vim.trim(input)
end

---@param default string
---@return string?
local function prompt_program(default)
    --
    -- The ELF may not exist yet (built by a later cargo build), so unlike
    -- the gdb foundation this prompt does not require the file to exist.
    --
    local input = fn.input('Program (ELF): ', default, 'file')

    if input == '' then
        return nil
    end

    return normalize(input)
end

---Build an nvim-dap server adapter that connects to a `probe-rs dap-server`
---listening on the given port. The caller is responsible for starting the
---server first (or for registering an adapter whose `executable` spawns it).
---@param opts table `{ port: integer, host?: string }`
---@return table?, string?
function M.build_dap_server(opts)
    opts = opts or {}

    local port, port_err = validate_port(opts.port)

    if port == nil then
        return nil, ('build_dap_server: %s'):format(port_err)
    end

    local host = opts.host or DEFAULT_HOST

    if not nonempty_string(host) then
        return nil, 'build_dap_server requires opts.host to be a non-empty string'
    end

    return {
        name = SOURCE,
        type = 'server',
        host = host,
        port = port,
        executable = {
            command = adapter_command(),
            args = { 'dap-server', '--port', tostring(port) },
        },
    }
end

---Pick a free TCP loopback port by binding to port 0 and reading the
---assigned port back. The handle is closed exactly once before returning.
---Callers must still handle the (unlikely) race where another process
---claims the port before `probe-rs dap-server` starts.
---@return integer?, string?
function M.find_free_port()
    local tcp_ok, tcp = pcall(uv.new_tcp)

    if not tcp_ok or tcp == nil then
        return nil, 'find_free_port: uv.new_tcp failed'
    end

    local closed = false

    local function close_once()
        if not closed then
            closed = true

            pcall(function()
                tcp:close()
            end)
        end
    end

    local bind_ok, bind_result = pcall(function()
        return tcp:bind(DEFAULT_HOST, 0)
    end)

    if not bind_ok or (bind_result ~= 0 and bind_result ~= true) then
        close_once()

        return nil, 'find_free_port: bind to 127.0.0.1:0 failed'
    end

    local name_ok, sockname = pcall(function()
        return tcp:getsockname()
    end)

    close_once()

    if not name_ok or type(sockname) ~= 'table' then
        return nil, 'find_free_port: getsockname failed'
    end

    local port, port_err = validate_port(sockname.port)

    if port == nil then
        return nil, ('find_free_port: %s'):format(port_err)
    end

    return port
end

---Build a probe-rs flash-and-debug configuration for one chip.
---
---opts: `{ chip: string, probe?: string, speed?: integer,
---  connect_under_reset?: boolean, program?: string, name?: string }`
---@param opts table
---@return table?, string?
function M.build_attach(opts)
    opts = opts or {}

    if not nonempty_string(opts.chip) then
        return nil, 'build_attach requires opts.chip to be a non-empty string'
    end

    local speed = nil

    if opts.speed ~= nil then
        if type(opts.speed) ~= 'number' or opts.speed < 1 or opts.speed % 1 ~= 0 then
            return nil, 'build_attach requires opts.speed to be a positive integer (kHz)'
        end

        speed = math.floor(opts.speed)
    end

    if opts.probe ~= nil and not nonempty_string(opts.probe) then
        return nil, 'build_attach requires opts.probe to be a non-empty string'
    end

    if opts.program ~= nil and not nonempty_string(opts.program) then
        return nil, 'build_attach requires opts.program to be a non-empty string'
    end

    local core_configs = {}

    if opts.program ~= nil then
        core_configs = {
            {
                coreIndex = 0,
                programBinary = opts.program,
            },
        }
    end

    return {
        name = opts.name or ('probe-rs: %s'):format(opts.chip),
        type = SOURCE,
        request = 'launch',
        chip = opts.chip,
        speed = speed,
        probe = opts.probe,
        connectUnderReset = opts.connect_under_reset == true,
        coreConfigs = core_configs,
    }
end

---@type table<string, any>
M.adapter = {
    name = SOURCE,
    type = 'server',
    host = DEFAULT_HOST,
    --
    -- No `${port}` placeholder: nvim-dap server adapters need a concrete
    -- port when the session starts. Callers resolve one first with
    -- M.find_free_port() and M.build_dap_server(), or pass
    -- `M.setup({ port = ... })` to store the resolved adapter here.
    --
    port = nil,
    executable = {
        command = 'probe-rs',
        args = { 'dap-server' },
    },
}

---@type table<string, table[]>
M.configurations = {
    rust = {
        {
            name = 'probe-rs: Flash & Debug',
            type = SOURCE,
            request = 'launch',
            chip = function()
                return prompt_chip()
            end,
            coreConfigs = function()
                local program = prompt_program(project_root() .. '/')

                if program == nil then
                    return nil
                end

                return {
                    {
                        coreIndex = 0,
                        programBinary = program,
                    },
                }
            end,
            cwd = function()
                return project_root()
            end,
        },
        {
            name = 'probe-rs: Attach (no flash)',
            type = SOURCE,
            request = 'attach',
            chip = function()
                return prompt_chip()
            end,
            cwd = function()
                return project_root()
            end,
        },
    },
}

local function check_health()
    local path = find_probe_rs()
    local version = path ~= nil and version_line(path) or nil

    local messages = {
        'probe-rs DAP configuration',
        '',
        'executable: ' .. (path or 'not found'),
        'version: ' .. (version or 'unknown'),
        'server command: probe-rs dap-server --port <port>',
        'serves: rust (embedded)',
    }

    if path == nil then
        messages[#messages + 1] = ''
        messages[#messages + 1] = 'install probe-rs or set NVIM_PROBE_RS_PATH=/path/to/probe-rs'
    end

    notify(table.concat(messages, '\n'), path ~= nil and levels.INFO or levels.WARN)
end

---@type table<string, DebugCommand>
M.commands = {
    ProbeRsCheck = {
        callback = function()
            check_health()
        end,
        desc = 'Check probe-rs DAP configuration',
    },
}

---@type table<string, DebugMapping>
M.mappings = {
    probe_rs_check = {
        lhs = '<leader>dPc',
        mode = 'n',
        rhs = function()
            check_health()
        end,
        desc = 'probe-rs DAP: Check configuration',
    },
}

---@param opts? table user overrides; honours `opts.probe_rs_path` and `opts.port`
function M.setup(opts)
    opts = opts or {}

    if nonempty_string(opts.probe_rs_path) then
        state.adapter_path = normalize(opts.probe_rs_path)
    end

    if opts.port ~= nil then
        local adapter, err = M.build_dap_server({ port = opts.port, host = opts.host })

        if adapter == nil then
            vim.schedule(function()
                notify(('invalid port for probe-rs adapter: %s'):format(err), levels.ERROR)
            end)
        else
            M.adapter = adapter
        end
    else
        --
        -- Keep the adapter command synchronized with discovery even when no
        -- port was resolved yet.
        --
        M.adapter.executable.command = adapter_command()
    end

    local path = find_probe_rs()

    if path == nil then
        -- Defer the nag: surfaced by Session.connect when a session starts.
        M.adapter.executable.missing_message = table.concat({
            'probe-rs was not found.',
            '',
            'Install probe-rs, or set:',
            'NVIM_PROBE_RS_PATH=/path/to/probe-rs',
        }, '\n')
    else
        M.adapter.executable.missing_message = nil
    end
end

---@return string?
function M.adapter_path()
    return find_probe_rs()
end

return M
