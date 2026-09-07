-- #################################################################
-- /qompassai/Diver/lua/dap/lua.lua
-- Qompass AI Diver Native Lua Debug Adapter Configuration
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI, All rights reserved
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

local api = vim.api
local env = vim.env
local fn = vim.fn
local fs = vim.fs
local levels = vim.log.levels
local uv = vim.uv

local task = require('config.core.async')

local M = {}

local ADAPTER_NAME = 'lua-debug'
local NOTIFY_PREFIX = '[lua-debug] '
local PROCESS_TIMEOUT = 5000
local VALIDATION_TIMEOUT = 5000

---@type string[]
local ROOT_MARKERS = {
    '.git',
    '.luacheckrc',
    '.luarc.json',
    '.luarc.jsonc',
    '.stylua.toml',
    'selene.toml',
    'stylua.toml',
}

---@type string[]
local LUA_EXECUTABLES = {
    'lua5.4',
    'lua5.3',
    'lua5.2',
    'lua5.1',
    'lua',
    'luajit',
}

---@type string[]
local LUA_DEBUG_ADAPTERS = {
    'lua-debug',
    'lua-debug-adapter',
}

---@type table<string, boolean>
local DEBUGGABLE_PROCESS_NAMES = {
    lua = true,
    ['lua5.1'] = true,
    ['lua5.2'] = true,
    ['lua5.3'] = true,
    ['lua5.4'] = true,
    luajit = true,
    nvim = true,
}

---@class QompassLuaDebugProcess
---@field command string
---@field executable string
---@field pid integer

---@type table<string, vim.async.Task>
local active_tasks = {}

---@type QompassLuaDebugProcess?
local selected_process = nil

---@param message string
---@param level? integer
local function notify(message, level)
    vim.notify(
        NOTIFY_PREFIX .. message,
        level or levels.INFO
    )
end

---@param path string
---@return boolean
local function exists(path)
    return uv.fs_stat(path) ~= nil
end

---@param path string
---@return boolean
local function is_file(path)
    local stat = uv.fs_stat(path)

    return stat ~= nil and stat.type == 'file'
end

---@param command string
---@return boolean
local function executable(command)
    if command == '' then
        return false
    end

    if command:find('/', 1, true) ~= nil then
        return is_file(command) and uv.fs_access(command, 'X')
    end

    return fn.executable(command) == 1
end

---@param command string
---@return string?
local function executable_path(command)
    if not executable(command) then
        return nil
    end

    if command:find('/', 1, true) ~= nil then
        return fs.normalize(command)
    end

    local path = fn.exepath(command)

    if path == '' then
        return command
    end

    return fs.normalize(path)
end

---@param path string
---@return string
local function normalize(path)
    if path == '' then
        return ''
    end

    return fs.normalize(
        fn.fnamemodify(path, ':p')
    )
end

---@param bufnr? integer
---@return string
local function filename(bufnr)
    bufnr = bufnr or api.nvim_get_current_buf()

    return normalize(
        api.nvim_buf_get_name(bufnr)
    )
end

---@param bufnr? integer
---@return string
local function root(bufnr)
    local current_filename = filename(bufnr)

    if current_filename == '' then
        return normalize(fn.getcwd())
    end

    local detected_root = fs.root(
        current_filename,
        ROOT_MARKERS
    )

    if
        type(detected_root) == 'string'
        and detected_root ~= ''
    then
        return normalize(detected_root)
    end

    return normalize(
        fs.dirname(current_filename)
            or fn.getcwd()
    )
end

---@param candidates string[]
---@return string?
local function first_executable(candidates)
    for index = 1, #candidates do
        local candidate = candidates[index]

        if executable(candidate) then
            return candidate
        end
    end

    return nil
end

---@return string?
local function lua_executable()
    local configured = env.LUA

    if
        type(configured) == 'string'
        and configured ~= ''
        and executable(configured)
    then
        return configured
    end

    return first_executable(
        LUA_EXECUTABLES
    )
end

---@return string?
local function lua_debug_adapter()
    local configured = env.LUA_DEBUG_ADAPTER

    if
        type(configured) == 'string'
        and configured ~= ''
        and executable(configured)
    then
        return configured
    end

    return first_executable(
        LUA_DEBUG_ADAPTERS
    )
end

---@param prompt string
---@return string?
local function prompt_program(prompt)
    local selected_path = fn.input(
        prompt,
        root() .. '/',
        'file'
    )

    if selected_path == '' then
        return nil
    end

    selected_path = normalize(
        selected_path
    )

    if not is_file(selected_path) then
        notify(
            'Lua program does not exist: '
                .. selected_path,
            levels.ERROR
        )

        return nil
    end

    return selected_path
end

---@return string?
local function current_program()
    local current_file = filename()

    if
        current_file ~= ''
        and is_file(current_file)
    then
        return current_file
    end

    return prompt_program(
        'Lua program: '
    )
end

---@return string?
local function pick_program()
    return prompt_program(
        'Lua program: '
    )
end

---@return string[]
local function program_arguments()
    local input = fn.input(
        'Arguments: '
    )

    if input == '' then
        return {}
    end

    ---@type string[]
    local arguments = {}

    for argument in input:gmatch('%S+') do
        arguments[#arguments + 1] =
            argument
    end

    return arguments
end

---@return table<string, string>
local function environment()
    ---@type table<string, string>
    local variables = {}

    local lua_path = env.LUA_PATH

    if
        type(lua_path) == 'string'
        and lua_path ~= ''
    then
        variables.LUA_PATH =
            lua_path
    end

    local lua_cpath = env.LUA_CPATH

    if
        type(lua_cpath) == 'string'
        and lua_cpath ~= ''
    then
        variables.LUA_CPATH =
            lua_cpath
    end

    return variables
end

---@return integer?
local function prompt_process_id()
    local input = fn.input(
        'Lua process PID: '
    )

    if input == '' then
        return nil
    end

    local pid = tonumber(input)

    if pid == nil then
        notify(
            'Invalid process ID',
            levels.WARN
        )

        return nil
    end

    pid = math.floor(pid)

    if pid <= 0 then
        notify(
            'Process ID must be greater than zero',
            levels.WARN
        )

        return nil
    end

    return pid
end

---@return integer?
local function process_id()
    if selected_process ~= nil then
        return selected_process.pid
    end

    return prompt_process_id()
end

---@return string
local function workspace()
    return root()
end

---@return string?
local function runtime()
    local runtime_executable =
        lua_executable()

    if runtime_executable == nil then
        notify(
            'Lua interpreter not found',
            levels.ERROR
        )

        return nil
    end

    return runtime_executable
end

---@return string?
local function neovim_runtime()
    local path = fn.exepath('nvim')

    if path == '' then
        notify(
            'Neovim executable not found',
            levels.ERROR
        )

        return nil
    end

    return normalize(path)
end

---@return string?
local function neovim_config()
    local config_path =
        fn.stdpath('config')

    if
        type(config_path) ~= 'string'
        or config_path == ''
    then
        return nil
    end

    return normalize(config_path)
end

---@return string[]
local function neovim_config_arguments()
    local config_path =
        neovim_config()

    if config_path == nil then
        return {
            '--headless',
        }
    end

    local init_path = fs.joinpath(
        config_path,
        'init.lua'
    )

    if not is_file(init_path) then
        return {
            '--headless',
        }
    end

    return {
        '--headless',
        '-u',
        init_path,
    }
end

---@param command string
---@return string
local function process_basename(command)
    local path =
        command:match('^%s*([^%s]+)')
        or ''

    if path == '' then
        return ''
    end

    return fs.basename(path)
end

---@param line string
---@return QompassLuaDebugProcess?
local function parse_process(line)
    local pid_text, command =
        line:match(
            '^%s*(%d+)%s+(.+)$'
        )

    if
        pid_text == nil
        or command == nil
    then
        return nil
    end

    local pid = tonumber(pid_text)

    if
        pid == nil
        or pid <= 0
        or pid == uv.os_getpid()
    then
        return nil
    end

    local name =
        process_basename(command)

    if not DEBUGGABLE_PROCESS_NAMES[name] then
        return nil
    end

    return {
        command = command,
        executable = name,
        pid = pid,
    }
end

---@return vim.async.Task
local function discover_processes()
    return task.run(
        'lua-debug.process-discovery',
        function()
            local result =
                task.await(
                    task.system({
                        'ps',
                        '-eo',
                        'pid=,args=',
                    }, {
                        text = true,
                    })
                )

            if result.code ~= 0 then
                error(
                    result.stderr ~= ''
                            and result.stderr
                        or (
                            'ps exited with code %d'
                        ):format(result.code),
                    0
                )
            end

            ---@type QompassLuaDebugProcess[]
            local processes = {}

            for line in result.stdout:gmatch(
                '[^\r\n]+'
            ) do
                local process =
                    parse_process(line)

                if process ~= nil then
                    processes[
                        #processes + 1
                    ] = process
                end
            end

            table.sort(
                processes,
                function(left, right)
                    if
                        left.executable
                        == right.executable
                    then
                        return left.pid
                            < right.pid
                    end

                    return left.executable
                        < right.executable
                end
            )

            return processes
        end
    )
end

---@return vim.async.Task
local function select_process()
    return task.run(
        'lua-debug.process-select',
        function()
            local discovery =
                discover_processes()

            local processes =
                task.timeout(
                    discovery,
                    PROCESS_TIMEOUT
                )

            if #processes == 0 then
                return nil
            end

            local process =
                task.await(
                    function(done)
                        vim.ui.select(
                            processes,
                            {
                                prompt =
                                    'Lua debug process:',

                                format_item =
                                    function(item)
                                        return (
                                            '%d  [%s]  %s'
                                        ):format(
                                            item.pid,
                                            item.executable,
                                            item.command
                                        )
                                    end,
                            },
                            function(item)
                                done(item)
                            end
                        )
                    end
                )

            return process
        end
    )
end

---@return vim.async.Task
local function validate_adapter()
    return task.run(
        'lua-debug.adapter-validation',
        function()
            local adapter =
                lua_debug_adapter()

            if adapter == nil then
                return false,
                    'Lua debug adapter not found'
            end

            local validation =
                task.system({
                    adapter,
                    '--help',
                }, {
                    text = true,
                })

            local result =
                task.timeout(
                    validation,
                    VALIDATION_TIMEOUT
                )

            if
                result.code ~= 0
                and result.code ~= 1
            then
                return false,
                    result.stderr ~= ''
                            and result.stderr
                        or (
                            '%s exited with code %d'
                        ):format(
                            adapter,
                            result.code
                        )
            end

            return true,
                executable_path(adapter)
                    or adapter
        end
    )
end

---@return vim.async.Task
local function validate_runtime()
    return task.run(
        'lua-debug.runtime-validation',
        function()
            local lua =
                lua_executable()

            if lua == nil then
                return false,
                    'Lua interpreter not found'
            end

            local validation =
                task.system({
                    lua,
                    '-v',
                }, {
                    text = true,
                })

            local result =
                task.timeout(
                    validation,
                    VALIDATION_TIMEOUT
                )

            if result.code ~= 0 then
                return false,
                    result.stderr ~= ''
                            and result.stderr
                        or (
                            '%s exited with code %d'
                        ):format(
                            lua,
                            result.code
                        )
            end

            local version =
                result.stdout ~= ''
                        and result.stdout
                    or result.stderr

            version =
                version:gsub(
                    '%s+$',
                    ''
                )

            return true,
                version ~= ''
                        and version
                    or (
                        executable_path(lua)
                        or lua
                    )
        end
    )
end

---@param name string
local function cancel_task(name)
    local current =
        active_tasks[name]

    if current == nil then
        return
    end

    if not current:completed() then
        current:close()
    end

    active_tasks[name] = nil
end

local function cancel_tasks()
    for name, current in pairs(
        active_tasks
    ) do
        if not current:completed() then
            current:close()
        end

        active_tasks[name] = nil
    end
end

---@param name string
---@param current vim.async.Task
---@param callback? fun(...)
local function observe(
    name,
    current,
    callback
)
    cancel_task(name)

    active_tasks[name] = current

    current:on_complete(
        function(err, ...)
            if
                active_tasks[name]
                == current
            then
                active_tasks[name] = nil
            end

            local results = {
                ...,
            }

            vim.schedule(
                function()
                    if err ~= nil then
                        if tostring(err) ~= 'closed' then
                            notify(
                                (
                                    '%s failed: %s'
                                ):format(
                                    name,
                                    tostring(err)
                                ),
                                levels.ERROR
                            )
                        end

                        return
                    end

                    if callback ~= nil then
                        callback(
                            unpack(
                                results
                            )
                        )
                    end
                end
            )
        end
    )
end

local function show_adapter()
    local adapter =
        lua_debug_adapter()

    if adapter == nil then
        notify(
            'Lua debug adapter not found',
            levels.WARN
        )

        return
    end

    notify(
        executable_path(adapter)
            or adapter
    )
end

local function show_runtime()
    local lua =
        lua_executable()

    if lua == nil then
        notify(
            'Lua interpreter not found',
            levels.WARN
        )

        return
    end

    notify(
        executable_path(lua)
            or lua
    )
end

local function choose_process()
    local current =
        select_process()

    observe(
        'process-select',
        current,
        function(process)
            if process == nil then
                notify(
                    'No Lua or Neovim process selected',
                    levels.INFO
                )

                return
            end

            selected_process =
                process

            notify(
                (
                    'Selected PID %d: %s'
                ):format(
                    process.pid,
                    process.command
                )
            )
        end
    )
end

local function clear_process()
    if selected_process == nil then
        notify(
            'No selected Lua process',
            levels.INFO
        )

        return
    end

    local pid =
        selected_process.pid

    selected_process = nil

    notify(
        (
            'Cleared selected PID %d'
        ):format(pid)
    )
end

local function show_process()
    if selected_process == nil then
        notify(
            'No selected Lua process',
            levels.INFO
        )

        return
    end

    notify(
        (
            '%d  [%s]  %s'
        ):format(
            selected_process.pid,
            selected_process.executable,
            selected_process.command
        )
    )
end

local function check_adapter()
    observe(
        'adapter-validation',
        validate_adapter(),
        function(ok, message)
            if not ok then
                notify(
                    message,
                    levels.WARN
                )

                return
            end

            notify(
                'Adapter OK: '
                    .. message
            )
        end
    )
end

local function check_runtime()
    observe(
        'runtime-validation',
        validate_runtime(),
        function(ok, message)
            if not ok then
                notify(
                    message,
                    levels.WARN
                )

                return
            end

            notify(
                'Runtime OK: '
                    .. message
            )
        end
    )
end

local function check_environment()
    observe(
        'environment-validation',
        task.run(
            'lua-debug.environment-validation',
            function()
                local adapter_task =
                    validate_adapter()

                local runtime_task =
                    validate_runtime()

                local adapter_ok,
                    adapter_message =
                    task.await(
                        adapter_task
                    )

                local runtime_ok,
                    runtime_message =
                    task.await(
                        runtime_task
                    )

                return {
                    adapter = {
                        message =
                            adapter_message,
                        ok =
                            adapter_ok,
                    },

                    runtime = {
                        message =
                            runtime_message,
                        ok =
                            runtime_ok,
                    },
                }
            end
        ),
        function(result)
            local level =
                result.adapter.ok
                    and result.runtime.ok
                    and levels.INFO
                    or levels.WARN

            notify(
                table.concat({
                    (
                        'adapter: %s (%s)'
                    ):format(
                        result.adapter.ok
                                and 'OK'
                            or 'FAIL',
                        result.adapter.message
                    ),

                    (
                        'runtime: %s (%s)'
                    ):format(
                        result.runtime.ok
                                and 'OK'
                            or 'FAIL',
                        result.runtime.message
                    ),
                }, '\n'),
                level
            )
        end
    )
end

M.adapter = {
    command =
        lua_debug_adapter()
        or 'lua-debug',

    name = ADAPTER_NAME,

    type = 'executable',
}

M.configurations = {
    lua = {
        {
            args =
                program_arguments,

            cwd =
                workspace,

            env =
                environment,

            lua =
                runtime,

            name =
                'Lua: Launch current file',

            program =
                current_program,

            request =
                'launch',

            stopOnEntry =
                false,

            type =
                ADAPTER_NAME,
        },

        {
            args =
                program_arguments,

            cwd =
                workspace,

            env =
                environment,

            lua =
                runtime,

            name =
                'Lua: Launch selected file',

            program =
                pick_program,

            request =
                'launch',

            stopOnEntry =
                false,

            type =
                ADAPTER_NAME,
        },

        {
            cwd =
                workspace,

            env =
                environment,

            name =
                'Lua: Attach to process',

            processId =
                process_id,

            request =
                'attach',

            type =
                ADAPTER_NAME,
        },

        {
            args = {
                '--clean',
                '--headless',
                '-u',
                'NONE',
            },

            cwd =
                workspace,

            env =
                environment,

            lua =
                neovim_runtime,

            name =
                'Lua: Launch clean Neovim',

            program =
                current_program,

            request =
                'launch',

            stopOnEntry =
                false,

            type =
                ADAPTER_NAME,
        },

        {
            args =
                neovim_config_arguments,

            cwd =
                workspace,

            env =
                environment,

            lua =
                neovim_runtime,

            name =
                'Lua: Launch Neovim config',

            program =
                current_program,

            request =
                'launch',

            stopOnEntry =
                false,

            type =
                ADAPTER_NAME,
        },
    },
}

M.filetypes = {
    'lua',
}

M.commands = {
    LuaDebugAdapter = {
        callback =
            show_adapter,

        desc =
            'Show Lua debug adapter',
    },

    LuaDebugCheck = {
        callback =
            check_environment,

        desc =
            'Validate Lua debug environment',
    },

    LuaDebugCheckAdapter = {
        callback =
            check_adapter,

        desc =
            'Validate Lua debug adapter',
    },

    LuaDebugCheckRuntime = {
        callback =
            check_runtime,

        desc =
            'Validate Lua runtime',
    },

    LuaDebugProcess = {
        callback =
            choose_process,

        desc =
            'Select Lua debug process',
    },

    LuaDebugProcessClear = {
        callback =
            clear_process,

        desc =
            'Clear selected Lua debug process',
    },

    LuaDebugProcessShow = {
        callback =
            show_process,

        desc =
            'Show selected Lua debug process',
    },

    LuaDebugProgram = {
        callback = function()
            local program =
                pick_program()

            if program ~= nil then
                notify(program)
            end
        end,

        desc =
            'Select Lua debug program',
    },

    LuaDebugRoot = {
        callback = function()
            notify(root())
        end,

        desc =
            'Show Lua debug root',
    },

    LuaDebugRuntime = {
        callback =
            show_runtime,

        desc =
            'Show Lua runtime',
    },
}

---@param _opts? table
function M.setup(_opts)
    local adapter =
        lua_debug_adapter()

    if adapter == nil then
        notify(
            'lua-debug is not available',
            levels.WARN
        )
    else
        M.adapter.command =
            adapter
    end

    if lua_executable() == nil then
        notify(
            'Lua interpreter is not available',
            levels.WARN
        )
    end
end

function M.teardown()
    cancel_tasks()

    selected_process = nil
end

return M