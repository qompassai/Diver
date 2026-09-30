-- #################################################################
-- ~/.config/nvim/lua/dap/ruby.lua
-- Qompass AI Diver Native Ruby Debug Adapter Configuration
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
---@source https://github.com/ruby/debug
---@source https://github.com/ruby/debug/blob/master/lib/debug/server_dap.rb
---@source https://github.com/ruby/vscode-rdbg/blob/master/src/extension.ts

--- Ruby debugging via rdbg's socket Debug Adapter Protocol.
---
--- Plain-language version: Ruby's `debug` gem (`rdbg`) speaks the Debug
--- Adapter Protocol, but only over a socket, never stdio. When you start a
--- debug session, this module launches `rdbg` itself -- exactly like the
--- upstream VS Code extension does -- in listening mode on a unix-domain
--- socket by default (loopback TCP when you select a debug port or on
--- Windows, which has no unix sockets), waits for the socket to appear, and
--- hands the connected socket to the DAP client. There is no manual
--- "start the server first" step. To attach, start the target yourself with
--- `rdbg --open` (short: `rdbg -O`), `ruby -r debug/open`, or
--- `RUBY_DEBUG_OPEN=true`, then use the attach configuration.
---
--- Upstream notes this module follows:
--- * rdbg is launched as `rdbg --command --open --stop-at-load
---   (--sock-path <path> | --host <host> --port <port>) -- <target...>`.
--- * `launch` hardcodes nonstop: the debug gem's DAP server sets
---   `@nonstop = true` on `launch` (so it continues after configuration),
---   while `attach` honors the request's own `nonstop` field.
--- * `rdbg --util=gen-sockpath`, `--util=gen-portpath` (debug.gem >= 1.7.2
---   for the port file), and `--util=list-socks` provide the socket paths.
---@module 'dap.ruby'

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local uv = vim.uv
local levels = vim.log.levels

local M = {}

local SOURCE = 'ruby'
local TCP_HOST_DEFAULT = 'localhost'

local ROOT_MARKERS = {
    'Gemfile',
    'Rakefile',
    'config.ru',
    '.git',
}

-- Bounds: all waits and captured output are capped so a wedged rdbg can
-- never hang session startup forever.
local SOCK_WAIT_MS = 10000
local PORT_WAIT_MS = 10000
local READY_WAIT_MS = 10000
local STDERR_MAX_BYTES = 65536
local STDERR_TAIL_BYTES = 2048
local LIST_SOCKS_MAX = 64

-- rdbg prints this on stderr once it is listening for the DAP client.
local READY_MARKER = 'wait for debugger connection'

---@class RdbgPortTarget
---@field mode 'tcp'|'unix'
---@field host string? loopback host for mode 'tcp'
---@field port integer? 0 means ephemeral (port-file rendezvous), for mode 'tcp'
---@field sock_path string? for mode 'unix'

---@class RdbgLaunchPlan
---@field argv string[] full rdbg command line to spawn
---@field mode 'tcp'|'unix'
---@field sock_path string? unix socket rdbg will listen on
---@field host string? loopback host for mode 'tcp'
---@field port integer? explicit port for mode 'tcp'
---@field port_path string? file rdbg writes the ephemeral port to

---@class RdbgDescriptor
---@field mode 'tcp'|'unix'
---@field sock_path string? for mode 'unix'
---@field host string? for mode 'tcp'
---@field port integer? for mode 'tcp'

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

---@type string?
local state_rdbg = nil

---@return string?
local function find_rdbg()
    if state_rdbg ~= nil then
        return state_rdbg
    end

    local configured = vim.env.NVIM_RDBG_PATH

    if executable(configured or '') then
        state_rdbg = normalize(fn.expand(configured))

        return state_rdbg
    end

    local on_path = fn.exepath('rdbg')

    if nonempty_string(on_path) then
        state_rdbg = fs.normalize(on_path)

        return state_rdbg
    end

    return nil
end

---@param configuration table
---@return string?, string?
local function resolve_rdbg(configuration)
    local override = configuration.rdbg_path

    if override ~= nil then
        if not nonempty_string(override) then
            return nil, 'rdbg_path must be a non-empty string'
        end

        local expanded = normalize(fn.expand(override))

        if not executable(expanded) then
            return nil, ('rdbg_path is not executable: %s'):format(override)
        end

        return expanded
    end

    local found = find_rdbg()

    if found == nil then
        return nil, 'rdbg was not found (gem install debug)'
    end

    return found
end

---@param root string
---@return boolean
local function uses_bundler(root)
    return root ~= '' and fn.filereadable(root .. '/Gemfile') == 1
end

--- Split a command line the way a shell would (quotes, backslash escapes),
--- so `bundle exec rspec` becomes three argv elements and quoted arguments
--- survive as single elements. No shell is ever invoked.
---@param raw string
---@return string[]?, string?
function M.parse_args(raw)
    if type(raw) ~= 'string' then
        return nil, 'parse_args requires a string'
    end

    local args = {}
    local current = {}
    local quote = nil
    local escaped = false
    local started = false

    local function finish()
        if started then
            args[#args + 1] = table.concat(current)
            current = {}
            started = false
        end
    end

    for index = 1, #raw do
        local character = raw:sub(index, index)

        if escaped then
            current[#current + 1] = character
            escaped = false
        elseif quote ~= nil then
            if character == quote then
                quote = nil
            else
                current[#current + 1] = character
            end

            started = true
        elseif character == '\\' then
            escaped = true
            started = true
        elseif character == "'" or character == '"' then
            quote = character
            started = true
        elseif character:match('%s') then
            finish()
        else
            current[#current + 1] = character
            started = true
        end
    end

    if escaped then
        return nil, 'arguments end with an incomplete escape'
    end

    if quote ~= nil then
        return nil, 'arguments contain an unterminated quote'
    end

    finish()

    return args
end

--- Parse an upstream-style `debug_port` value: digits mean loopback TCP on
--- that port, `host:port` means TCP there, anything else names a
--- unix-domain socket path. Port 0 means "ephemeral" (rdbg picks a free
--- port and reports it through a port file; needs debug.gem >= 1.7.2).
---@param value unknown
---@return RdbgPortTarget?, string?
function M.parse_debug_port(value)
    if not nonempty_string(value) then
        return nil, 'debug_port must be a non-empty string'
    end

    local function check_port(port)
        if port < 0 or port > 65535 then
            return nil, ('debug_port port out of range: %s'):format(value)
        end

        return port
    end

    local digits = value:match('^%d+$')

    if digits ~= nil then
        local port, err = check_port(tonumber(digits))

        if port == nil then
            return nil, err
        end

        return { mode = 'tcp', host = TCP_HOST_DEFAULT, port = port }
    end

    local host, port_text = value:match('^(.+):(%d+)$')

    if host ~= nil then
        local port, err = check_port(tonumber(port_text))

        if port == nil then
            return nil, err
        end

        return { mode = 'tcp', host = host, port = port }
    end

    return { mode = 'unix', sock_path = value }
end

--- Build the debuggee target argv: `<ruby> <script> <args...>`.
--- `config.command` (e.g. `rspec`, or `bundle exec rspec`) wins when given;
--- otherwise the ruby command is `bundle exec ruby` when a Gemfile is
--- present (unless `config.use_bundler == false`), plain `ruby` otherwise.
--- `config.script` names the target file; `config.program` is accepted as
--- a fallback for nvim-dap-style configurations.
---@param config table expanded launch configuration
---@param root string project root for Gemfile detection
---@return string[]?, string?
function M.target_argv(config, root)
    if type(config) ~= 'table' then
        return nil, 'target_argv requires a configuration table'
    end

    if not nonempty_string(root) then
        return nil, 'target_argv requires a non-empty root'
    end

    local argv
    local command = config.command

    if command ~= nil then
        if not nonempty_string(command) then
            return nil, 'target_argv requires config.command to be a non-empty string'
        end

        local parsed, err = M.parse_args(command)

        if parsed == nil then
            return nil, err
        end

        argv = parsed
    elseif config.use_bundler ~= false and uses_bundler(root) then
        argv = { 'bundle', 'exec', 'ruby' }
    else
        argv = { 'ruby' }
    end

    local script = config.script or config.program

    if not nonempty_string(script) then
        return nil, 'target_argv requires config.script (or config.program)'
    end

    argv[#argv + 1] = script

    local args = config.args

    if args ~= nil then
        if type(args) ~= 'table' then
            return nil, 'target_argv requires config.args to be a list of strings'
        end

        for index, arg in ipairs(args) do
            if type(arg) ~= 'string' then
                return nil, ('target_argv requires config.args[%d] to be a string'):format(index)
            end

            argv[#argv + 1] = arg
        end
    end

    return argv
end

--- Run `rdbg --util=<name>` synchronously and return its trimmed stdout.
---@param rdbg string
---@param util string
---@return string?, string?
local function rdbg_util(rdbg, util)
    local result = vim.system({ rdbg, '--util=' .. util }, { text = true }):wait()

    if result.code ~= 0 then
        return nil, (('rdbg --util=%s failed: %s'):format(util, result.stderr or '')):gsub('%s+$', '')
    end

    local out = (result.stdout or ''):match('^%s*(.-)%s*$')

    if out == '' then
        return nil, ('rdbg --util=%s printed nothing'):format(util)
    end

    return out
end

---@param rdbg string
---@return string?, string?
local function gen_sock_path(rdbg)
    return rdbg_util(rdbg, 'gen-sockpath')
end

---@param rdbg string
---@return string?, string?
local function gen_port_path(rdbg)
    return rdbg_util(rdbg, 'gen-portpath')
end

--- List unix sockets of Ruby processes started with `rdbg --open`.
---@param rdbg string
---@param cwd string
---@return string[]?, string?
local function list_socks(rdbg, cwd)
    local result = vim.system({ rdbg, '--util=list-socks' }, { text = true, cwd = cwd }):wait()

    if result.code ~= 0 then
        return nil, (('rdbg --util=list-socks failed: %s'):format(result.stderr or '')):gsub('%s+$', '')
    end

    local socks = {}

    for line in (result.stdout or ''):gmatch('[^\n]+') do
        if #socks >= LIST_SOCKS_MAX then
            break
        end

        local trimmed = line:match('^%s*(.-)%s*$')

        if trimmed ~= '' then
            socks[#socks + 1] = trimmed
        end
    end

    return socks
end

--- Build the full rdbg command line for a launch, upstream-style:
--- `rdbg --command --open --stop-at-load (--sock-path <p> | --host <h>
--- --port <port>) -- <target...>`. Unix socket by default; loopback TCP
--- when `debug_port` selects it or on Windows (no unix sockets there).
---@param rdbg string path to the rdbg executable
---@param config table expanded launch configuration
---@param root string project root
---@return RdbgLaunchPlan?, string?
function M.launch_plan(rdbg, config, root)
    if not executable(rdbg) then
        return nil, 'launch_plan requires an executable rdbg path'
    end

    if type(config) ~= 'table' then
        return nil, 'launch_plan requires a configuration table'
    end

    if not nonempty_string(root) then
        return nil, 'launch_plan requires a non-empty root'
    end

    local target, err = M.target_argv(config, root)

    if target == nil then
        return nil, err
    end

    local on_windows = fn.has('win32') == 1
    local mode = 'unix'
    local sock_path, host, port, port_path

    local debug_port = config.debug_port

    if debug_port ~= nil then
        local parsed, perr = M.parse_debug_port(debug_port)

        if parsed == nil then
            return nil, perr
        end

        if parsed.mode == 'tcp' then
            mode = 'tcp'
            host = parsed.host
            port = parsed.port
        elseif on_windows then
            return nil, 'debug_port names a unix socket, which Windows cannot use'
        else
            sock_path = parsed.sock_path
        end

        if port == 0 then
            port_path, err = gen_port_path(rdbg)

            if port_path == nil then
                return nil, err
            end
        end
    elseif on_windows then
        -- No unix-domain sockets on Windows: loopback TCP with an ephemeral
        -- port, reported back through a port file (debug.gem >= 1.7.2).
        mode = 'tcp'
        host = TCP_HOST_DEFAULT
        port = 0
        port_path, err = gen_port_path(rdbg)

        if port_path == nil then
            return nil, err
        end
    else
        sock_path, err = gen_sock_path(rdbg)

        if sock_path == nil then
            return nil, err
        end
    end

    local argv = { rdbg, '--command', '--open', '--stop-at-load' }

    if mode == 'unix' then
        argv[#argv + 1] = '--sock-path=' .. sock_path
    else
        argv[#argv + 1] = '--host=' .. host

        local port_arg = tostring(port)

        if port_path ~= nil then
            port_arg = port_arg .. ':' .. port_path
        end

        argv[#argv + 1] = '--port=' .. port_arg
    end

    argv[#argv + 1] = '--'

    for _, word in ipairs(target) do
        argv[#argv + 1] = word
    end

    return {
        argv = argv,
        mode = mode,
        sock_path = sock_path,
        host = host,
        port = port,
        port_path = port_path,
    }
end

---@param path string
---@return integer?
local function read_port_file(path)
    local file = io.open(path, 'r')

    if file == nil then
        return nil
    end

    local line = file:read('*l')
    file:close()

    local port = tonumber(line and line:match('%d+') or '')

    if port ~= nil and port >= 1 and port <= 65535 then
        return port
    end

    return nil
end

---@param chunks string[]
---@return string last bytes of captured stderr for error messages
local function stderr_tail(chunks)
    local text = table.concat(chunks)
    local start = #text - STDERR_TAIL_BYTES + 1

    if start < 1 then
        start = 1
    end

    return (text:sub(start)):gsub('%s+$', '')
end

--- Spawn rdbg for a launch plan and wait (bounded) until it is listening:
--- the socket file appears (unix), the port file fills in (ephemeral TCP),
--- or the ready marker arrives on stderr (explicit TCP port). Kills the
--- child and reports nil+err when rdbg exits early or the wait times out.
---@param plan RdbgLaunchPlan
---@param cwd string
---@param env table<string, string>?
---@return RdbgDescriptor?, string?
local function spawn_and_wait(plan, cwd, env)
    assert(plan ~= nil, 'spawn_and_wait requires a launch plan')
    assert(nonempty_string(cwd), 'spawn_and_wait requires a cwd')

    local drain = { chunks = {}, size = 0, ready = false, exited = false, code = nil }

    local function on_stderr(_, data)
        if data == nil or data == '' then
            return
        end

        if drain.size < STDERR_MAX_BYTES then
            local keep = data:sub(1, STDERR_MAX_BYTES - drain.size)
            drain.chunks[#drain.chunks + 1] = keep
            drain.size = drain.size + #keep
        end

        if not drain.ready and data:find(READY_MARKER, 1, true) ~= nil then
            drain.ready = true
        end
    end

    -- Merge over the parent environment explicitly: vim.system replaces
    -- the environment when `env` is given, it does not merge.
    local merged_env = vim.tbl_extend('force', fn.environ(), env or {})

    local ok, job = pcall(vim.system, plan.argv, {
        cwd = cwd,
        env = merged_env,
        text = true,
        stderr = on_stderr,
    }, function(result)
        drain.exited = true
        drain.code = result and result.code or nil
    end)

    if not ok or job == nil then
        return nil, 'could not spawn rdbg'
    end

    local function failed()
        return drain.exited and drain.code ~= 0
    end

    local function give_up(reason)
        pcall(function()
            job:kill('sigterm')
        end)

        if failed() then
            return nil, ('rdbg exited with code %s: %s'):format(tostring(drain.code), stderr_tail(drain.chunks))
        end

        return nil, ('rdbg did not become ready in time (%s): %s'):format(reason, stderr_tail(drain.chunks))
    end

    if plan.mode == 'unix' then
        local appeared = vim.wait(SOCK_WAIT_MS, function()
            return failed() or uv.fs_stat(plan.sock_path) ~= nil
        end)

        if not appeared then
            return give_up('unix socket never appeared')
        end

        if failed() then
            return give_up('rdbg exited early')
        end

        return { mode = 'unix', sock_path = plan.sock_path }
    end

    if plan.port_path ~= nil then
        local port
        local appeared = vim.wait(PORT_WAIT_MS, function()
            if failed() then
                return true
            end

            port = read_port_file(plan.port_path)

            return port ~= nil
        end)

        if not appeared or failed() or port == nil then
            return give_up('ephemeral TCP port never reported')
        end

        return { mode = 'tcp', host = plan.host, port = port }
    end

    local ready = vim.wait(READY_WAIT_MS, function()
        return failed() or drain.ready
    end)

    if not ready or failed() then
        return give_up('TCP listener never announced itself')
    end

    return { mode = 'tcp', host = plan.host, port = plan.port }
end

---@param configuration table expanded launch configuration
---@return RdbgDescriptor?, string?
local function resolve_launch(configuration)
    local rdbg, rdbg_err = resolve_rdbg(configuration)

    if rdbg == nil then
        return nil, rdbg_err
    end

    local cwd = configuration.cwd

    if not nonempty_string(cwd) then
        cwd = project_root()
    end

    local plan, plan_err = M.launch_plan(rdbg, configuration, cwd)

    if plan == nil then
        return nil, plan_err
    end

    return spawn_and_wait(plan, cwd, configuration.env)
end

---@param configuration table expanded attach configuration
---@return RdbgDescriptor?, string?
local function resolve_attach(configuration)
    local rdbg, rdbg_err = resolve_rdbg(configuration)

    if rdbg == nil then
        return nil, rdbg_err
    end

    local cwd = configuration.cwd

    if not nonempty_string(cwd) then
        cwd = project_root()
    end

    if nonempty_string(configuration.sock_path) then
        local path = configuration.sock_path

        if uv.fs_stat(path) == nil then
            return nil, ('no such socket: %s'):format(path)
        end

        return { mode = 'unix', sock_path = path }
    end

    if configuration.debug_port ~= nil then
        local target, err = M.parse_debug_port(configuration.debug_port)

        if target == nil then
            return nil, err
        end

        if target.mode == 'unix' then
            if uv.fs_stat(target.sock_path) == nil then
                return nil, ('no such socket: %s'):format(target.sock_path)
            end
        elseif target.port == 0 then
            return nil, 'cannot attach to ephemeral port 0; give a real port'
        end

        return target
    end

    if nonempty_string(configuration.host) and configuration.port ~= nil then
        local port = tonumber(configuration.port)

        if port == nil or port < 1 or port > 65535 or port ~= math.floor(port) then
            return nil, 'attach requires port to be an integer in 1-65535'
        end

        return { mode = 'tcp', host = configuration.host, port = port }
    end

    -- Upstream discovery: `rdbg --util=list-socks` lists Ruby processes
    -- started with `rdbg --open`. Exactly one is unambiguous; anything
    -- else is an error, not a guess.
    local socks, err = list_socks(rdbg, cwd)

    if socks == nil then
        return nil, err
    end

    if #socks == 0 then
        return nil, 'no attachable Ruby process found; start one with `rdbg --open` (or `rdbg -O`)'
    end

    if #socks > 1 then
        return nil,
            ('multiple attachable Ruby processes; set sock_path to choose one:\n%s'):format(table.concat(socks, '\n'))
    end

    return { mode = 'unix', sock_path = socks[1] }
end

--- Point the shared adapter table at this session's resolved descriptor.
--- The DAP client deep-copies the adapter when the session is created, so
--- mutating here is per-session by construction; nothing is shared after
--- the copy.
---@param descriptor RdbgDescriptor
local function apply_descriptor(descriptor)
    assert(descriptor ~= nil, 'apply_descriptor requires a descriptor')

    if descriptor.mode == 'unix' then
        assert(nonempty_string(descriptor.sock_path), 'unix descriptor requires sock_path')
        M.adapter.type = 'pipe'
        M.adapter.pipe = descriptor.sock_path
        M.adapter.host = nil
        M.adapter.port = nil
    else
        assert(nonempty_string(descriptor.host), 'tcp descriptor requires host')
        assert(type(descriptor.port) == 'number', 'tcp descriptor requires port')
        M.adapter.type = 'server'
        M.adapter.host = descriptor.host
        M.adapter.port = descriptor.port
        M.adapter.pipe = nil
    end
end

--- DAP adapter hook: runs after config expansion, before the client
--- connects. Launches rdbg for `launch`, resolves the target for `attach`,
--- then hands the client a pipe (unix socket) or server (TCP) descriptor.
--- Failures notify and stop the session start; on_config is never called.
---@param configuration table expanded DAP configuration
---@param on_config fun(config: table)
local function enrich_config(configuration, on_config)
    assert(type(configuration) == 'table', 'enrich_config requires a configuration table')
    assert(type(on_config) == 'function', 'enrich_config requires an on_config function')

    local request = configuration.request
    local descriptor, err

    if request == 'launch' then
        descriptor, err = resolve_launch(configuration)
    elseif request == 'attach' then
        descriptor, err = resolve_attach(configuration)
    else
        err = ('unsupported DAP request %q'):format(tostring(request))
    end

    if descriptor == nil then
        notify(err or 'could not resolve rdbg target', levels.ERROR)

        return
    end

    apply_descriptor(descriptor)
    on_config(configuration)
end

---@type table
M.adapter = {
    name = SOURCE,
    -- Placeholder shape: enrich_config resolves the real descriptor per
    -- session (pipe for unix sockets, server for loopback TCP).
    type = 'pipe',
    enrich_config = enrich_config,
}

---@param bufnr? integer
---@return string
local function current_script(bufnr)
    local filename = buffer_filename(bufnr)

    if filename ~= '' then
        return filename
    end

    return '${file}'
end

---@type table<string, table[]>
M.configurations = {
    ruby = {
        {
            name = 'Ruby: Debug Current File',
            type = SOURCE,
            request = 'launch',
            -- Upstream vscode-rdbg names this field `script`.
            script = function()
                return current_script()
            end,
            -- The debug gem hardcodes nonstop on `launch`
            -- (server_dap.rb sets @nonstop = true); stating it keeps the
            -- request honest about what the adapter will do.
            nonstop = true,
            cwd = function()
                return project_root()
            end,
        },
        {
            name = 'Ruby: Debug with Arguments',
            type = SOURCE,
            request = 'launch',
            script = function()
                return current_script()
            end,
            args = function()
                local input = fn.input('Program arguments: ')

                if input == '' then
                    return {}
                end

                --
                -- vim.fn.shellsplit does not exist (E117); parse locally so
                -- quoted arguments survive as single argv elements.
                --
                local parsed, err = M.parse_args(input)

                if parsed == nil then
                    notify(err or 'invalid program arguments', levels.ERROR)

                    return {}
                end

                return parsed
            end,
            nonstop = true,
            cwd = function()
                return project_root()
            end,
        },
        {
            name = 'Ruby: RSpec Current File',
            type = SOURCE,
            request = 'launch',
            -- Explicit command: used as-is (upstream does not wrap an
            -- explicit command in `bundle exec`; write
            -- `command = 'bundle exec rspec'` if you need that).
            command = 'rspec',
            script = function()
                return current_script()
            end,
            nonstop = true,
            cwd = function()
                return project_root()
            end,
        },
        {
            name = 'Ruby: Attach to rdbg',
            type = SOURCE,
            request = 'attach',
            -- `nonstop` is intentionally unset: the debug gem honors the
            -- attach request's own `nonstop` field (absent/false stops at
            -- the breakpoint). Set `nonstop = true` here to keep running.
            -- Start the target first, e.g. `rdbg --open foo.rb`.
            -- Optional: `sock_path`, `debug_port`, or `host` + `port`.
            cwd = function()
                return project_root()
            end,
        },
    },
}

local function check_health()
    local rdbg = find_rdbg()
    local root = project_root()

    local messages = {
        'Ruby DAP (rdbg socket)',
        '',
        'rdbg: ' .. (rdbg or 'not found'),
        'project root: ' .. root,
        'bundler: ' .. (uses_bundler(root) and 'yes (Gemfile)' or 'no'),
        'transport: unix socket by default, loopback TCP when debug_port is set or on Windows',
    }

    if rdbg == nil then
        messages[#messages + 1] = ''
        messages[#messages + 1] = 'install the debug gem or set:'
        messages[#messages + 1] = 'NVIM_RDBG_PATH=/path/to/rdbg'
    end

    notify(table.concat(messages, '\n'), rdbg ~= nil and levels.INFO or levels.WARN)
end

---@type table<string, DebugCommand>
M.commands = {
    RubyCheck = {
        callback = function()
            check_health()
        end,
        desc = 'Check Ruby DAP configuration',
    },
}

---@type table<string, DebugMapping>
M.mappings = {
    ruby_check = {
        lhs = '<leader>dRc',
        mode = 'n',
        rhs = function()
            check_health()
        end,
        desc = 'Ruby DAP: Check configuration',
    },
}

---@param opts? table user overrides; honours `opts.rdbg`
function M.setup(opts)
    opts = opts or {}

    if nonempty_string(opts.rdbg) then
        state_rdbg = normalize(fn.expand(opts.rdbg))
    end

    -- rdbg is resolved per session by enrich_config, which reports a
    -- missing adapter then, so no setup nag.
end

---@return string?
function M.rdbg_path()
    return find_rdbg()
end

return M
