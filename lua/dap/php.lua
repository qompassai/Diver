-- #################################################################
-- ~/.config/nvim/lua/dap/php.lua
-- Qompass AI Diver Native PHP Debug Adapter Configuration
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
---@source https://github.com/xdebug/vscode-php-debug
---@source https://xdebug.org/docs/

--- PHP debugging via vscode-php-debug and Xdebug.
---
--- Plain-language version: this module finds the `phpDebug.js` adapter
--- program (run with Node), listens for Xdebug on your own machine only
--- (127.0.0.1, port 9003), and offers recipes to listen for a web request
--- or launch the PHP file you have open. Blade templates delegate to the
--- same Xdebug listener; there is no separate Blade debug adapter upstream.
---@module 'dap.php'

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local levels = vim.log.levels

local M = {}

local SOURCE = 'php'
local PROBE_TIMEOUT_MS = 5000
local XDEBUG_PORT = 9003
local LOOPBACK = '127.0.0.1'

---@type string[]
local ROOT_MARKERS = {
    'composer.json',
    'artisan',
    'index.php',
    '.git',
}

---@class PhpState
---@field adapter_js string?
---@field node string?
local state = {
    adapter_js = nil,
    node = nil,
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
---@return boolean
local function readable_file(path)
    return nonempty_string(path) and fn.filereadable(path) == 1
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
local function find_node()
    if state.node ~= nil then
        return state.node
    end

    local configured = vim.env.NVIM_NODE_PATH

    if executable(configured or '') then
        state.node = normalize(fn.expand(configured))
    else
        local on_path = fn.exepath('node')

        if nonempty_string(on_path) then
            state.node = fs.normalize(on_path)
        end
    end

    return state.node
end

---@return string?
local function find_adapter_js()
    if state.adapter_js ~= nil then
        return state.adapter_js
    end

    local candidates = {}

    local configured = vim.env.NVIM_PHP_DEBUG_JS

    if nonempty_string(configured) then
        candidates[#candidates + 1] = normalize(fn.expand(configured))
    end

    local global = vim.g.php_debug_js

    if nonempty_string(global) then
        candidates[#candidates + 1] = normalize(fn.expand(global))
    end

    --
    -- Common install locations for the vscode-php-debug extension.
    --
    candidates[#candidates + 1] = fn.expand('~/.vscode/extensions/xdebug.php-debug/out/phpDebug.js')
    candidates[#candidates + 1] = fn.expand(
        '~/.local/share/nvim/mason/packages/php-debug-adapter/extension/out/phpDebug.js'
    )
    candidates[#candidates + 1] = '/usr/local/lib/node_modules/php-debug/out/phpDebug.js'

    for _, candidate in ipairs(candidates) do
        if readable_file(candidate) then
            state.adapter_js = fs.normalize(candidate)

            return state.adapter_js
        end
    end

    return nil
end

---@return boolean
local function xdebug_present()
    local php = fn.exepath('php')

    if php == '' then
        return false
    end

    local result = system({ php, '--ri', 'xdebug' })

    return result ~= nil and result.code == 0
end

---@return string
local function adapter_command()
    local node = find_node()

    if node ~= nil then
        return node
    end

    --
    -- Keep the adapter structurally valid when node is missing.
    -- setup() warns before any session is attempted.
    --
    return 'node'
end

---@return string[]
local function adapter_args()
    local js = find_adapter_js()

    if js ~= nil then
        return { js }
    end

    return {}
end

---@param opts table
---@return table?, string?
function M.build_listen(opts)
    opts = opts or {}

    local port = opts.port or XDEBUG_PORT

    if port < 1 or port > 65535 then
        return nil, 'build_listen requires opts.port in 1..65535'
    end

    --
    -- Always bind the Xdebug listener to loopback. The adapter defaults to
    -- all interfaces; a debug port reachable from the network is a remote
    -- code execution vector.
    --
    return {
        name = opts.name or 'PHP: Listen for Xdebug',
        type = SOURCE,
        request = 'launch',
        port = port,
        hostname = LOOPBACK,
        pathMappings = opts.path_mappings,
        xdebugSettings = opts.xdebug_settings,
    }
end

---@param opts table
---@return table?, string?
function M.build_launch_script(opts)
    opts = opts or {}

    if not nonempty_string(opts.program) then
        return nil, 'build_launch_script requires opts.program'
    end

    return {
        name = opts.name or 'PHP: Launch Current Script',
        type = SOURCE,
        request = 'launch',
        program = opts.program,
        cwd = opts.cwd or project_root(),
        port = opts.port or XDEBUG_PORT,
        hostname = LOOPBACK,
        runtimeExecutable = opts.runtime_executable or 'php',
        runtimeArgs = opts.runtime_args,
        env = opts.env,
        pathMappings = opts.path_mappings,
    }
end

---@type table
M.adapter = {
    name = SOURCE,
    type = 'executable',
    command = adapter_command(),
    args = adapter_args(),
    options = {
        source_filetype = 'php',
    },
}

---@type table<string, table[]>
M.configurations = {
    php = {
        {
            name = 'PHP: Listen for Xdebug',
            type = SOURCE,
            request = 'launch',
            port = XDEBUG_PORT,
            hostname = LOOPBACK,
        },
        {
            name = 'PHP: Launch Current Script',
            type = SOURCE,
            request = 'launch',
            program = function()
                local filename = buffer_filename()

                if filename ~= '' then
                    return filename
                end

                return '${file}'
            end,
            cwd = function()
                return project_root()
            end,
            port = XDEBUG_PORT,
            hostname = LOOPBACK,
            runtimeExecutable = 'php',
        },
    },
}

local function check_health()
    local node = find_node()
    local js = find_adapter_js()

    local messages = {
        'PHP DAP (vscode-php-debug)',
        '',
        'node: ' .. (node or 'not found'),
        'adapter: ' .. (js or 'not found'),
        'xdebug extension: ' .. (xdebug_present() and 'present' or 'not detected'),
        ('listen address: %s:%d (loopback only)'):format(LOOPBACK, XDEBUG_PORT),
    }

    if js == nil then
        messages[#messages + 1] = ''
        messages[#messages + 1] = 'install the php-debug adapter and set:'
        messages[#messages + 1] = 'NVIM_PHP_DEBUG_JS=/path/to/phpDebug.js'
    end

    if not xdebug_present() then
        messages[#messages + 1] = ''
        messages[#messages + 1] = 'install the Xdebug PHP extension and enable it:'
        messages[#messages + 1] = 'zend_extension=xdebug'
        messages[#messages + 1] = 'xdebug.mode=debug'
    end

    notify(table.concat(messages, '\n'), (node ~= nil and js ~= nil) and levels.INFO or levels.WARN)
end

---@type table<string, DebugCommand>
M.commands = {
    PhpCheck = {
        callback = function()
            check_health()
        end,
        desc = 'Check PHP DAP configuration',
    },
}

---@type table<string, DebugMapping>
M.mappings = {
    php_check = {
        lhs = '<leader>dPc',
        mode = 'n',
        rhs = function()
            check_health()
        end,
        desc = 'PHP DAP: Check configuration',
    },
}

---@param opts? table user overrides; honours `opts.node` and `opts.php_debug_js`
function M.setup(opts)
    opts = opts or {}

    if nonempty_string(opts.node) then
        state.node = normalize(fn.expand(opts.node))
    end

    if nonempty_string(opts.php_debug_js) then
        state.adapter_js = normalize(fn.expand(opts.php_debug_js))
    end

    local node = find_node()
    local js = find_adapter_js()

    if node == nil or js == nil then
        vim.schedule(function()
            notify(
                table.concat({
                    'php-debug adapter is not fully configured.',
                    '',
                    'Need: node on PATH and the vscode-php-debug phpDebug.js.',
                    'Set NVIM_PHP_DEBUG_JS=/path/to/phpDebug.js to point at it.',
                }, '\n'),
                levels.WARN
            )
        end)

        return
    end

    --
    -- Keep the adapter synchronized with discovery.
    --
    M.adapter.command = node
    M.adapter.args = { js }
end

---@return boolean
function M.xdebug_available()
    return xdebug_present()
end

return M
