-- #################################################################
-- ~/.config/nvim/lua/dap/lldb.lua
-- Qompass AI Diver Native LLDB DAP Foundation Configuration
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
---@source https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap
---@source https://lldb.llvm.org/

--- Reusable LLDB DAP foundation for compiled languages.
---
--- Plain-language version: this module finds the `lldb-dap` debugger program,
--- checks its version, and hands out ready-made debug recipes (launch, attach,
--- core dump, remote) that other language modules reuse instead of copying the
--- same logic. It serves C, C++, Objective-C, Objective-C++, assembly, and
--- Crystal. It needs `lldb-dap` installed (LLVM 17 or newer recommended).
---@module 'dap.lldb'

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local uv = vim.uv
local levels = vim.log.levels

local M = {}

local SOURCE = 'lldb-dap'
local PROBE_TIMEOUT_MS = 5000

---@type string[]
local ROOT_MARKERS = {
    'compile_commands.json',
    'CMakeLists.txt',
    'CMakePresets.json',
    'meson.build',
    'Makefile',
    'makefile',
    'build.ninja',
    '.git',
}

---@type string[]
local FILETYPES = {
    'c',
    'cpp',
    'objc',
    'objcpp',
    'asm',
    'crystal',
}

---@type string[]
local WELL_KNOWN_PATHS = {
    '/usr/bin/lldb-dap',
    '/opt/homebrew/opt/llvm/bin/lldb-dap',
    '/usr/local/opt/llvm/bin/lldb-dap',
}

---@class LldbFoundationState
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
---@param env? table<string, string> extra environment for the probe
---@return vim.SystemCompleted?
local function system(command, env)
    local ok, result = pcall(function()
        return vim.system(command, {
            text = true,
            env = env,
        }):wait(PROBE_TIMEOUT_MS)
    end)

    if not ok then
        return nil
    end

    return result
end

---@type table<string, table<string, string>|false>
local adapter_env_cache = {}

---Directory holding the libpython an lldb-dap binary needs, or nil.
---
---Some lldb-dap builds link libpython without shipping it. When the
---binary fails to start because of a missing libpython, this searches
---the uv-managed Python installs for a matching shared library. The
---result is cached per binary path. Returns nil when the binary runs
---fine on its own or no matching library is found.
---@param path string lldb-dap binary
---@return string?
local function missing_libpython_dir(path)
    local probe = system({ path, '--version' })

    if probe ~= nil and probe.code == 0 then
        return nil
    end

    local stderr = probe ~= nil and type(probe.stderr) == 'string' and probe.stderr or ''

    if not stderr:find('libpython', 1, true) then
        return nil
    end

    local home = vim.env.HOME or ''

    for _, version in ipairs({ '3.14', '3.15', '3.13', '3.12', '3.11' }) do
        local pattern = home
            .. '/.local/share/uv/python/cpython-'
            .. version
            .. '*/lib/libpython'
            .. version
            .. '.so.1.0'
        local matches = fn.glob(pattern, false, true)

        if #matches > 0 then
            return fn.fnamemodify(matches[1], ':h')
        end
    end

    return nil
end

---Environment patch that lets this lldb-dap binary start, or nil when
---no patch is needed. Merges with the current process environment so
---PATH, HOME and friends survive; only LD_LIBRARY_PATH is extended.
---@param path string lldb-dap binary
---@return table<string, string>?
local function adapter_env(path)
    local cached = adapter_env_cache[path]

    if cached ~= nil then
        if cached == false then
            return nil
        end

        return cached
    end

    local dir = missing_libpython_dir(path)
    ---@type table<string, string>|false
    local env = false

    if dir ~= nil then
        env = vim.fn.environ()
        local current = env.LD_LIBRARY_PATH

        if type(current) == 'string' and current ~= '' then
            env.LD_LIBRARY_PATH = dir .. ':' .. current
        else
            env.LD_LIBRARY_PATH = dir
        end
    end

    adapter_env_cache[path] = env

    if env == false then
        return nil
    end

    return env
end

---@return string?
local function xcrun_lldb_dap()
    if fn.has('mac') ~= 1 or fn.executable('xcrun') ~= 1 then
        return nil
    end

    local result = system({ 'xcrun', '-f', 'lldb-dap' })

    if result == nil or result.code ~= 0 then
        return nil
    end

    local path = trim(result.stdout)

    if executable(path) then
        return fs.normalize(path)
    end

    return nil
end

---@return string?
local function find_lldb_dap()
    if state.adapter_path ~= nil then
        return state.adapter_path
    end

    --
    -- Explicit overrides win: environment first, then vim.g.
    --
    local candidates = {}

    local configured = vim.env.NVIM_LLDB_DAP

    if nonempty_string(configured) then
        candidates[#candidates + 1] = normalize(fn.expand(configured))
    end

    local global = vim.g.lldb_dap_path

    if nonempty_string(global) then
        candidates[#candidates + 1] = normalize(fn.expand(global))
    end

    local on_path = fn.exepath('lldb-dap')

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

    local xcrun = xcrun_lldb_dap()

    if xcrun ~= nil then
        state.adapter_path = xcrun

        return xcrun
    end

    return nil
end

---@param path string
---@return string?
local function lldb_dap_version(path)
    local result = system({ path, '--version' }, adapter_env(path))

    if result == nil or result.code ~= 0 or type(result.stdout) ~= 'string' then
        return nil
    end

    --
    -- Typical output: "lldb version 19.1.7".
    --
    local version = result.stdout:match('lldb version (%d+%.%d+%.?%d*)')

    if version ~= nil then
        return version
    end

    return trim(result.stdout:match('[^\r\n]*') or '')
end

---@return table?
function M.resolve_adapter()
    local path = find_lldb_dap()

    if path == nil then
        return nil
    end

    return {
        name = SOURCE,
        type = 'executable',
        command = path,
        args = {},
        options = {
            env = adapter_env(path),
        },
    }
end

---@return string
local function adapter_command()
    local path = find_lldb_dap()

    if path ~= nil then
        return path
    end

    --
    -- Keep the adapter structurally valid when lldb-dap is missing.
    -- setup() warns before any session is attempted.
    --
    return 'lldb-dap'
end

---@return string[]
local function prompt_args()
    local input = fn.input('Program arguments: ')

    if input == '' then
        return {}
    end

    --
    -- shellsplit handles quoted arguments but never runs a shell.
    --
    return fn.shellsplit(input)
end

---@param value string
---@return integer?
local function prompt_pid(value)
    local input = fn.input(value)

    if input == '' then
        return nil
    end

    local pid = tonumber(input)

    if pid == nil or pid < 1 or pid % 1 ~= 0 then
        notify('process ID must be a positive integer', levels.ERROR)

        return nil
    end

    return math.floor(pid)
end

---@param default string
---@return string?
local function prompt_program(default)
    local input = fn.input('Program: ', default, 'file')

    if input == '' then
        return nil
    end

    local path = normalize(fn.expand(input))
    local stat = uv.fs_stat(path)

    if stat == nil or stat.type ~= 'file' then
        notify(('not a file: %s'):format(path), levels.ERROR)

        return nil
    end

    return path
end

---@param opts table
---@return table?, string?
function M.build_launch(opts)
    opts = opts or {}

    if not nonempty_string(opts.program) then
        return nil, 'build_launch requires opts.program'
    end

    if opts.args ~= nil and type(opts.args) ~= 'table' then
        return nil, 'build_launch requires opts.args to be a list of strings'
    end

    if opts.cwd ~= nil and not nonempty_string(opts.cwd) then
        return nil, 'build_launch requires opts.cwd to be a non-empty string'
    end

    local config = {
        name = opts.name or 'LLDB: Launch',
        type = SOURCE,
        request = 'launch',
        program = opts.program,
        args = opts.args or {},
        cwd = opts.cwd or project_root(),
        stopOnEntry = opts.stop_on_entry == true,
        console = 'internalConsole',
    }

    if type(opts.env) == 'table' then
        config.env = opts.env
    end

    if type(opts.source_map) == 'table' then
        --
        -- lldb-dap maps remote/foreign source paths onto local ones.
        --
        config.sourceMap = opts.source_map
    end

    return config
end

---@param opts table
---@return table?, string?
function M.build_attach(opts)
    opts = opts or {}

    if type(opts.pid) ~= 'number' or opts.pid < 1 or opts.pid % 1 ~= 0 then
        return nil, 'build_attach requires opts.pid to be a positive integer'
    end

    return {
        name = opts.name or ('LLDB: Attach %d'):format(opts.pid),
        type = SOURCE,
        request = 'attach',
        pid = math.floor(opts.pid),
    }
end

---@param opts table
---@return table?, string?
function M.build_core(opts)
    opts = opts or {}

    if not nonempty_string(opts.program) then
        return nil, 'build_core requires opts.program'
    end

    if not nonempty_string(opts.core_file) then
        return nil, 'build_core requires opts.core_file'
    end

    return {
        name = opts.name or 'LLDB: Core File',
        type = SOURCE,
        request = 'attach',
        program = opts.program,
        coreFile = opts.core_file,
    }
end

---@param opts table
---@return table?, string?
function M.build_remote(opts)
    opts = opts or {}

    if not nonempty_string(opts.program) then
        return nil, 'build_remote requires opts.program'
    end

    if not nonempty_string(opts.host) then
        return nil, 'build_remote requires opts.host'
    end

    if type(opts.port) ~= 'number' or opts.port < 1 or opts.port > 65535 or opts.port % 1 ~= 0 then
        return nil, 'build_remote requires opts.port to be an integer in 1..65535'
    end

    if opts.host ~= '127.0.0.1' and opts.host ~= 'localhost' and opts.host ~= '::1' then
        --
        -- lldb-dap remote attach opens a debugger session against another
        -- machine. Non-loopback targets need an explicit SSH tunnel; refuse
        -- to guess one silently.
        --
        return nil, 'refusing non-loopback remote host without an SSH tunnel: ' .. opts.host
    end

    return {
        name = opts.name or ('LLDB: Remote %s:%d'):format(opts.host, opts.port),
        type = SOURCE,
        request = 'attach',
        program = opts.program,
        ['gdb-remote-host'] = opts.host,
        ['gdb-remote-port'] = opts.port,
    }
end

---@return table[]
local function base_configurations()
    return {
        {
            name = 'LLDB: Launch Program',
            type = SOURCE,
            request = 'launch',
            program = function()
                return prompt_program(project_root() .. '/')
            end,
            args = prompt_args,
            cwd = function()
                return project_root()
            end,
            stopOnEntry = false,
            console = 'internalConsole',
        },
        {
            name = 'LLDB: Launch Program (Stop on Entry)',
            type = SOURCE,
            request = 'launch',
            program = function()
                return prompt_program(project_root() .. '/')
            end,
            args = prompt_args,
            cwd = function()
                return project_root()
            end,
            stopOnEntry = true,
            console = 'internalConsole',
        },
        {
            name = 'LLDB: Attach to Process',
            type = SOURCE,
            request = 'attach',
            pid = function()
                return prompt_pid('Process ID: ')
            end,
        },
        {
            name = 'LLDB: Inspect Core File',
            type = SOURCE,
            request = 'attach',
            program = function()
                return prompt_program(project_root() .. '/')
            end,
            coreFile = function()
                local input = fn.input('Core file: ', project_root() .. '/', 'file')

                if input == '' then
                    return nil
                end

                return normalize(fn.expand(input))
            end,
        },
    }
end

---@type table
M.adapter = {
    name = SOURCE,
    type = 'executable',
    command = adapter_command(),
    args = {},
    options = {
        source_filetype = 'c',
    },
}

---@type table<string, table[]>
M.configurations = {}

for _, filetype in ipairs(FILETYPES) do
    M.configurations[filetype] = base_configurations()
end

local function check_health()
    local path = find_lldb_dap()
    local version = path ~= nil and lldb_dap_version(path) or nil

    local messages = {
        'LLDB DAP foundation',
        '',
        'executable: ' .. (path or 'not found'),
        'version: ' .. (version or 'unknown'),
        'serves: ' .. table.concat(FILETYPES, ', '),
    }

    if path == nil then
        messages[#messages + 1] = ''
        messages[#messages + 1] = 'install lldb (provides lldb-dap), or set:'
        messages[#messages + 1] = 'NVIM_LLDB_DAP=/path/to/lldb-dap'
    end

    notify(table.concat(messages, '\n'), path ~= nil and levels.INFO or levels.WARN)
end

---@type table<string, DebugCommand>
M.commands = {
    LldbCheck = {
        callback = function()
            check_health()
        end,
        desc = 'Check LLDB DAP foundation configuration',
    },

    LldbVersion = {
        callback = function()
            local path = find_lldb_dap()

            if path == nil then
                notify('lldb-dap not found', levels.WARN)

                return
            end

            notify(('lldb-dap %s at %s'):format(lldb_dap_version(path) or 'unknown', path))
        end,
        desc = 'Show lldb-dap version',
    },
}

---@type table<string, DebugMapping>
M.mappings = {
    lldb_check = {
        lhs = '<leader>dLc',
        mode = 'n',
        rhs = function()
            check_health()
        end,
        desc = 'LLDB DAP: Check configuration',
    },
}

---@param opts? table user overrides; honours `opts.lldb_dap_path`
function M.setup(opts)
    opts = opts or {}

    if nonempty_string(opts.lldb_dap_path) then
        state.adapter_path = normalize(fn.expand(opts.lldb_dap_path))
    end

    local path = find_lldb_dap()

    if path == nil then
        vim.schedule(function()
            notify(
                table.concat({
                    'lldb-dap was not found.',
                    '',
                    'Install LLVM lldb (17+) or set:',
                    'NVIM_LLDB_DAP=/path/to/lldb-dap',
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
    M.adapter.options.env = adapter_env(path)
end

---@return string?
function M.adapter_path()
    return find_lldb_dap()
end

---@return string?
function M.version()
    local path = find_lldb_dap()

    if path == nil then
        return nil
    end

    return lldb_dap_version(path)
end

return M
