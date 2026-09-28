-- #################################################################
-- ~/.config/nvim/lua/dap/firefox.lua
-- Qompass AI Diver Native Firefox Debug Adapter Configuration
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
---@source https://github.com/firefox-devtools/vscode-firefox-debug
---@source https://github.com/firefox-devtools/vscode-firefox-debug/blob/HEAD/README.md
---@source https://github.com/mfussenegger/nvim-dap/issues/1513
---@source https://github.com/mozilla-firefox/firefox/blob/HEAD/browser/docs/CommandLineParameters.md

--- Firefox web debugging through the Firefox Debug Adapter.
---
--- Plain-language version: `firefox-debug-adapter` (upstream
--- firefox-devtools/vscode-firefox-debug, shipped by Mason as the
--- `firefox-debug-adapter` package) is a small program that translates the
--- Debug Adapter Protocol into Firefox's own remote debugging protocol. It
--- talks DAP to Neovim over stdio, so no port juggling is needed on the
--- Neovim side: launch starts a Firefox instance for you, attach connects
--- to a Firefox you started yourself.
---
--- Prerequisites:
---
--- - Launch: Firefox installed where the adapter can find it
---   (`firefoxExecutable` overrides the lookup). The launch configuration
---   needs either `file` (a local HTML file) or `url` plus `webRoot` so
---   the adapter can map URLs back to your sources.
--- - Attach: start Firefox manually with the remote debugger enabled:
---   enable "remote debugging" in the Developer Tools Settings (or set
---   `devtools.debugger.remote-enabled=true` and
---   `devtools.chrome.enabled=true` in about:config), then run
---   `firefox -start-debugger-server` (default port 6000).
---
--- Honest limitations:
---
--- - The adapter needs Node.js at session start: the Mason-installed
---   `firefox-debug-adapter` executable is a wrapper around
---   `node .../dist/adapter.bundle.js` (verified against the Mason
---   package layout and nvim-dap#1513).
--- - Breakpoints in bundled/transpiled apps only bind with correct
---   `webRoot`/`pathMappings`; the README documents `pathMappings` as
---   required when the URL points into a subdirectory of the project.
---@module 'dap.firefox'

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local levels = vim.log.levels

local M = {}

local SOURCE = 'firefox'
local ADAPTER_BIN = 'firefox-debug-adapter'
local LOOPBACK = '127.0.0.1'
local DEFAULT_REMOTE_PORT = 6000
local DEFAULT_URL = 'http://localhost:3000'

---@type string[]
local ROOT_MARKERS = {
    'package.json',
    'vite.config.js',
    'vite.config.ts',
    'webpack.config.js',
    'webpack.config.ts',
    'index.html',
    '.git',
}

---@type table<string, boolean>
local BUILD_LAUNCH_FIELDS = {
    name = true,
    url = true,
    file = true,
    web_root = true,
    path_mappings = true,
    re_attach = true,
    firefox_executable = true,
}

---@type table<string, boolean>
local BUILD_ATTACH_FIELDS = {
    name = true,
    host = true,
    port = true,
    url = true,
    web_root = true,
    path_mappings = true,
}

---@class FirefoxState
---@field adapter string?
local state = {
    adapter = nil,
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

---@return string
local function mason_bin()
    return fs.joinpath(fn.stdpath('data'), 'mason', 'bin', ADAPTER_BIN)
end

---@return string?
local function find_adapter()
    if state.adapter ~= nil then
        return state.adapter
    end

    local candidates = {}

    local configured = vim.env.NVIM_FIREFOX_DEBUG_ADAPTER_PATH

    if nonempty_string(configured) then
        candidates[#candidates + 1] = normalize(fn.expand(configured))
    end

    local global = vim.g.firefox_debug_adapter_path

    if nonempty_string(global) then
        candidates[#candidates + 1] = normalize(fn.expand(global))
    end

    local on_path = fn.exepath(ADAPTER_BIN)

    if nonempty_string(on_path) then
        candidates[#candidates + 1] = fs.normalize(on_path)
    end

    candidates[#candidates + 1] = mason_bin()

    for _, candidate in ipairs(candidates) do
        if executable(candidate) then
            state.adapter = fs.normalize(candidate)

            return state.adapter
        end
    end

    return nil
end

---@param value unknown
---@return integer?, string?
local function valid_port(value)
    if type(value) ~= 'number' then
        return nil, 'port must be a number'
    end

    if value % 1 ~= 0 or value < 1 or value > 65535 then
        return nil, 'port must be an integer in 1..65535'
    end

    return math.floor(value)
end

---@param path_mappings unknown
---@return table[]?, string?
local function valid_path_mappings(path_mappings)
    if path_mappings == nil then
        return nil
    end

    if type(path_mappings) ~= 'table' then
        return nil, 'path_mappings must be a list of { url=..., path=... } tables'
    end

    for index, mapping in ipairs(path_mappings) do
        if type(mapping) ~= 'table' then
            return nil, ('path_mappings[%d] must be a table'):format(index)
        end

        if not nonempty_string(mapping.url) then
            return nil, ('path_mappings[%d].url must be a non-empty string'):format(index)
        end

        if not nonempty_string(mapping.path) then
            return nil, ('path_mappings[%d].path must be a non-empty string'):format(index)
        end
    end

    return path_mappings
end

---@param fields table<string, boolean>
---@param builder string
---@param opts table
---@return string?
local function unknown_field(fields, builder, opts)
    for key in pairs(opts) do
        if fields[key] ~= true then
            return ('%s: unknown field %s'):format(builder, key)
        end
    end

    return nil
end

--- Resolve the standalone adapter executable.
---
--- The Mason `firefox-debug-adapter` bin is a wrapper that runs
--- `node <prefix>/dist/adapter.bundle.js`; the bundle speaks DAP over
--- stdio, so the adapter takes no arguments.
---@return table?
function M.resolve_adapter()
    local path = find_adapter()

    if path == nil then
        return nil
    end

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
    -- Keep the adapter structurally valid when the binary is missing.
    -- setup() warns before any session is attempted.
    --
    return ADAPTER_BIN
end

---@param opts table
---@return table?, string?
function M.build_launch(opts)
    opts = opts or {}

    local unknown = unknown_field(BUILD_LAUNCH_FIELDS, 'build_launch', opts)

    if unknown ~= nil then
        return nil, unknown
    end

    local has_url = nonempty_string(opts.url)
    local has_file = nonempty_string(opts.file)

    if not has_url and not has_file then
        return nil, 'build_launch requires exactly one of opts.url or opts.file'
    end

    if has_url and has_file then
        return nil, 'build_launch accepts only one of opts.url or opts.file, not both'
    end

    if opts.web_root ~= nil and not nonempty_string(opts.web_root) then
        return nil, 'build_launch requires opts.web_root to be a non-empty string'
    end

    if opts.re_attach ~= nil and type(opts.re_attach) ~= 'boolean' then
        return nil, 'build_launch requires opts.re_attach to be a boolean'
    end

    if opts.firefox_executable ~= nil and not nonempty_string(opts.firefox_executable) then
        return nil, 'build_launch requires opts.firefox_executable to be a non-empty string'
    end

    local path_mappings, mappings_err = valid_path_mappings(opts.path_mappings)

    if mappings_err ~= nil then
        return nil, 'build_launch: ' .. mappings_err
    end

    local config = {
        name = opts.name or 'Firefox: Launch',
        type = SOURCE,
        request = 'launch',
    }

    if has_url then
        config.url = opts.url
    else
        config.file = opts.file
    end

    if opts.web_root ~= nil then
        config.webRoot = opts.web_root
    end

    if path_mappings ~= nil then
        config.pathMappings = path_mappings
    end

    if opts.re_attach ~= nil then
        config.reAttach = opts.re_attach
    end

    if opts.firefox_executable ~= nil then
        config.firefoxExecutable = opts.firefox_executable
    end

    return config
end

---@param opts table
---@return table?, string?
function M.build_attach(opts)
    opts = opts or {}

    local unknown = unknown_field(BUILD_ATTACH_FIELDS, 'build_attach', opts)

    if unknown ~= nil then
        return nil, unknown
    end

    local host = opts.host or LOOPBACK

    if not nonempty_string(host) then
        return nil, 'build_attach requires opts.host to be a non-empty string'
    end

    --
    -- Firefox's remote debugger port (devtools.debugger.remote-port),
    -- the default used by `firefox -start-debugger-server`.
    --
    local port = DEFAULT_REMOTE_PORT

    if opts.port ~= nil then
        local valid, port_err = valid_port(opts.port)

        if valid == nil then
            return nil, 'build_attach: ' .. (port_err or 'invalid port')
        end

        port = valid
    end

    if opts.url ~= nil and not nonempty_string(opts.url) then
        return nil, 'build_attach requires opts.url to be a non-empty string'
    end

    if opts.web_root ~= nil and not nonempty_string(opts.web_root) then
        return nil, 'build_attach requires opts.web_root to be a non-empty string'
    end

    local path_mappings, mappings_err = valid_path_mappings(opts.path_mappings)

    if mappings_err ~= nil then
        return nil, 'build_attach: ' .. mappings_err
    end

    local config = {
        name = opts.name or 'Firefox: Attach',
        type = SOURCE,
        request = 'attach',
        host = host,
        port = port,
    }

    if opts.url ~= nil then
        config.url = opts.url
    end

    if opts.web_root ~= nil then
        config.webRoot = opts.web_root
    end

    if path_mappings ~= nil then
        config.pathMappings = path_mappings
    end

    return config
end

---@type table
M.adapter = {
    name = SOURCE,
    type = 'executable',
    command = adapter_command(),
    args = {},
}

---@return string
local function current_file()
    local filename = buffer_filename()

    if filename ~= '' then
        return filename
    end

    return '${file}'
end

---@return string
local function prompt_url()
    local input = fn.input('URL: ', DEFAULT_URL)

    if input == '' then
        return DEFAULT_URL
    end

    return input
end

---@type table[]
local configurations = {
    {
        name = 'Firefox: Launch File',
        type = SOURCE,
        request = 'launch',
        file = current_file,
        reAttach = true,
    },
    {
        name = 'Firefox: Launch URL',
        type = SOURCE,
        request = 'launch',
        url = prompt_url,
        webRoot = function()
            return project_root()
        end,
        reAttach = true,
    },
    {
        name = 'Firefox: Attach',
        type = SOURCE,
        request = 'attach',
        host = LOOPBACK,
        port = DEFAULT_REMOTE_PORT,
        webRoot = function()
            return project_root()
        end,
    },
}

--
-- One adapter/configuration stack is shared across the web filetypes,
-- matching the filetype naming used by the node (js-debug) module.
--
---@type table<string, table[]>
M.configurations = {
    javascript = configurations,
    javascriptreact = configurations,
    typescript = configurations,
    typescriptreact = configurations,
}

---@return string?
local function node_path()
    local path = fn.exepath('node')

    if nonempty_string(path) then
        return fs.normalize(path)
    end

    return nil
end

---@return string?
local function firefox_path()
    local path = fn.exepath('firefox')

    if nonempty_string(path) then
        return fs.normalize(path)
    end

    return nil
end

local function check_health()
    local adapter = find_adapter()
    local node = node_path()
    local firefox = firefox_path()

    local messages = {
        'Firefox DAP (firefox-debug-adapter, stdio bridge)',
        '',
        'adapter: ' .. (adapter or 'not found'),
        'node: ' .. (node or 'not found (required: the adapter runs on node)'),
        'firefox: ' .. (firefox or 'not found (required for launch)'),
        '',
        'attach prerequisites: enable remote debugging in the Developer',
        'Tools Settings (or about:config devtools.debugger.remote-enabled',
        'and devtools.chrome.enabled), then: firefox -start-debugger-server',
    }

    if adapter == nil then
        messages[#messages + 1] = ''
        messages[#messages + 1] = 'install the Mason package, or set:'
        messages[#messages + 1] = 'NVIM_FIREFOX_DEBUG_ADAPTER_PATH=/path/to/firefox-debug-adapter'
    end

    local ok = adapter ~= nil and node ~= nil

    notify(table.concat(messages, '\n'), ok and levels.INFO or levels.WARN)
end

---@type table<string, DebugCommand>
M.commands = {
    FirefoxDebugCheck = {
        callback = function()
            check_health()
        end,
        desc = 'Check Firefox DAP configuration',
    },
}

---@type table<string, DebugMapping>
M.mappings = {
    firefox_check = {
        lhs = '<leader>dFc',
        mode = 'n',
        rhs = function()
            check_health()
        end,
        desc = 'Firefox DAP: Check configuration',
    },
}

---@param opts? table user overrides; honours `opts.firefox_debug_adapter_path`
function M.setup(opts)
    opts = opts or {}

    if nonempty_string(opts.firefox_debug_adapter_path) then
        state.adapter = normalize(fn.expand(opts.firefox_debug_adapter_path))
    end

    --
    -- Keep the adapter command synchronized with discovery.
    --
    M.adapter.command = adapter_command()

    if find_adapter() == nil then
        vim.schedule(function()
            notify(
                table.concat({
                    'firefox-debug-adapter was not found.',
                    '',
                    'Install the Mason package:',
                    '  :MasonInstall firefox-debug-adapter',
                    'Or set:',
                    '  NVIM_FIREFOX_DEBUG_ADAPTER_PATH=/path/to/firefox-debug-adapter',
                }, '\n'),
                levels.WARN
            )
        end)

        return
    end

    if node_path() == nil then
        vim.schedule(function()
            notify('node was not found; firefox-debug-adapter runs on node', levels.WARN)
        end)
    end
end

---@return string?
function M.adapter_path()
    return find_adapter()
end

return M
