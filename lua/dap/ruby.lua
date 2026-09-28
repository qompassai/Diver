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
---@source https://github.com/ruby/debug/blob/master/doc/debugger.md

--- Ruby debugging via rdbg's socket Debug Adapter Protocol.
---
--- Plain-language version: Ruby's `debug` gem (`rdbg`) speaks the Debug
--- Adapter Protocol, but only over a network socket, never stdio. This
--- module starts `rdbg` in listening mode on your own machine only
--- (127.0.0.1, never the open network) and connects Neovim to it. It offers
--- recipes to run a script, a Rails app, or an RSpec test, and it wraps the
--- command with `bundle exec` when your project uses Bundler.
---@module 'dap.ruby'

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local uv = vim.uv
local levels = vim.log.levels

local M = {}

local SOURCE = 'ruby'
local LOOPBACK = '127.0.0.1'
local DEFAULT_PORT = 38698
local MAX_PORT_ATTEMPTS = 16

---@type string[]
local ROOT_MARKERS = {
    'Gemfile',
    'Rakefile',
    'config.ru',
    '.git',
}

---@class RubyState
---@field rdbg string?
---@field port integer?
---@field job vim.SystemObj?
local state = {
    rdbg = nil,
    port = nil,
    job = nil,
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

---@return string?
local function find_rdbg()
    if state.rdbg ~= nil then
        return state.rdbg
    end

    local configured = vim.env.NVIM_RDBG_PATH

    if executable(configured or '') then
        state.rdbg = normalize(fn.expand(configured))

        return state.rdbg
    end

    local on_path = fn.exepath('rdbg')

    if nonempty_string(on_path) then
        state.rdbg = fs.normalize(on_path)

        return state.rdbg
    end

    return nil
end

---@param host string
---@param port integer
---@return boolean
local function port_free(host, port)
    local ok, socket = pcall(uv.new_tcp)

    if not ok or socket == nil then
        return false
    end

    local bound = pcall(uv.tcp_bind, socket, host, port)
    uv.close(socket)

    return bound
end

---@return integer?
local function pick_port()
    local configured = tonumber(vim.env.NVIM_RDBG_PORT or vim.g.rdbg_port or '')

    if configured ~= nil and configured >= 1 and configured <= 65535 then
        if port_free(LOOPBACK, configured) then
            return configured
        end

        notify(('configured rdbg port %d is busy'):format(configured), levels.WARN)
    end

    if port_free(LOOPBACK, DEFAULT_PORT) then
        return DEFAULT_PORT
    end

    for attempt = 1, MAX_PORT_ATTEMPTS do
        local port = DEFAULT_PORT + attempt

        if port <= 65535 and port_free(LOOPBACK, port) then
            return port
        end
    end

    return nil
end

---@param root string
---@return boolean
local function uses_bundler(root)
    return root ~= '' and fn.filereadable(root .. '/Gemfile') == 1
end

---@param raw string
---@return string[]?, string?
local function parse_args(raw)
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

---@param root string
---@param extra string[]
---@return string[]
local function rdbg_command(root, extra)
    local rdbg = find_rdbg()
    local port = state.port or DEFAULT_PORT

    if rdbg == nil then
        return {}
    end

    local command = { rdbg }

    if uses_bundler(root) then
        --
        -- Run the project's own debug gem through Bundler so the versions
        -- match the Gemfile.lock instead of whatever is installed globally.
        --
        command = { 'bundle', 'exec', rdbg }
    end

    vim.list_extend(command, {
        '--open',
        '--host',
        LOOPBACK,
        '--port',
        tostring(port),
    })
    vim.list_extend(command, extra)

    return command
end

---@param root string
---@return boolean
local function start_rdbg(root)
    if state.job ~= nil then
        return true
    end

    local rdbg = find_rdbg()

    if rdbg == nil then
        notify('rdbg was not found (gem install debug)', levels.ERROR)

        return false
    end

    local port = pick_port()

    if port == nil then
        notify('no free loopback port for rdbg', levels.ERROR)

        return false
    end

    state.port = port

    local command = rdbg_command(root, { '--', 'ruby' })

    if #command == 0 then
        return false
    end

    local ok, job = pcall(vim.system, command, {
        cwd = root,
        text = true,
        detach = false,
    }, function(result)
        state.job = nil

        if result ~= nil and result.code ~= 0 then
            vim.schedule(function()
                notify('rdbg exited unexpectedly', levels.WARN)
            end)
        end
    end)

    if not ok or job == nil then
        notify('could not start rdbg', levels.ERROR)

        return false
    end

    state.job = job

    return true
end

---@type table
M.adapter = {
    name = SOURCE,
    type = 'server',
    host = LOOPBACK,
    port = function()
        return state.port or DEFAULT_PORT
    end,
    executable = {
        command = 'rdbg',
        args = {
            '--open',
            '--host',
            LOOPBACK,
            '--port',
            '${port}',
        },
    },
}

---@type table<string, table[]>
M.configurations = {
    ruby = {
        {
            name = 'Ruby: Debug Current File',
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
        },
        {
            name = 'Ruby: Debug with Arguments',
            type = SOURCE,
            request = 'launch',
            program = function()
                local filename = buffer_filename()

                if filename ~= '' then
                    return filename
                end

                return '${file}'
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
                local parsed, err = parse_args(input)

                if parsed == nil then
                    notify(err or 'invalid program arguments', levels.ERROR)

                    return {}
                end

                return parsed
            end,
            cwd = function()
                return project_root()
            end,
        },
        {
            name = 'Ruby: RSpec Current File',
            type = SOURCE,
            request = 'launch',
            program = function()
                local filename = buffer_filename()

                if filename ~= '' then
                    return filename
                end

                return '${file}'
            end,
            command = 'rspec',
            cwd = function()
                return project_root()
            end,
        },
        {
            name = 'Ruby: Attach to rdbg',
            type = SOURCE,
            request = 'attach',
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
        ('listen address: %s (loopback only)'):format(LOOPBACK),
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

    RubyRdbgStart = {
        callback = function()
            local root = project_root()

            if start_rdbg(root) then
                notify(('rdbg listening on %s:%d'):format(LOOPBACK, state.port or DEFAULT_PORT))
            end
        end,
        desc = 'Start rdbg in listening mode on loopback',
    },

    RubyRdbgStop = {
        callback = function()
            if state.job == nil then
                notify('rdbg is not running', levels.WARN)

                return
            end

            state.job:kill('sigterm')
            state.job = nil
            state.port = nil
            notify('rdbg stopped')
        end,
        desc = 'Stop the running rdbg listener',
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
        state.rdbg = normalize(fn.expand(opts.rdbg))
    end

    if find_rdbg() == nil then
        vim.schedule(function()
            notify(
                table.concat({
                    'rdbg was not found.',
                    '',
                    'Install with: gem install debug',
                    'Or set: NVIM_RDBG_PATH=/path/to/rdbg',
                }, '\n'),
                levels.WARN
            )
        end)
    end
end

---@return string?
function M.rdbg_path()
    return find_rdbg()
end

return M
