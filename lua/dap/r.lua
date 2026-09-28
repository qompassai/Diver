-- #################################################################
-- ~/.config/nvim/lua/dap/r.lua
-- Qompass AI Diver Native R Debug Adapter Configuration
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
---@source https://github.com/ManuelHentschel/VSCode-R-Debugger
---@source https://github.com/ManuelHentschel/VSCode-R-Debugger/blob/master/src/debugConfig.ts
---@source https://github.com/ManuelHentschel/VSCode-R-Debugger/blob/master/src/debugAdapter.ts
---@source https://github.com/ManuelHentschel/VSCode-R-Debugger/blob/master/configuration.md
---@source https://microsoft.github.io/debug-adapter-protocol/implementors/adapters/

--- R debugging via the vscDebugger DAP listener (attach only).
---
--- Plain-language version: the R package `vscDebugger` can listen for
--- Debug Adapter Protocol messages on a TCP port inside a running R
--- session. This module connects Neovim to that listener, so you start R
--- yourself, load the package, and attach the debugger to it.
---
--- Verified facts (evidence over assumptions):
--- - There is NO documented standalone (non-VS-Code) entry point for the
---   "R Debugger" adapter. Its launch path runs in-process inside the VS
---   Code extension host (`src/debugConfig.ts` returns
---   `vscode.DebugAdapterInlineImplementation` for `request = 'launch'`),
---   and `src/debugAdapter.ts` imports the `vscode` API, so it cannot
---   run under plain `node`. The `package.json` `"program":
---   "./out/debugAdapter.js"` entry is dead: the registered
---   `DebugAdapterDescriptorFactory` (`src/extension.ts`) overrides it.
--- - The documented attach route is a TCP server descriptor: VS Code
---   itself connects to R over DAP (`new vscode.DebugAdapterServer(port,
---   host)` in `src/debugConfig.ts`, defaults 18721 / localhost), after
---   the user calls `.vsc.listenForDAP()` in R (`configuration.md` 3.2;
---   the README's attach section calls it `.vsc.listen()`).
--- - The adapter is listed in the official DAP adapter catalog
---   ("R Debugger", @ManuelHentschel).
---
--- Known limitations:
--- - `build_launch` is intentionally unsupported: launching an R debug
---   session requires the VS Code extension host, and no standalone
---   invocation is documented. It returns nil plus an error explaining
---   this instead of fabricating a `node .../out/debugAdapter.js`
---   command that cannot work.
--- - Attach-mode flow control (step/continue) in VS Code additionally
---   uses an extension-managed "custom socket" (`useCustomSocket`,
---   default true: "necessary to allow flow control (stepping through
---   code)"). Outside VS Code only the documented DAP surface is
---   available, so expect breakpoints and variable inspection to work
---   and stepping to be limited.
--- - No binary discovery is performed: there is no adapter binary to
---   find, so `NVIM_R_DEBUG_ADAPTER_PATH`-style overrides do not exist.
---   Endpoint discovery is setup opts > `NVIM_R_DEBUG_HOST` /
---   `NVIM_R_DEBUG_PORT` > `vim.g.r_debug_host` / `vim.g.r_debug_port`
---   > defaults (`127.0.0.1`, `18721`).
---@module 'dap.r'

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local levels = vim.log.levels

local M = {}

local SOURCE = 'r'
local DEFAULT_HOST = '127.0.0.1'
local DEFAULT_PORT = 18721
local MIN_PORT = 1
local MAX_PORT = 65535

---@type string[]
local ROOT_MARKERS = {
    'DESCRIPTION',
    '.Rprofile',
    '.git',
}

---@class RState
---@field host string?
---@field port integer?
local state = {
    host = nil,
    port = nil,
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

    return fs.normalize(fn.fnamemodify(name, ':p'))
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

---@param raw unknown
---@return integer
local function valid_port(raw)
    local port = tonumber(raw)

    if port == nil or port < MIN_PORT or port > MAX_PORT or port % 1 ~= 0 then
        return DEFAULT_PORT
    end

    return math.floor(port)
end

---@param raw unknown
---@return string
local function valid_host(raw)
    if nonempty_string(raw) then
        return raw
    end

    return DEFAULT_HOST
end

---@return string, integer
local function resolve_endpoint()
    local host = state.host

    if not nonempty_string(host) then
        host = vim.env.NVIM_R_DEBUG_HOST
    end

    if not nonempty_string(host) then
        host = vim.g.r_debug_host
    end

    local port = state.port

    if port == nil then
        port = vim.env.NVIM_R_DEBUG_PORT
    end

    if port == nil then
        port = vim.g.r_debug_port
    end

    return valid_host(host), valid_port(port)
end

---@param opts? table per-call overrides; honours `opts.host` and `opts.port`
---@return string, integer
local function endpoint_from_opts(opts)
    opts = opts or {}

    local host, port = resolve_endpoint()

    if nonempty_string(opts.host) then
        host = opts.host
    end

    if opts.port ~= nil then
        local parsed = tonumber(opts.port)

        if parsed ~= nil and parsed >= MIN_PORT and parsed <= MAX_PORT and parsed % 1 == 0 then
            port = math.floor(parsed)
        end
    end

    return host, port
end

---@param opts? table
---@return table
function M.resolve_adapter(opts)
    local host, port = endpoint_from_opts(opts)

    --
    -- The documented non-VS-Code route is a TCP server: R's vscDebugger
    -- package listens for DAP messages after `.vsc.listenForDAP()`.
    -- There is no adapter binary to spawn.
    --
    return {
        name = SOURCE,
        type = 'server',
        host = host,
        port = port,
    }
end

---@param opts? table
---@return table?, string?
function M.build_launch(opts)
    if opts ~= nil and type(opts) ~= 'table' then
        return nil, 'build_launch requires a table of options'
    end

    --
    -- Launch is VS Code-extension-host-only: the Node adapter runs
    -- in-process (`vscode.DebugAdapterInlineImplementation`) and imports
    -- the `vscode` API. No standalone invocation is documented, so no
    -- launch configuration is fabricated here.
    --
    return nil,
        'R Debugger launch requires the VS Code extension host; '
            .. 'only attach to a running R session is supported outside VS Code'
end

---@param opts? table
---@return table?, string?
function M.build_attach(opts)
    opts = opts or {}

    local host, port = endpoint_from_opts(opts)

    return {
        name = opts.name or ('R: Attach (%s:%d)'):format(host, port),
        type = SOURCE,
        request = 'attach',
        host = host,
        port = port,
    }
end

---@type table
M.adapter = {
    name = SOURCE,
    type = 'server',
    host = DEFAULT_HOST,
    port = DEFAULT_PORT,
}

---@type table<string, table[]>
M.configurations = {
    r = {
        {
            name = 'R: Attach to R Session',
            type = SOURCE,
            request = 'attach',
            host = function()
                local host = fn.input('R DAP host: ', DEFAULT_HOST)

                return valid_host(host ~= '' and host or nil)
            end,
            port = function()
                local input = fn.input('R DAP port: ', tostring(DEFAULT_PORT))

                if input == '' then
                    return DEFAULT_PORT
                end

                return valid_port(input)
            end,
        },
    },
}

---@return boolean
local function rscript_available()
    return nonempty_string(fn.exepath('Rscript'))
end

local function check_health()
    local host, port = resolve_endpoint()
    local rscript = fn.exepath('Rscript')

    local messages = {
        'R DAP (vscDebugger attach, TCP server)',
        '',
        ('endpoint: %s:%d'):format(host, port),
        ('Rscript: %s'):format(nonempty_string(rscript) and rscript or 'not found'),
        'project root: ' .. project_root(),
        '',
        'attach prerequisites (in a terminal running R):',
        '  install.packages("vscDebugger",',
        '      repos = "https://manuelhentschel.r-universe.dev")',
        '  library(vscDebugger)',
        '  .vsc.listenForDAP()',
    }

    if not rscript_available() then
        messages[#messages + 1] = ''
        messages[#messages + 1] = 'Rscript was not found on PATH;'
        messages[#messages + 1] = 'install R to run the debuggee side.'
    end

    messages[#messages + 1] = ''
    messages[#messages + 1] = 'note: there is no standalone R debug adapter'
    messages[#messages + 1] = 'binary; launch mode needs the VS Code extension host.'

    notify(table.concat(messages, '\n'), levels.INFO)
end

---@type table<string, DebugCommand>
M.commands = {
    RDebugCheck = {
        callback = function()
            check_health()
        end,
        desc = 'Check R DAP configuration',
    },
}

---@type table<string, DebugMapping>
M.mappings = {
    r_debug_check = {
        lhs = '<leader>drc',
        mode = 'n',
        rhs = function()
            check_health()
        end,
        desc = 'R DAP: Check configuration',
    },
}

---@param opts? table user overrides; honours `opts.host` and `opts.port`
function M.setup(opts)
    opts = opts or {}

    if nonempty_string(opts.host) then
        state.host = opts.host
    end

    if opts.port ~= nil then
        state.port = valid_port(opts.port)
    end

    --
    -- Keep the adapter endpoint synchronized with discovery.
    --
    local host, port = resolve_endpoint()
    M.adapter.host = host
    M.adapter.port = port
end

---@return string, integer
function M.endpoint()
    return resolve_endpoint()
end

---@return boolean
function M.rscript_found()
    return rscript_available()
end

return M
