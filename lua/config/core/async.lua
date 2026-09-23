#!/usr/bin/env luajit
---@version JIT
-- #################################################################
-- /qompassai/Diver/lua/config/core/async.lua
-- Native Neovim 0.13+ Async Utilities
-- Copyright (C) 2026, All rights reserved
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
---@source https://neovim.io/doc/user/lua-async.html
---@source https://github.com/neovim/neovim/blob/master/runtime/lua/vim/async.lua
--
-- Design:
--   * passive at require-time;
--   * never require("vim.async") directly;
--   * resolve the public vim.async API only when an operation is requested;
--   * keep LSP startup independent from the experimental async runtime;
--   * bound user-controlled arrays, durations, and retained error output.
-- #################################################################

local M = {}

local unpack_values = unpack

local COMMAND_ARGUMENTS_MAX = 4096
local DURATION_MS_MAX = 2 ^ 32 - 1
local ERROR_MESSAGE_BYTES_MAX = 4096
local SYSTEM_CANCEL_GRACE_MS = 1000
local TASKS_MAX = 4096

---@alias CoreAsyncTaskStatus
---| 'running'
---| 'awaiting'
---| 'normal'
---| 'completed'

-- Deliberately keep method fields broad here.
--
-- The user's LuaLS metadata may lag Neovim 0.13 and previously reported
-- vim.async.Task as undefined. Runtime validation below checks the methods
-- that this module actually depends on without shadowing Neovim's own
-- vim.async overload annotations.
---@class CoreAsyncTask
---@field name? string
---@field close function
---@field completed function
---@field detach function
---@field on_complete function
---@field pwait function
---@field raise_on_error function
---@field status function
---@field traceback function
---@field wait function

---@class CoreAsyncSemaphore
---@field acquire function
---@field release function
---@field with function

---@class CoreAsyncCancelEntry
---@field key any
---@field task CoreAsyncTask

local native_state = {
    attempted = false,
    module = nil,
    error = nil,
}

local REQUIRED_NATIVE_METHODS = {
    'await',
    'checkpoint',
    'is_closing',
    'iter',
    'pawait',
    'run',
    'semaphore',
    'sleep',
    'timeout',
    'wrap',
}

---@param name string
---@param value any
local function assert_callable(name, value)
    assert(vim.is_callable(value), ('%s: expected callable'):format(name))
end

---@param name string
---@param value any
---@param minimum integer
local function assert_integer(name, value, minimum)
    assert(
        type(value) == 'number' and value >= minimum and value <= DURATION_MS_MAX and value % 1 == 0,
        ('%s: expected integer in range %d..%d'):format(name, minimum, DURATION_MS_MAX)
    )
end

---@return table?, string?
local function resolve_native()
    if native_state.attempted then
        return native_state.module, native_state.error
    end

    native_state.attempted = true

    if vim.fn.has('nvim-0.13') ~= 1 then
        native_state.error = 'vim.async requires Neovim 0.13+'
        return nil, native_state.error
    end

    local ok, value = pcall(function()
        return vim.async
    end)

    if not ok then
        native_state.error = ('failed to resolve vim.async: %s'):format(tostring(value))
        return nil, native_state.error
    end

    if type(value) ~= 'table' then
        native_state.error = 'vim.async is unavailable in this Neovim runtime'
        return nil, native_state.error
    end

    for _, method in ipairs(REQUIRED_NATIVE_METHODS) do
        if not vim.is_callable(value[method]) then
            native_state.error = ('vim.async.%s is unavailable'):format(method)
            return nil, native_state.error
        end
    end

    native_state.module = value
    return value, nil
end

---@param level? integer
---@return table
local function native(level)
    local value, err = resolve_native()

    if value ~= nil then
        return value
    end

    error(err or 'vim.async is unavailable', (level or 1) + 1)
end

---@param value any
---@param name? string
---@return CoreAsyncTask
local function assert_task(value, name)
    name = name or 'task'

    local value_type = type(value)

    assert(
        value_type == 'table' or value_type == 'userdata',
        ('%s: expected vim.async task'):format(name)
    )

    ---@cast value CoreAsyncTask
    assert_callable(name .. '.close', value.close)
    assert_callable(name .. '.completed', value.completed)
    assert_callable(name .. '.on_complete', value.on_complete)

    return value
end

---@param command string[]
---@return string[]
local function copy_command(command)
    assert(type(command) == 'table', 'command: expected string array')

    local count = #command

    assert(count > 0, 'command: must not be empty')

    assert(
        count <= COMMAND_ARGUMENTS_MAX,
        ('command: exceeds %d arguments'):format(COMMAND_ARGUMENTS_MAX)
    )

    for key in pairs(command) do
        assert(
            type(key) == 'number' and key % 1 == 0 and key >= 1 and key <= count,
            'command: expected dense string array'
        )
    end

    local copied = {} ---@type string[]

    for index = 1, count do
        local argument = command[index]

        assert(type(argument) == 'string', ('command[%d]: expected string'):format(index))

        assert(
            argument:find('\0', 1, true) == nil,
            ('command[%d]: contains NUL byte'):format(index)
        )

        if index == 1 then
            assert(argument ~= '', 'command[1]: executable must not be empty')
        end

        copied[index] = argument
    end

    return copied
end

---@param opts? vim.SystemOpts
---@return vim.SystemOpts
local function copy_system_options(opts)
    if opts == nil then
        return {
            text = true,
        }
    end

    assert(type(opts) == 'table', 'opts: expected vim.SystemOpts')

    local copied = vim.deepcopy(opts)

    if copied.text == nil then
        copied.text = true
    end

    ---@cast copied vim.SystemOpts
    return copied
end

---@param message string
---@return string
local function truncate_error(message)
    if #message <= ERROR_MESSAGE_BYTES_MAX then
        return message
    end

    return '[output truncated]\n' .. message:sub(-ERROR_MESSAGE_BYTES_MAX)
end

---@param result vim.SystemCompleted
---@param executable string
---@return string
local function command_error(result, executable)
    if result.error then
        return truncate_error(result.error)
    end
    local stderr = type(result.stderr) == 'string' and vim.trim(result.stderr) or ''

    if stderr ~= '' then
        return truncate_error(stderr)
    end

    local stdout = type(result.stdout) == 'string' and vim.trim(result.stdout) or ''

    if stdout ~= '' then
        return truncate_error(stdout)
    end

    if result.signal ~= 0 then
        return ('%s exited with code %d after signal %d'):format(
            executable,
            result.code,
            result.signal
        )
    end

    return ('%s exited with code %d'):format(executable, result.code)
end

---@param process vim.SystemObj
---@param signal string
---@return boolean
local function kill_process(process, signal)
    local ok = pcall(function()
        process:kill(signal)
    end)

    return ok
end

---@async
---@param command string[]
---@param opts vim.SystemOpts
---@return vim.SystemCompleted
local function await_system(command, opts)
    local async = native(2)
    local exited = false
    local closing = false
    local close_callbacks = {} ---@type fun()[]
    local process ---@type vim.SystemObj?

    local function finish_close()
        local callbacks = close_callbacks

        close_callbacks = {}

        for index = 1, #callbacks do
            callbacks[index]()
        end
    end

    ---@param done fun(completed: vim.SystemCompleted)
    ---@return table
    local function start_process(done)
        local spawn_error
        process, spawn_error = M.spawn(command, opts, function(completed)
            exited = true
            done(completed)
            finish_close()
            process = nil
        end)
        if not process then
            error(spawn_error, 0)
        end

        return {
            close = function(_, callback)
                if callback ~= nil then
                    assert_callable('close callback', callback)

                    close_callbacks[#close_callbacks + 1] = callback
                end

                if exited then
                    finish_close()
                    return
                end

                if closing then
                    return
                end

                closing = true

                local active = process

                if active == nil then
                    finish_close()
                    return
                end

                if not kill_process(active, 'sigterm') then
                    if not kill_process(active, 'sigkill') then
                        finish_close()
                    end

                    return
                end

                vim.defer_fn(function()
                    if exited then
                        return
                    end

                    local running = process

                    if running == nil then
                        finish_close()
                        return
                    end

                    if not kill_process(running, 'sigkill') then
                        finish_close()
                    end
                end, SYSTEM_CANCEL_GRACE_MS)
            end,

            is_closing = function()
                return closing or exited
            end,
        }
    end

    local result = async.await(start_process)

    ---@cast result vim.SystemCompleted
    return result
end

---Return whether Neovim's native structured-concurrency API is usable.
---
---Requiring this module never invokes this probe automatically.
---@return boolean
---@return string?
function M.available()
    local value, err = resolve_native()

    return value ~= nil, err
end

---Clear the cached native API probe.
---
---Useful when testing different Neovim 0.13 development builds in one session.
function M.reset_native()
    native_state.attempted = false
    native_state.module = nil
    native_state.error = nil
end

---@param callback_or_name string|function
---@param ... any
---@return CoreAsyncTask
function M.run(callback_or_name, ...)
    local async = native(2)

    if type(callback_or_name) == 'string' then
        assert(callback_or_name ~= '', 'name: must not be empty')

        assert_callable('callback', select(1, ...))
    else
        assert_callable('callback', callback_or_name)
    end

    local task = async.run(callback_or_name, ...)

    ---@cast task CoreAsyncTask
    return task
end

---@param duration_ms integer
---@param callback? fun()
---@return CoreAsyncTask
function M.delay(duration_ms, callback)
    assert_integer('duration_ms', duration_ms, 0)

    if callback ~= nil then
        assert_callable('callback', callback)
    end

    return M.run(('delay:%d'):format(duration_ms), function()
        native(2).sleep(duration_ms)

        if callback ~= nil then
            callback()
        end
    end)
end

---@async
---@param duration_ms integer
function M.sleep(duration_ms)
    assert_integer('duration_ms', duration_ms, 0)

    native(2).sleep(duration_ms)
end

---@param command string[]
---@param opts? vim.SystemOpts
---@return CoreAsyncTask
function M.system(command, opts)
    local copied_command = copy_command(command)
    local copied_opts = copy_system_options(opts)

    return M.run('system:' .. copied_command[1], function()
        return await_system(copied_command, copied_opts)
    end)
end

---@param command string[]
---@param opts? vim.SystemOpts
---@return CoreAsyncTask
function M.system_checked(command, opts)
    local copied_command = copy_command(command)
    local copied_opts = copy_system_options(opts)

    return M.run('system_checked:' .. copied_command[1], function()
        local result = await_system(copied_command, copied_opts)

        if result.code ~= 0 then
            error(command_error(result, copied_command[1]), 0)
        end

        return result
    end)
end

---@async
---@param items any[]
---@param opts? vim.ui.select.Opts
---@return any
---@return integer?
function M.select(items, opts)
    assert(type(items) == 'table', 'items: expected array')
    assert(#items <= TASKS_MAX, 'selection exceeds item budget')

    if opts ~= nil then
        assert(type(opts) == 'table', 'opts: expected vim.ui.select.Opts')
    end

    local async = native(2)

    ---@param done fun(item: any, index: integer?)
    local function select_item(done)
        vim.ui.select(items, opts or {}, done)
    end

    return async.await(select_item)
end

---@async
---@param opts? vim.ui.input.Opts
---@return string?
function M.input(opts)
    if opts ~= nil then
        assert(type(opts) == 'table', 'opts: expected vim.ui.input.Opts')
    end

    local async = native(2)

    ---@param done fun(value: string?)
    local function request_input(done)
        vim.ui.input(opts or {}, done)
    end

    local value = async.await(request_input)

    ---@cast value string?
    return value
end

---@async
---@param current CoreAsyncTask
---@param duration_ms integer
---@return ...
function M.timeout(current, duration_ms)
    local task = assert_task(current)

    assert_integer('duration_ms', duration_ms, 0)

    return native(2).timeout(duration_ms, task)
end

---@async
---@param current CoreAsyncTask
---@return ...
function M.await(current)
    local task = assert_task(current)

    return native(2).await(task)
end

---@async
---@param current CoreAsyncTask
---@return boolean
---@return ...
function M.pawait(current)
    local task = assert_task(current)

    return native(2).pawait(task)
end

---@async
function M.checkpoint()
    native(2).checkpoint()
end

---@return boolean
function M.is_closing()
    return native(2).is_closing()
end

---@async
---@param tasks CoreAsyncTask[]
---@return fun(): CoreAsyncTask?
function M.iter(tasks)
    assert(type(tasks) == 'table', 'tasks: expected array')

    local count = #tasks

    assert(count <= TASKS_MAX, ('tasks: exceeds %d entries'):format(TASKS_MAX))

    for key in pairs(tasks) do
        assert(
            type(key) == 'number' and key % 1 == 0 and key >= 1 and key <= count,
            'tasks: expected dense array'
        )
    end

    local copied = {} ---@type CoreAsyncTask[]

    for index = 1, count do
        copied[index] = assert_task(tasks[index], ('tasks[%d]'):format(index))
    end

    local iterator = native(2).iter(copied)

    ---@cast iterator fun(): CoreAsyncTask?
    return iterator
end

---@param permits integer
---@return CoreAsyncSemaphore
function M.semaphore(permits)
    assert_integer('permits', permits, 1)

    local semaphore = native(2).semaphore(permits)

    ---@cast semaphore CoreAsyncSemaphore
    return semaphore
end

---Wrap a callback-style function as a reusable async function.
---
---`argc` is the callback argument position, matching vim.async.wrap().
---@param argc integer
---@param callback function
---@return function
function M.wrap(argc, callback)
    assert_integer('argc', argc, 1)

    assert_callable('callback', callback)

    return native(2).wrap(argc, callback)
end

---@param current CoreAsyncTask
---@param callback fun(err?: any, ...: any)
---@return fun()
function M.observe(current, callback)
    local task = assert_task(current)

    assert_callable('callback', callback)

    return task:on_complete(function(err, ...)
        local values = {
            n = select('#', ...),
            ...,
        }

        vim.schedule(function()
            callback(err, unpack_values(values, 1, values.n))
        end)
    end)
end

---@param current? CoreAsyncTask
function M.cancel(current)
    if current == nil then
        return
    end

    local task = assert_task(current)

    if not task:completed() then
        task:close()
    end
end

---@param tasks table<any, CoreAsyncTask>
function M.cancel_all(tasks)
    assert(type(tasks) == 'table', 'tasks: expected table')

    local entries = {} ---@type CoreAsyncCancelEntry[]

    for key, current in pairs(tasks) do
        assert(#entries < TASKS_MAX, ('tasks: exceeds %d entries'):format(TASKS_MAX))

        entries[#entries + 1] = {
            key = key,
            task = assert_task(current, ('tasks[%s]'):format(tostring(key))),
        }
    end

    local errors = {} ---@type string[]

    for index = 1, #entries do
        local entry = entries[index]

        tasks[entry.key] = nil

        local cancelled, cancel_error = pcall(M.cancel, entry.task)

        if not cancelled then
            errors[#errors + 1] = tostring(cancel_error)
        end
    end

    if #errors > 0 then
        error(truncate_error(table.concat(errors, '\n')), 0)
    end
end

-- Callback process entry point also works when the optional vim.async runtime is absent.
-- Capture has one owner, a fixed byte budget, a deadline, and editor-exit cancellation.
local processes = {}
local process_count = 0
local process_group

---@param command string[]
---@param opts? vim.SystemOpts|table max_output_bytes defaults to 8 MiB, timeout to 30 s.
---@param callback fun(result: vim.SystemCompleted|table)
---@return vim.SystemObj?, string?
function M.spawn(command, opts, callback)
    local argv = copy_command(command)
    assert_callable('callback', callback)
    if process_count >= 64 then
        return nil, 'Process limit (64) reached'
    end
    local settings = copy_system_options(opts)
    local budget = settings.max_output_bytes or 8 * 1024 * 1024
    assert(type(budget) == 'number' and budget >= 1 and budget <= 64 * 1024 * 1024)
    settings.max_output_bytes = nil
    settings.timeout = settings.timeout or 30000
    assert_integer('timeout', settings.timeout, 1)
    assert(settings.timeout <= 300000, 'process timeout exceeds 5 minutes')
    local chunks = { stdout = {}, stderr = {} }
    local count, size, failure, process = 0, 0, nil, nil
    local function stop()
        if process then
            kill_process(process, 'sigkill')
        end
    end
    for _, stream in ipairs({ 'stdout', 'stderr' }) do
        local consumer = settings[stream]
        if consumer ~= false then
            settings[stream] = function(err, data)
                if failure then
                    return
                end
                if err then
                    failure = tostring(err)
                end
                if data then
                    size, count = size + #data, count + 1
                    if size > budget or count > 65536 then
                        failure = 'Process output budget exceeded'
                    end
                end
                if failure then
                    stop()
                    return
                end
                if type(consumer) == 'function' then
                    local ok, message = pcall(consumer, err, data)
                    if not ok then
                        failure = tostring(message)
                        stop()
                    end
                elseif data then
                    chunks[stream][#chunks[stream] + 1] = data
                end
            end
        end
    end
    if not process_group then
        process_group = vim.api.nvim_create_augroup('DiverCoreProcesses', { clear = true })
        vim.api.nvim_create_autocmd('VimLeavePre', {
            group = process_group,
            callback = function()
                for running in pairs(processes) do
                    kill_process(running, 'sigkill')
                end
            end,
        })
    end
    local ok, result = pcall(vim.system, argv, settings, function(completed)
        vim.schedule(function()
            if process and processes[process] then
                processes[process] = nil
                process_count = process_count - 1
            end
            completed.stdout, completed.stderr =
                table.concat(chunks.stdout), table.concat(chunks.stderr)
            completed.error = failure
            if failure and completed.code == 0 then
                completed.code = 1
            end
            callback(completed)
        end)
    end)
    if not ok then
        return nil, 'Start process: ' .. tostring(result)
    end
    process = result
    processes[process] = true
    process_count = process_count + 1
    return process
end

return M
