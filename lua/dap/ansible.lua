-- #################################################################
-- ~/.config/nvim/lua/dap/ansible.lua
-- Qompass AI Diver Native Ansible Debug Adapter Configuration
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
---@source https://github.com/xbglowx/ansibug
---@source https://github.com/ansible/vscode-ansible

--- Ansible playbook debugging via ansibug.
---
--- Plain-language version: this module finds the `ansibug` program (the
--- Ansible debugger) and hands it to Neovim as a stdio debug adapter. It
--- offers recipes to launch a playbook (optionally with `-i` inventory) or
--- attach to a playbook that is already running.
---@module 'dap.ansible'

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local levels = vim.log.levels

local M = {}

local SOURCE = 'ansibug'
local PROBE_TIMEOUT_MS = 5000

---@type string[]
local ROOT_MARKERS = {
    'ansible.cfg',
    'inventory',
    'inventories',
    'site.yml',
    '.git',
}

---@type string[]
local WELL_KNOWN_PATHS = {
    fn.expand('~/.local/bin/ansibug'),
    '/usr/local/bin/ansibug',
    '/usr/bin/ansibug',
}

---@class AnsibleState
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
local function find_ansibug()
    if state.adapter_path ~= nil then
        return state.adapter_path
    end

    local candidates = {}

    local configured = vim.env.NVIM_ANSIBUG_PATH

    if nonempty_string(configured) then
        candidates[#candidates + 1] = normalize(fn.expand(configured))
    end

    local global = vim.g.ansibug_path

    if nonempty_string(global) then
        candidates[#candidates + 1] = normalize(fn.expand(global))
    end

    local on_path = fn.exepath('ansibug')

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

---@return string?
local function ansibug_version()
    local path = find_ansibug()

    if path == nil then
        return nil
    end

    local result = system({ path, '--version' })

    if result == nil or result.code ~= 0 or type(result.stdout) ~= 'string' then
        return nil
    end

    return trim(result.stdout:match('[^\r\n]*') or '')
end

---@return string
local function adapter_command()
    local path = find_ansibug()

    if path ~= nil then
        return path
    end

    --
    -- Keep the adapter structurally valid when ansibug is missing.
    -- setup() warns before any session is attempted.
    --
    return 'ansibug'
end

---@param default string
---@return string?
local function prompt_playbook(default)
    local input = fn.input('Playbook: ', default, 'file')

    if input == '' then
        return nil
    end

    local path = normalize(fn.expand(input))

    if vim.fn.filereadable(path) ~= 1 then
        notify(('playbook not readable: %s'):format(path), levels.ERROR)

        return nil
    end

    return path
end

---@param default string
---@return string?
local function prompt_inventory(default)
    local input = fn.input('Inventory: ', default, 'file')

    if input == '' then
        return nil
    end

    return normalize(fn.expand(input))
end

---@param default string
---@return string
local function default_playbook(default)
    local filename = buffer_filename()

    if filename ~= '' and filename:match('%.ya?ml$') ~= nil then
        return filename
    end

    return default
end

---@type table
M.adapter = {
    name = SOURCE,
    type = 'executable',
    command = adapter_command(),
    args = {
        'dap',
        '--temp-dir',
        fn.stdpath('cache') .. '/ansibug',
    },
    options = {
        source_filetype = 'yaml.ansible',
    },
}

---@type table<string, table[]>
M.configurations = {
    ['yaml.ansible'] = {
        {
            name = 'Ansible: Debug Current Playbook',
            type = SOURCE,
            request = 'launch',
            playbook = function()
                return prompt_playbook(default_playbook(project_root() .. '/site.yml'))
            end,
            args = function()
                --
                -- ansibug has no `inventory` launch field; the inventory
                -- reaches ansible-playbook through `args` (-i).
                --
                local inventory = prompt_inventory(project_root() .. '/inventory')

                if inventory == nil then
                    return {}
                end

                return { '-i', inventory }
            end,
            cwd = function()
                return project_root()
            end,
        },
        {
            name = 'Ansible: Debug Playbook (Step Into Roles)',
            type = SOURCE,
            request = 'launch',
            playbook = function()
                return prompt_playbook(default_playbook(project_root() .. '/site.yml'))
            end,
            args = function()
                local inventory = prompt_inventory(project_root() .. '/inventory')

                if inventory == nil then
                    return {}
                end

                return { '-i', inventory }
            end,
            cwd = function()
                return project_root()
            end,
        },
        {
            name = 'Ansible: Attach to Running Playbook',
            type = SOURCE,
            request = 'attach',
            processId = function()
                local input = fn.input('Process ID: ')

                if input == '' then
                    return nil
                end

                local pid = tonumber(input)

                if pid == nil or pid < 1 or pid % 1 ~= 0 then
                    notify('process ID must be a positive integer', levels.ERROR)

                    return nil
                end

                return math.floor(pid)
            end,
        },
    },

    yaml = {},
}

local function check_health()
    local path = find_ansibug()
    local version = ansibug_version()

    local messages = {
        'Ansible DAP (ansibug)',
        '',
        'executable: ' .. (path or 'not found'),
        'version: ' .. (version or 'unknown'),
    }

    if path == nil then
        messages[#messages + 1] = ''
        messages[#messages + 1] = 'install ansibug (pipx install ansibug) or set:'
        messages[#messages + 1] = 'NVIM_ANSIBUG_PATH=/path/to/ansibug'
    end

    notify(table.concat(messages, '\n'), path ~= nil and levels.INFO or levels.WARN)
end

---@type table<string, DebugCommand>
M.commands = {
    AnsibleCheck = {
        callback = function()
            check_health()
        end,
        desc = 'Check Ansible DAP configuration',
    },

    AnsibleDebugPlaybook = {
        callback = function()
            local template = M.configurations['yaml.ansible'][1]

            if template == nil then
                return
            end

            local playbook = template.playbook()

            if playbook == nil then
                notify('No playbook selected.', levels.WARN)

                return
            end

            require('dap').run({
                name = template.name,
                type = template.type,
                request = template.request,
                playbook = playbook,
                args = template.args(),
                cwd = template.cwd(),
            })
        end,
        desc = 'Debug an Ansible playbook with ansibug',
    },
}

---@type table<string, DebugMapping>
M.mappings = {
    ansible_check = {
        lhs = '<leader>dAc',
        mode = 'n',
        rhs = function()
            check_health()
        end,
        desc = 'Ansible DAP: Check configuration',
    },

    ansible_debug_playbook = {
        lhs = '<leader>dAp',
        mode = 'n',
        rhs = function()
            local cmd = M.commands.AnsibleDebugPlaybook

            if cmd ~= nil and type(cmd.callback) == 'function' then
                cmd.callback()
            end
        end,
        desc = 'Ansible DAP: Debug playbook',
    },
}

---@param opts? table user overrides; honours `opts.ansibug_path`
function M.setup(opts)
    opts = opts or {}

    if nonempty_string(opts.ansibug_path) then
        state.adapter_path = normalize(fn.expand(opts.ansibug_path))
    end

    local path = find_ansibug()

    if path == nil then
        vim.schedule(function()
            notify(
                table.concat({
                    'ansibug was not found.',
                    '',
                    'Install with: pipx install ansibug',
                    'Or set: NVIM_ANSIBUG_PATH=/path/to/ansibug',
                }, '\n'),
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
    return find_ansibug()
end

return M
