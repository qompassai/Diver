-- #################################################################
-- lua/dap/backend.lua
-- Qompass AI Diver DebugBackend Registry
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
---@source https://microsoft.github.io/debug-adapter-protocol/
---@source https://microsoft.github.io/debug-adapter-protocol/implementors/adapters/
---@source https://sourceware.org/gdb/current/onlinedocs/gdb.html/Debugger-Adapter-Protocol.html
---@source https://github.com/llvm/llvm-project/blob/main/lldb/tools/lldb-dap/README.md
---@source https://github.com/go-delve/delve/blob/master/Documentation/usage/dlv_dap.md
---@source https://github.com/microsoft/debugpy/wiki/DAP-Client-reference
---@source https://github.com/Samsung/netcoredbg
---@source https://github.com/probe-rs/webpage/blob/HEAD/src/content/docs/tools/debugger.mdx
---@source https://github.com/ruby/debug
---@source https://github.com/hackwaly/ocamlearlybird
---@source https://github.com/whatsapp/edb
---@source https://github.com/PowerShell/PowerShellEditorServices
---@source https://github.com/ManuelHentschel/VSCode-R-Debugger

--- DebugBackend registry: debugger plus transport plus protocol, not just adapters.
---
--- Plain-language version: this module is the phone book for debuggers. Each
--- entry says which languages it covers, what the real debugger underneath is
--- (gdb, Delve, Xdebug, ...), which program translates for it (the adapter),
--- and how Neovim talks to that program (a process it starts, a TCP port it
--- connects to, a named pipe). Health checks walk the same chain every time:
--- is the editor side up, is the adapter program installed, is the underlying
--- debugger usable, and -- for network backends -- is the remote target
--- answering. Nothing here launches a session; it only describes and probes.
---@module 'dap.backend'

local fn = vim.fn
local fs = vim.fs
local uv = vim.uv

local M = {}

---@alias ProbeStage 'neovim'|'adapter'|'debugger'|'target' chain stage reached or failed at

---@class ProbeResult
---@field ok boolean
---@field stage ProbeStage chain stage reached or failed at
---@field message string human-readable detail

---@class DebugBackend
---@field id string
---@field languages string[]
---@field debugger string             -- gdb, lldb, Xdebug, JDWP runtime, etc.
---@field adapter string|nil          -- lldb-dap, vscode-js-debug, php-debug, etc.
---@field transport 'stdio'|'tcp'|'pipe'|'unix'
---@field protocol 'dap'|'mi'|'jdwp'|'cdp'|'dbgp'|'rsp'
---@field dap_native boolean
---@field probe fun(): ProbeResult
---@field build_config fun(ctx: table): table

---@class BackendProbeSpec
---@field binaries string[] candidate executable names, tried in order
---@field env_var string? NVIM_<NAME>_PATH style override
---@field global_key string? vim.g.<name>_path style override
---@field well_known string[]? extra absolute paths to try
---@field skip_adapter boolean? no adapter-binary stage (the debugger IS the server)
---@field debugger_binaries string[]? underlying debugger/runtime binaries to verify
---@field version { argv: string[], min_major: integer }? minimum-version gate
---@field validate (fun(path: string|nil, run: fun(argv: string[]): vim.SystemCompleted?): boolean, string?)?
---@field validate_stage 'adapter'|'debugger'|'target'? stage blamed when validate fails
---@field tcp { host: string, port: integer }? default target for the reachability stage

local PROBE_TIMEOUT_MS = 5000
local PROBE_TCP_TIMEOUT_MS = 3000
local REGISTRY_MAX = 128
local LOOPBACK = '127.0.0.1'
local MASON_BIN = '~/.local/share/nvim/mason/bin/'

---@type table<string, boolean>
local TRANSPORTS = {
    stdio = true,
    tcp = true,
    pipe = true,
    unix = true,
}

---@type table<string, boolean>
local PROTOCOLS = {
    dap = true,
    mi = true,
    jdwp = true,
    cdp = true,
    dbgp = true,
    rsp = true,
}

--
-- Never seed or accept these: deprecated protocols, misleading bridges,
-- editor-internal harnesses, and Moonwalk-superseded Lua.
--
---@type table<string, boolean>
local DENIED = {
    ['lldb-vscode'] = true,
    ['lldb-mi'] = true,
    ['local-lua-debugger-vscode'] = true,
    ['mockdebug'] = true,
    ['java-test'] = true,
    ['vscode-java-decompiler'] = true,
    ['pdb'] = true,
    ['jdb'] = true,
    ['phpdbg'] = true,
    ['node-legacy-v8'] = true,
}

---@type table<string, DebugBackend>
local registry = {}
local registry_size = 0

---@param value unknown
---@return boolean
local function nonempty_string(value)
    return type(value) == 'string' and value ~= ''
end

---@param path unknown
---@return boolean
local function executable(path)
    return nonempty_string(path) and fn.executable(path) == 1
end

---@param value unknown
---@return boolean
local function valid_port(value)
    return type(value) == 'number' and value >= 1 and value <= 65535 and value % 1 == 0
end

---@param value unknown
---@return boolean
local function valid_pid(value)
    return type(value) == 'number' and value >= 1 and value % 1 == 0
end

---@param output string?
---@return number? major version, or nil when the output is unparseable
local function parse_major(output)
    if type(output) ~= 'string' then
        return nil
    end

    --
    -- Typical first lines: "GNU gdb (GDB) 15.2", "Dart SDK version: 3.4.0".
    --
    local first = output:match('[^\r\n]*') or ''
    local major = first:match('%(.-GDB.-%) (%d+)%.') or first:match('GDB%s+(%d+)%.') or first:match('(%d+)%.%d+')

    if major == nil then
        return nil
    end

    return tonumber(major)
end

---@param argv string[]
---@return vim.SystemCompleted?
local function system(argv)
    local ok, result = pcall(function()
        return vim.system(argv, {
            text = true,
        }):wait(PROBE_TIMEOUT_MS)
    end)

    if not ok then
        return nil
    end

    return result
end

---@return boolean
local function engine_available()
    if type(vim) ~= 'table' then
        return false
    end

    local ok, mod = pcall(require, 'dap.dap')

    return ok and type(mod) == 'table' and type(mod.session) == 'function'
end

---@param host string
---@param port integer
---@param timeout_ms integer
---@return boolean, string?
local function tcp_reachable(host, port, timeout_ms)
    local ok, sock = pcall(uv.new_tcp)

    if not ok or sock == nil then
        return false, 'cannot create TCP handle'
    end

    local done = false
    local connect_err = nil
    local started = pcall(function()
        sock:connect(host, port, function(err)
            done = true
            connect_err = err
        end)
    end)

    if not started then
        pcall(function()
            sock:close()
        end)

        return false, 'connect call failed'
    end

    vim.wait(timeout_ms, function()
        return done
    end, 50)

    pcall(function()
        sock:close()
    end)

    if not done then
        return false, 'connection timed out'
    end

    if connect_err ~= nil then
        return false, tostring(connect_err)
    end

    return true
end

---@param name string executable name
---@param opts? { env_var: string?, global_key: string?, well_known: string[]? }
---@return string? resolved executable path, nil when not found
function M.discover(name, opts)
    opts = opts or {}

    if not nonempty_string(name) then
        return nil
    end

    --
    -- Discovery order: NVIM_<NAME>_PATH env > vim.g.<name>_path >
    -- fn.exepath > well-known paths.
    --
    if nonempty_string(opts.env_var) then
        local from_env = vim.env[opts.env_var]

        if nonempty_string(from_env) then
            from_env = fn.expand(from_env)

            if executable(from_env) then
                return fs.normalize(from_env)
            end
        end
    end

    if nonempty_string(opts.global_key) then
        local from_g = vim.g[opts.global_key]

        if nonempty_string(from_g) then
            from_g = fn.expand(from_g)

            if executable(from_g) then
                return fs.normalize(from_g)
            end
        end
    end

    local on_path = fn.exepath(name)

    if executable(on_path) then
        return fs.normalize(on_path)
    end

    if type(opts.well_known) == 'table' then
        for _, candidate in ipairs(opts.well_known) do
            local expanded = fn.expand(candidate)

            if executable(expanded) then
                return fs.normalize(expanded)
            end
        end
    end

    return nil
end

---@param names string[]
---@param spec { env_var: string?, global_key: string?, well_known: string[]? }
---@return string?
local function discover_any(names, spec)
    for _, name in ipairs(names) do
        local found = M.discover(name, spec)

        if found ~= nil then
            return found
        end
    end

    return nil
end

---@param backend DebugBackend
---@return boolean?, string? true when the shape is valid, nil+err otherwise
local function validate_backend_shape(backend)
    local id = backend.id
    local languages = backend.languages

    if type(languages) ~= 'table' or #languages == 0 then
        return nil, ('backend %q requires languages to be a non-empty list'):format(id)
    end

    for index, language in ipairs(languages) do
        if not nonempty_string(language) then
            return nil, ('backend %q has an invalid language at position %d'):format(id, index)
        end
    end

    if not nonempty_string(backend.debugger) then
        return nil, ('backend %q requires debugger to be a non-empty string'):format(id)
    end

    if backend.adapter ~= nil and not nonempty_string(backend.adapter) then
        return nil, ('backend %q requires adapter to be nil or a non-empty string'):format(id)
    end

    if not TRANSPORTS[backend.transport] then
        return nil, ('backend %q has an invalid transport %q'):format(id, tostring(backend.transport))
    end

    if not PROTOCOLS[backend.protocol] then
        return nil, ('backend %q has an invalid protocol %q'):format(id, tostring(backend.protocol))
    end

    if type(backend.dap_native) ~= 'boolean' then
        return nil, ('backend %q requires dap_native to be a boolean'):format(id)
    end

    if type(backend.probe) ~= 'function' then
        return nil, ('backend %q requires probe to be a function'):format(id)
    end

    if type(backend.build_config) ~= 'function' then
        return nil, ('backend %q requires build_config to be a function'):format(id)
    end

    return true
end

---@param backend DebugBackend
---@return boolean?, string? true on success, nil+err on rejection
function M.register(backend)
    if type(backend) ~= 'table' then
        return nil, 'register requires a backend table'
    end

    local id = backend.id

    if not nonempty_string(id) then
        return nil, 'register requires backend.id to be a non-empty string'
    end

    if DENIED[id] then
        return nil, ('backend id %q is on the deny list and must never be registered'):format(id)
    end

    if registry[id] ~= nil then
        return nil, ('backend id %q is already registered'):format(id)
    end

    if registry_size >= REGISTRY_MAX then
        return nil, ('backend registry is full (%d entries)'):format(REGISTRY_MAX)
    end

    local ok, err = validate_backend_shape(backend)

    if not ok then
        return nil, err
    end

    registry[id] = backend
    registry_size = registry_size + 1

    return true
end

---@param id string
---@return DebugBackend?
function M.get(id)
    if not nonempty_string(id) then
        return nil
    end

    return registry[id]
end

---@return string[] backend ids, sorted for determinism
function M.list()
    local ids = {}

    for id in pairs(registry) do
        ids[#ids + 1] = id
    end

    table.sort(ids)

    return ids
end

---@param filetype string
---@return DebugBackend[] matching backends, sorted by id
function M.backends_for_filetype(filetype)
    local matches = {}

    if not nonempty_string(filetype) then
        return matches
    end

    for _, id in ipairs(M.list()) do
        local backend = registry[id]

        for _, language in ipairs(backend.languages) do
            if language == filetype then
                matches[#matches + 1] = backend

                break
            end
        end
    end

    return matches
end

---@param transport string
---@return DebugBackend[] matching backends, sorted by id
function M.backends_for_transport(transport)
    local matches = {}

    if not nonempty_string(transport) then
        return matches
    end

    for _, id in ipairs(M.list()) do
        local backend = registry[id]

        if backend.transport == transport then
            matches[#matches + 1] = backend
        end
    end

    return matches
end

---@param opts { command: string, args?: string[], options?: table }
---@return table?, string? nvim-dap executable adapter
function M.stdio_adapter(opts)
    if type(opts) ~= 'table' then
        return nil, 'stdio_adapter requires an options table'
    end

    if not nonempty_string(opts.command) then
        return nil, 'stdio_adapter requires opts.command to be a non-empty string'
    end

    local args = opts.args or {}

    if type(args) ~= 'table' then
        return nil, 'stdio_adapter requires opts.args to be a list of strings'
    end

    local adapter = {
        type = 'executable',
        command = opts.command,
        args = args,
    }

    if opts.options ~= nil then
        if type(opts.options) ~= 'table' then
            return nil, 'stdio_adapter requires opts.options to be a table'
        end

        adapter.options = opts.options
    end

    return adapter
end

---@param opts { command?: string, args?: string[], host?: string, port: integer }
---@return table?, string? nvim-dap server adapter
function M.tcp_adapter(opts)
    if type(opts) ~= 'table' then
        return nil, 'tcp_adapter requires an options table'
    end

    if not valid_port(opts.port) then
        return nil, 'tcp_adapter requires opts.port to be an integer in 1-65535'
    end

    local host = opts.host or LOOPBACK

    if not nonempty_string(host) then
        return nil, 'tcp_adapter requires opts.host to be a non-empty string'
    end

    local adapter = {
        type = 'server',
        host = host,
        port = math.floor(opts.port),
    }

    --
    -- command is optional: some servers (e.g. the Godot editor) are started
    -- externally and only connected to, never spawned by the client.
    --
    if opts.command ~= nil then
        if not nonempty_string(opts.command) then
            return nil, 'tcp_adapter requires opts.command to be a non-empty string'
        end

        local args = opts.args or {}

        if type(args) ~= 'table' then
            return nil, 'tcp_adapter requires opts.args to be a list of strings'
        end

        adapter.executable = {
            command = opts.command,
            args = args,
        }
    end

    return adapter
end

---@param id string
---@param backend DebugBackend
---@param ctx table
---@return boolean?, string? true when the context is valid, nil+err otherwise
local function validate_build_ctx(id, backend, ctx)
    local mode = ctx.mode

    if mode ~= 'launch' and mode ~= 'attach' then
        return nil, 'build_config requires ctx.mode to be "launch" or "attach"'
    end

    if ctx.args ~= nil and type(ctx.args) ~= 'table' then
        return nil, 'build_config requires ctx.args to be a list of strings'
    end

    if ctx.cwd ~= nil and not nonempty_string(ctx.cwd) then
        return nil, 'build_config requires ctx.cwd to be a non-empty string'
    end

    if ctx.program ~= nil and not nonempty_string(ctx.program) then
        return nil, 'build_config requires ctx.program to be a non-empty string'
    end

    if ctx.host ~= nil and not nonempty_string(ctx.host) then
        return nil, 'build_config requires ctx.host to be a non-empty string'
    end

    if ctx.port ~= nil and not valid_port(ctx.port) then
        return nil, 'build_config requires ctx.port to be an integer in 1-65535'
    end

    if ctx.pid ~= nil and not valid_pid(ctx.pid) then
        return nil, 'build_config requires ctx.pid to be a positive integer'
    end

    local transport = backend.transport
    local spawned = transport == 'stdio' or transport == 'pipe' or transport == 'unix'

    if mode == 'launch' then
        if spawned and not nonempty_string(ctx.program) then
            return nil, ('build_config: launch via %q requires ctx.program'):format(id)
        end

        if transport == 'tcp' and not valid_port(ctx.port) then
            return nil, ('build_config: launch via tcp backend %q requires ctx.port'):format(id)
        end
    else
        local has_pid = valid_pid(ctx.pid)
        local has_target = nonempty_string(ctx.host) and valid_port(ctx.port)

        if not has_pid and not has_target then
            return nil, ('build_config: attach via %q requires ctx.pid or ctx.host+ctx.port'):format(id)
        end

        if transport == 'tcp' and not has_target then
            return nil, ('build_config: attach via tcp backend %q requires ctx.host and ctx.port'):format(id)
        end
    end

    return true
end

---@param id string
---@param ctx table
---@return table generic launch/attach configuration
local function assemble_build_config(id, ctx)
    --
    -- Generic shape only: no adapter-specific quirks (those stay in the
    -- per-language modules that own each backend's detail).
    --
    local config = {
        name = ctx.name or ('%s: %s'):format(id, ctx.mode),
        type = id,
        request = ctx.mode,
    }

    if ctx.program ~= nil then
        config.program = ctx.program
    end

    if ctx.args ~= nil then
        config.args = ctx.args
    end

    if ctx.cwd ~= nil then
        config.cwd = ctx.cwd
    end

    if ctx.host ~= nil then
        config.host = ctx.host
    end

    if ctx.port ~= nil then
        config.port = math.floor(ctx.port)
    end

    if ctx.pid ~= nil then
        config.pid = math.floor(ctx.pid)
    end

    return config
end

---@param ctx { backend_id: string, mode: 'launch'|'attach', name?: string, program?: string, args?: string[], cwd?: string, host?: string, port?: integer, pid?: integer }
---@return table?, string? generic launch/attach configuration
function M.build_config(ctx)
    if type(ctx) ~= 'table' then
        return nil, 'build_config requires a context table'
    end

    local id = ctx.backend_id

    if not nonempty_string(id) then
        return nil, 'build_config requires ctx.backend_id to be a non-empty string'
    end

    local backend = registry[id]

    if backend == nil then
        return nil, ('build_config: unknown backend id %q'):format(id)
    end

    local ok, err = validate_build_ctx(id, backend, ctx)

    if not ok then
        return nil, err
    end

    return assemble_build_config(id, ctx)
end

---@return table<string, ProbeResult> per-backend probe summary (pure data, no notifications)
function M.check_all()
    local summary = {}

    for _, id in ipairs(M.list()) do
        local backend = registry[id]
        local ok, result = pcall(backend.probe)

        if ok and type(result) == 'table' then
            summary[id] = result
        else
            summary[id] = {
                ok = false,
                stage = 'neovim',
                message = ('probe error: %s'):format(tostring(result)),
            }
        end
    end

    return summary
end

---@param stage ProbeStage
---@param message string
---@return ProbeResult
local function probe_fail(stage, message)
    return { ok = false, stage = stage, message = message }
end

---@class ProbeState
---@field deepest string furthest chain stage verified so far
---@field path string? resolved adapter executable, nil when skipped

---@param spec BackendProbeSpec
---@param state ProbeState
---@return ProbeResult? failure, nil when the stage passed
local function stage_adapter(spec, state)
    if spec.skip_adapter then
        return nil
    end

    local path = discover_any(spec.binaries, spec)

    if path == nil then
        return probe_fail(
            'adapter',
            ('adapter executable not found (tried: %s)'):format(table.concat(spec.binaries, ', '))
        )
    end

    state.path = path
    state.deepest = 'adapter'

    return nil
end

---@param spec BackendProbeSpec
---@param state ProbeState
---@return ProbeResult? failure, nil when the stage passed
local function stage_debugger(spec, state)
    if spec.debugger_binaries == nil then
        return nil
    end

    local debugger_path = discover_any(spec.debugger_binaries, spec)

    if debugger_path == nil then
        return probe_fail(
            'debugger',
            ('debugger executable not found (tried: %s)'):format(table.concat(spec.debugger_binaries, ', '))
        )
    end

    state.deepest = 'debugger'

    return nil
end

---@param spec BackendProbeSpec
---@param state ProbeState
---@return ProbeResult? failure, nil when the stage passed
local function stage_version(spec, state)
    if spec.version == nil or state.path == nil then
        return nil
    end

    local result = system({ state.path, table.unpack(spec.version.argv) })
    local major = parse_major(result ~= nil and result.stdout or nil)

    if major == nil then
        return probe_fail('debugger', ('could not determine version of %s'):format(state.path))
    end

    if major < spec.version.min_major then
        return probe_fail(
            'debugger',
            ('%s is too old for DAP (need major >= %d, have %d)'):format(state.path, spec.version.min_major, major)
        )
    end

    state.deepest = 'debugger'

    return nil
end

---@param spec BackendProbeSpec
---@param state ProbeState
---@return ProbeResult? failure, nil when the stage passed
local function stage_validate(spec, state)
    if spec.validate == nil then
        return nil
    end

    local valid, message = spec.validate(state.path, system)

    if not valid then
        return probe_fail(spec.validate_stage or 'debugger', message or 'validation failed')
    end

    if spec.validate_stage ~= nil then
        state.deepest = spec.validate_stage
    end

    return nil
end

---@param spec BackendProbeSpec
---@param state ProbeState
---@return ProbeResult? failure, nil when the stage passed
local function stage_target(spec, state)
    if spec.tcp == nil then
        return nil
    end

    local reachable, why = tcp_reachable(spec.tcp.host, spec.tcp.port, PROBE_TCP_TIMEOUT_MS)

    if not reachable then
        return probe_fail('target', ('target unreachable at %s:%d (%s)'):format(spec.tcp.host, spec.tcp.port, why))
    end

    state.deepest = 'target'

    return nil
end

---@type (fun(spec: BackendProbeSpec, state: ProbeState): ProbeResult?)[]
local PROBE_STAGES = {
    stage_adapter,
    stage_debugger,
    stage_version,
    stage_validate,
    stage_target,
}

---@param spec BackendProbeSpec
---@return ProbeResult
local function run_probe(spec)
    if not engine_available() then
        return probe_fail('neovim', 'DAP engine (dap.dap) is unavailable')
    end

    --
    -- deepest records the furthest stage verified, so a passing probe still
    -- says how much of the chain was actually checked.
    --
    ---@type ProbeState
    local state = { deepest = 'neovim', path = nil }

    for _, stage in ipairs(PROBE_STAGES) do
        local failure = stage(spec, state)

        if failure ~= nil then
            return failure
        end
    end

    return { ok = true, stage = state.deepest, message = 'probe passed' }
end

---@param spec BackendProbeSpec
---@return fun(): ProbeResult a probe that never throws
local function make_probe(spec)
    return function()
        local ok, result = pcall(run_probe, spec)

        if ok and type(result) == 'table' then
            return result
        end

        return { ok = false, stage = 'neovim', message = ('probe error: %s'):format(tostring(result)) }
    end
end

---@param id string
---@return fun(ctx: table?): table?, string?
local function seed_builder(id)
    return function(ctx)
        local copy = {}

        if type(ctx) == 'table' then
            for key, value in pairs(ctx) do
                copy[key] = value
            end
        end

        copy.backend_id = id

        return M.build_config(copy)
    end
end

---@param binary string
---@return string[]
local function mason_bin(binary)
    return { MASON_BIN .. binary }
end

--
-- The report's actionable executable set, as data. Probes check executables
-- only; adapter-specific launch quirks stay in the per-language modules.
--
---@type DebugBackend[]
local SEEDS = {
    {
        id = 'gdb',
        languages = { 'c', 'cpp', 'objc', 'objcpp', 'asm', 'rust', 'fortran', 'd' },
        debugger = 'GDB',
        adapter = nil,
        transport = 'stdio',
        protocol = 'dap',
        dap_native = true,
        probe = make_probe({
            binaries = { 'gdb' },
            env_var = 'NVIM_GDB_PATH',
            global_key = 'gdb_path',
            well_known = { '/usr/bin/gdb', '/opt/homebrew/bin/gdb', '/usr/local/bin/gdb' },
            version = { argv = { '--version' }, min_major = 14 },
        }),
        build_config = seed_builder('gdb'),
    },
    {
        id = 'lldb-dap',
        languages = { 'c', 'cpp', 'objc', 'objcpp', 'swift', 'rust', 'zig' },
        debugger = 'LLDB',
        adapter = 'lldb-dap',
        transport = 'stdio',
        protocol = 'dap',
        dap_native = false,
        probe = make_probe({
            binaries = { 'lldb-dap' },
            env_var = 'NVIM_LLDB_DAP_PATH',
            global_key = 'lldb_dap_path',
            well_known = {
                '/usr/bin/lldb-dap',
                '/usr/lib/llvm/bin/lldb-dap',
                '/opt/homebrew/opt/llvm/bin/lldb-dap',
            },
        }),
        build_config = seed_builder('lldb-dap'),
    },
    {
        id = 'codelldb',
        languages = { 'c', 'cpp', 'rust', 'zig' },
        debugger = 'LLDB',
        adapter = 'codelldb',
        transport = 'stdio',
        protocol = 'dap',
        dap_native = false,
        probe = make_probe({
            binaries = { 'codelldb' },
            env_var = 'NVIM_CODELLDB_PATH',
            global_key = 'codelldb_path',
            well_known = mason_bin('codelldb'),
        }),
        build_config = seed_builder('codelldb'),
    },
    {
        id = 'debugpy',
        languages = { 'python' },
        debugger = 'CPython (debugpy)',
        adapter = 'debugpy',
        transport = 'stdio',
        protocol = 'dap',
        dap_native = true,
        probe = make_probe({
            binaries = { 'python3', 'python' },
            env_var = 'NVIM_DEBUGPY_PYTHON',
            global_key = 'debugpy_python',
            validate = function(path, run)
                local result = run({ path, '-c', 'import debugpy' })

                if result ~= nil and result.code == 0 then
                    return true
                end

                return false, ('debugpy is not importable by %s'):format(tostring(path))
            end,
            validate_stage = 'adapter',
        }),
        build_config = seed_builder('debugpy'),
    },
    {
        id = 'dlv',
        languages = { 'go' },
        debugger = 'Delve',
        adapter = nil,
        transport = 'tcp',
        protocol = 'dap',
        dap_native = true,
        probe = make_probe({
            binaries = { 'dlv' },
            env_var = 'NVIM_DLV_PATH',
            global_key = 'dlv_path',
            -- `dlv dap` binds 127.0.0.1:0 by default: no stable target to
            -- reachability-check, so the probe stops at the adapter stage.
        }),
        build_config = seed_builder('dlv'),
    },
    {
        id = 'js-debug',
        languages = { 'javascript', 'typescript', 'javascriptreact', 'typescriptreact' },
        debugger = 'V8 Inspector/CDP',
        adapter = 'js-debug-adapter',
        transport = 'stdio',
        protocol = 'cdp',
        dap_native = false,
        probe = make_probe({
            binaries = { 'js-debug-adapter' },
            env_var = 'NVIM_JS_DEBUG_ADAPTER_PATH',
            global_key = 'js_debug_adapter_path',
            well_known = mason_bin('js-debug-adapter'),
        }),
        build_config = seed_builder('js-debug'),
    },
    {
        id = 'java-debug',
        languages = { 'java' },
        debugger = 'JVM/JDWP',
        adapter = 'java-debug-adapter',
        transport = 'stdio',
        protocol = 'jdwp',
        dap_native = false,
        probe = make_probe({
            binaries = { 'java-debug-adapter' },
            env_var = 'NVIM_JAVA_DEBUG_ADAPTER_PATH',
            global_key = 'java_debug_adapter_path',
            well_known = mason_bin('java-debug-adapter'),
        }),
        build_config = seed_builder('java-debug'),
    },
    {
        id = 'kotlin-debug-adapter',
        languages = { 'kotlin' },
        debugger = 'JVM/JDWP',
        adapter = 'kotlin-debug-adapter',
        transport = 'stdio',
        protocol = 'jdwp',
        dap_native = false,
        probe = make_probe({
            binaries = { 'kotlin-debug-adapter' },
            env_var = 'NVIM_KOTLIN_DEBUG_ADAPTER_PATH',
            global_key = 'kotlin_debug_adapter_path',
            well_known = mason_bin('kotlin-debug-adapter'),
        }),
        build_config = seed_builder('kotlin-debug-adapter'),
    },
    {
        id = 'netcoredbg',
        languages = { 'cs', 'fsharp', 'vb' },
        debugger = '.NET CLR',
        adapter = 'netcoredbg',
        transport = 'stdio',
        protocol = 'dap',
        dap_native = false,
        probe = make_probe({
            binaries = { 'netcoredbg' },
            env_var = 'NVIM_NETCOREDBG_PATH',
            global_key = 'netcoredbg_path',
            well_known = mason_bin('netcoredbg'),
        }),
        build_config = seed_builder('netcoredbg'),
    },
    {
        id = 'rdbg',
        languages = { 'ruby' },
        debugger = 'Ruby (debug gem)',
        adapter = 'rdbg',
        transport = 'unix',
        protocol = 'dap',
        dap_native = true,
        probe = make_probe({
            binaries = { 'rdbg' },
            env_var = 'NVIM_RDBG_PATH',
            global_key = 'rdbg_path',
        }),
        build_config = seed_builder('rdbg'),
        -- Upstream rdbg speaks DAP over a unix-domain socket by default
        -- (`rdbg --command --open --sock-path <path> -- <target...>`); the
        -- loopback-TCP form (`--host <host> --port <port>`) is the fallback
        -- when a debug port is selected or the platform requires it. Never
        -- raw stdio: rdbg has no stdio DAP mode.
    },
    {
        id = 'php-debug',
        languages = { 'php' },
        debugger = 'Xdebug',
        adapter = 'php-debug-adapter',
        transport = 'stdio',
        protocol = 'dbgp',
        dap_native = false,
        probe = make_probe({
            binaries = { 'php-debug-adapter' },
            env_var = 'NVIM_PHP_DEBUG_ADAPTER_PATH',
            global_key = 'php_debug_adapter_path',
            well_known = mason_bin('php-debug-adapter'),
            validate = function(_path, run)
                local result = run({ 'php', '-m' })
                local output = result ~= nil and result.stdout or ''

                if type(output) == 'string' and output:lower():find('xdebug', 1, true) ~= nil then
                    return true
                end

                return false, 'Xdebug is not loaded for php (php -m shows no xdebug module)'
            end,
            validate_stage = 'debugger',
        }),
        build_config = seed_builder('php-debug'),
    },
    {
        id = 'probe-rs',
        languages = { 'rust', 'c', 'cpp' },
        debugger = 'probe-rs',
        adapter = nil,
        transport = 'tcp',
        protocol = 'dap',
        dap_native = true,
        probe = make_probe({
            binaries = { 'probe-rs' },
            env_var = 'NVIM_PROBE_RS_PATH',
            global_key = 'probe_rs_path',
            -- `probe-rs dap-server` needs an explicit --port: no stable
            -- target to reachability-check, so the probe stops at the
            -- adapter stage.
        }),
        build_config = seed_builder('probe-rs'),
    },
    {
        id = 'cortex-debug',
        languages = { 'c', 'cpp', 'rust' },
        debugger = 'GDB/OpenOCD stack',
        adapter = 'cortex-debug',
        transport = 'stdio',
        protocol = 'dap',
        dap_native = false,
        probe = make_probe({
            binaries = { 'cortex-debug' },
            env_var = 'NVIM_CORTEX_DEBUG_PATH',
            global_key = 'cortex_debug_path',
            -- Best-effort entry: the embedded worker owns the OpenOCD /
            -- J-Link / pyOCD / ST-Link detail.
        }),
        build_config = seed_builder('cortex-debug'),
    },
    {
        id = 'bash-debug-adapter',
        languages = { 'sh', 'bash' },
        debugger = 'bashdb',
        adapter = 'bash-debug-adapter',
        transport = 'stdio',
        protocol = 'dap',
        dap_native = false,
        probe = make_probe({
            binaries = { 'bash-debug-adapter' },
            env_var = 'NVIM_BASH_DEBUG_ADAPTER_PATH',
            global_key = 'bash_debug_adapter_path',
            well_known = mason_bin('bash-debug-adapter'),
        }),
        build_config = seed_builder('bash-debug-adapter'),
    },
    {
        id = 'perl-debug-adapter',
        languages = { 'perl' },
        debugger = 'Perl (perl5db)',
        adapter = 'perl-debug-adapter',
        transport = 'stdio',
        protocol = 'dap',
        dap_native = false,
        probe = make_probe({
            binaries = { 'perl-debug-adapter' },
            env_var = 'NVIM_PERL_DEBUG_ADAPTER_PATH',
            global_key = 'perl_debug_adapter_path',
            well_known = mason_bin('perl-debug-adapter'),
            -- Best-effort entry: mason package presence not re-verified in
            -- this pass; the probe reports adapter-missing honestly.
        }),
        build_config = seed_builder('perl-debug-adapter'),
    },
    {
        id = 'dart',
        languages = { 'dart' },
        debugger = 'Dart VM',
        adapter = nil,
        transport = 'stdio',
        protocol = 'dap',
        dap_native = true,
        probe = make_probe({
            binaries = { 'dart', 'flutter' },
            env_var = 'NVIM_DART_PATH',
            global_key = 'dart_path',
            validate = function(path, run)
                local result = run({ path, '--version' })

                if result ~= nil and result.code == 0 then
                    return true
                end

                return false, ('Dart SDK did not run: %s'):format(tostring(path))
            end,
            validate_stage = 'debugger',
        }),
        build_config = seed_builder('dart'),
    },
    {
        id = 'elixir-ls-debugger',
        languages = { 'elixir' },
        debugger = 'ElixirLS',
        adapter = 'elixir-ls-debugger',
        transport = 'stdio',
        protocol = 'dap',
        dap_native = false,
        probe = make_probe({
            binaries = { 'elixir-ls-debugger' },
            env_var = 'NVIM_ELIXIR_LS_DEBUGGER_PATH',
            global_key = 'elixir_ls_debugger_path',
            well_known = mason_bin('elixir-ls-debugger'),
        }),
        build_config = seed_builder('elixir-ls-debugger'),
    },
    {
        id = 'edb',
        languages = { 'erlang', 'elixir' },
        debugger = 'EDB (WhatsApp)',
        adapter = 'edb',
        transport = 'stdio',
        protocol = 'dap',
        dap_native = false,
        probe = make_probe({
            binaries = { 'edb' },
            env_var = 'NVIM_EDB_PATH',
            global_key = 'edb_path',
            -- Best-effort entry: the Elixir/EDB worker owns the detail.
        }),
        build_config = seed_builder('edb'),
    },
    {
        id = 'ocamlearlybird',
        languages = { 'ocaml' },
        debugger = 'OCaml bytecode',
        adapter = 'ocamlearlybird',
        transport = 'stdio',
        protocol = 'dap',
        dap_native = false,
        probe = make_probe({
            binaries = { 'ocamlearlybird' },
            env_var = 'NVIM_OCAMLEARLYBIRD_PATH',
            global_key = 'ocamlearlybird_path',
            well_known = mason_bin('ocamlearlybird'),
        }),
        build_config = seed_builder('ocamlearlybird'),
    },
    {
        id = 'r-debugger',
        languages = { 'r' },
        debugger = 'R',
        adapter = 'vscDebugger',
        transport = 'stdio',
        protocol = 'dap',
        dap_native = false,
        probe = make_probe({
            binaries = { 'Rscript', 'R' },
            env_var = 'NVIM_RSCRIPT_PATH',
            global_key = 'rscript_path',
            validate = function(path, run)
                local result = run({ path, '-e', "cat(requireNamespace('vscDebugger', quietly=TRUE))" })
                local output = result ~= nil and result.stdout or ''

                if type(output) == 'string' and output:find('TRUE', 1, true) ~= nil then
                    return true
                end

                return false, 'vscDebugger R package is not installed'
            end,
            validate_stage = 'adapter',
        }),
        build_config = seed_builder('r-debugger'),
    },
    {
        id = 'godot',
        languages = { 'gdscript' },
        debugger = 'Godot editor',
        adapter = nil,
        transport = 'tcp',
        protocol = 'dap',
        dap_native = true,
        probe = make_probe({
            binaries = {},
            skip_adapter = true,
            debugger_binaries = { 'godot' },
            -- Godot's built-in DAP server listens on 6006 by default
            -- (Editor Settings > Network > Debug Adapter).
            tcp = { host = '127.0.0.1', port = 6006 },
        }),
        build_config = seed_builder('godot'),
    },
    {
        id = 'firefox-debug-adapter',
        languages = { 'javascript', 'typescript' },
        debugger = 'Firefox',
        adapter = 'firefox-debug-adapter',
        transport = 'stdio',
        protocol = 'dap',
        dap_native = false,
        probe = make_probe({
            binaries = { 'firefox-debug-adapter' },
            env_var = 'NVIM_FIREFOX_DEBUG_ADAPTER_PATH',
            global_key = 'firefox_debug_adapter_path',
            well_known = mason_bin('firefox-debug-adapter'),
        }),
        build_config = seed_builder('firefox-debug-adapter'),
    },
    {
        id = 'powershell-editor-services',
        languages = { 'ps1', 'powershell' },
        debugger = 'PowerShell',
        adapter = 'powershell-editor-services',
        transport = 'pipe',
        protocol = 'dap',
        dap_native = false,
        probe = make_probe({
            binaries = { 'pwsh', 'powershell' },
            env_var = 'NVIM_PWSH_PATH',
            global_key = 'pwsh_path',
            -- Best-effort entry: verifies the PowerShell host only; the
            -- PSES bundle / session-file detail is owned by the language
            -- worker.
        }),
        build_config = seed_builder('powershell-editor-services'),
    },
}

for _, seed in ipairs(SEEDS) do
    local ok, err = M.register(seed)

    assert(ok, ('seed backend %q failed to register: %s'):format(tostring(seed.id), tostring(err)))
end

return M
