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

-- Bounds for the role-entry breakpoint seeding scan: playbooks and role
-- task files are user-authored YAML; cap how much we read.
local ROLE_SCAN_MAX_LINES = 2000
local TASK_SCAN_MAX_LINES = 2000

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

---@param path string
---@param max_lines integer
---@return string[]? lines, string? err
local function read_lines(path, max_lines)
    local handle, open_err = io.open(path, 'r')

    if handle == nil then
        return nil, ('cannot read %s: %s'):format(path, open_err or 'unknown error')
    end

    local lines = {}
    local count = 0

    for line in handle:lines() do
        count = count + 1

        if count > max_lines then
            break
        end

        lines[#lines + 1] = line
    end

    handle:close()

    return lines, nil
end

---@param value string
---@return string unquoted value
local function unquote(value)
    local quoted = value:match("^'([^']*)'$") or value:match('^"([^"]*)"$')

    if quoted ~= nil then
        return quoted
    end

    return value
end

---Extract a role name from one `roles:` list item.
---
---Plain-language version: a playbook lists its roles in a few spellings --
---`- web`, `- { role: web }`, `- role: web`, `- 'web'`. This reads one
---list item and pulls out just the role's name, or gives up (nil) when the
---item is something fancier like a dict with conditionals.
---@param item string text after the `- ` of a roles list item
---@return string? role_name
local function parse_role_name(item)
    local text = unquote(trim(item))

    -- Dict forms: `- { role: web }` and `- role: web`.
    local dict_role = text:match('^%{%s*role%s*:%s*([^,}%s]+)') or text:match('^role%s*:%s*([%w_.-]+)%s*$')

    if dict_role ~= nil then
        return unquote(dict_role)
    end

    -- Plain form: `- web` (quotes already stripped above).
    if text:match('^[%w_.-]+$') ~= nil then
        return text
    end

    return nil
end

---Collect every role referenced by `roles:` sections in a playbook.
---
---Plain-language version: walks the playbook top to bottom; whenever it
---finds a `roles:` line it reads the indented `- ...` items under it until
---the indentation drops back. Inline `roles: [a, b]` lists are not
---supported (rare in playbooks; documented, not silently misread).
---@param playbook_path string absolute path of the playbook
---@return string[]? roles, string? err
local function playbook_roles(playbook_path)
    local lines, err = read_lines(playbook_path, ROLE_SCAN_MAX_LINES)

    if lines == nil then
        return nil, err
    end

    local roles = {}
    local i = 1

    while i <= #lines do
        local indent = lines[i]:match('^(%s*)roles:%s*$')

        if indent == nil then
            i = i + 1
        else
            local base_indent = #indent
            i = i + 1

            while i <= #lines do
                local item_line = lines[i]

                if item_line:match('^%s*$') or item_line:match('^%s*#') then
                    i = i + 1
                else
                    local item_indent = #(item_line:match('^(%s*)') or '')

                    if item_indent <= base_indent then
                        break
                    end

                    local item = item_line:match('^%s*%-%s+(.-)%s*$')

                    if item ~= nil then
                        local name = parse_role_name(item)

                        if name ~= nil then
                            roles[#roles + 1] = name
                        end
                    end

                    i = i + 1
                end
            end
        end
    end

    return roles, nil
end

---Find the first executable task in a role's tasks file.
---
---Plain-language version: the first thing a role actually *does* is the
---first top-level `- ...` entry in `tasks/main.yml` (skipping blank lines,
---comments, and the `---` header). That is where the entry breakpoint goes.
---@param tasks_path string absolute path of tasks/main.yml
---@return integer? line 1-based line number of the first task
---@return string? err reason when no task is found
local function first_task_line(tasks_path)
    local lines, err = read_lines(tasks_path, TASK_SCAN_MAX_LINES)

    if lines == nil then
        return nil, err
    end

    for idx, line in ipairs(lines) do
        local ignorable = line:match('^%s*$') or line:match('^%s*#') or line:match('^%s*---%s*$')
        if not ignorable and line:match('^%-%s+%S') then
            return idx, nil
        end
        -- Otherwise not a task: keep scanning.
    end

    return nil, 'no executable task found'
end

---@param path string absolute path to load
---@return integer? bufnr
---@return string? err
local function ensure_loaded_buffer(path)
    local bufnr = fn.bufadd(path)

    if bufnr == nil or bufnr < 1 then
        return nil, ('cannot create buffer for %s'):format(path)
    end

    fn.bufload(bufnr)

    return bufnr, nil
end

---Seed a normal DAP breakpoint on the first task of each role the playbook uses.
---
---Plain-language version: ansibug cannot step *into* a role, so this cheats
---honestly -- before launching, it puts a plain breakpoint on the first
---task of every role (`roles/<role>/tasks/main.yml`). When the debugger
---reaches a role it stops at its front door, which is what "step into
---roles" should have felt like. Roles are resolved next to the playbook;
---anything unresolvable is reported out loud, never silently skipped. The
---playbook itself is never modified.
---@param playbook_path string absolute path of the playbook to launch
---@return table? result `{ seeded = {...}, unresolved = {...} }`
---@return string? err when the playbook cannot be read at all
function M.seed_role_entry_breakpoints(playbook_path)
    if not nonempty_string(playbook_path) then
        return nil, 'playbook path must be a non-empty string'
    end

    local playbook = normalize(playbook_path)

    if fn.filereadable(playbook) ~= 1 then
        return nil, ('playbook not readable: %s'):format(playbook)
    end

    local roles, roles_err = playbook_roles(playbook)

    if roles == nil then
        return nil, roles_err
    end

    local playbook_dir = fs.dirname(playbook)
    local breakpoints = require('dap.breakpoints')
    local seeded = {}
    local unresolved = {}

    for _, role in ipairs(roles) do
        -- Role names become path segments: reject anything that could
        -- escape the roles directory.
        if role:find('%.%.', 1, true) ~= nil or role:find('/', 1, true) ~= nil then
            unresolved[#unresolved + 1] = { role = role, reason = 'unsafe role name' }
        else
            local tasks_path = fs.normalize(playbook_dir .. '/roles/' .. role .. '/tasks/main.yml')
            local line, line_err = first_task_line(tasks_path)

            if line == nil then
                unresolved[#unresolved + 1] = { role = role, reason = line_err }
            else
                local bufnr, buf_err = ensure_loaded_buffer(tasks_path)

                if bufnr == nil then
                    unresolved[#unresolved + 1] = { role = role, reason = buf_err }
                else
                    local ok, set_err = pcall(breakpoints.set, {}, bufnr, line)

                    if not ok then
                        unresolved[#unresolved + 1] =
                            { role = role, reason = ('breakpoint failed: %s'):format(set_err) }
                    else
                        seeded[#seeded + 1] = { role = role, file = tasks_path, line = line }
                    end
                end
            end
        end
    end

    if #unresolved > 0 then
        local reasons = {}

        for _, entry in ipairs(unresolved) do
            reasons[#reasons + 1] = ('%s (%s)'):format(entry.role, entry.reason)
        end

        notify(
            ('role-entry breakpoints: %d unresolved: %s'):format(#unresolved, table.concat(reasons, '; ')),
            levels.WARN
        )
    end

    return { seeded = seeded, unresolved = unresolved }, nil
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
            name = 'Ansible: Debug Playbook (Role-Entry Breakpoints)',
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

    AnsibleDebugPlaybookRoles = {
        callback = function()
            local template = M.configurations['yaml.ansible'][2]

            if template == nil then
                return
            end

            local playbook = template.playbook()

            if playbook == nil then
                notify('No playbook selected.', levels.WARN)

                return
            end

            --
            -- ansibug cannot step into roles: seed a plain breakpoint on
            -- each role's first task, then launch normally. Unresolved
            -- roles are reported by seed_role_entry_breakpoints; the
            -- launch still proceeds so a partial seed never blocks a run.
            --
            local result, err = M.seed_role_entry_breakpoints(playbook)

            if result == nil then
                notify(('role breakpoint seeding failed: %s'):format(err), levels.ERROR)

                return
            end

            notify(('seeded %d role-entry breakpoint(s)'):format(#result.seeded), levels.INFO)

            require('dap').run({
                name = template.name,
                type = template.type,
                request = template.request,
                playbook = playbook,
                args = template.args(),
                cwd = template.cwd(),
            })
        end,
        desc = 'Seed role-entry breakpoints, then debug the playbook with ansibug',
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

    ansible_debug_playbook_roles = {
        lhs = '<leader>dAr',
        mode = 'n',
        rhs = function()
            local cmd = M.commands.AnsibleDebugPlaybookRoles

            if cmd ~= nil and type(cmd.callback) == 'function' then
                cmd.callback()
            end
        end,
        desc = 'Ansible DAP: Debug playbook with role-entry breakpoints',
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
