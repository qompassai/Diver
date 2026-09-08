-- #################################################################
-- /lua/config/core/async.lua
-- Native Neovim Async Utilities
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
---@source https://github.com/neovim/neovim/blob/master/runtime/lua/vim/async.lua
---@source https://github.com/neovim/neovim/blob/master/runtime/lua/vim/async/_core.lua
---@source https://github.com/neovim/neovim/blob/master/runtime/lua/vim/async/_semaphore.lua
---@source https://neovim.io/doc/user/lua.html

local async = require('vim.async')

local M = {}

local COMMAND_ARGUMENTS_MAX = 4096
local DURATION_MS_MAX = 2 ^ 32 - 1
local ERROR_MESSAGE_BYTES_MAX = 4096
local SYSTEM_CANCEL_GRACE_MS = 1000
local TASKS_MAX = 4096

---@alias NativeAsyncTaskStatus 'running'|'awaiting'|'normal'|'completed'

---@class NativeAsyncTask
---@field name? string
---@field close fun(self: NativeAsyncTask, callback?: fun())
---@field completed fun(self: NativeAsyncTask): boolean
---@field detach fun(self: NativeAsyncTask): NativeAsyncTask
---@field on_complete fun(self: NativeAsyncTask, callback: fun(err?: any, ...: any)): fun()
---@field pwait fun(self: NativeAsyncTask, timeout?: integer): boolean, ...
---@field raise_on_error fun(self: NativeAsyncTask): NativeAsyncTask
---@field status fun(self: NativeAsyncTask): NativeAsyncTaskStatus
---@field traceback fun(self: NativeAsyncTask, message?: string, level?: integer): string
---@field wait fun(self: NativeAsyncTask, timeout?: integer): ...

---@class NativeAsyncSemaphore
---@field acquire fun(self: NativeAsyncSemaphore)
---@field release fun(self: NativeAsyncSemaphore)
---@field with fun(self: NativeAsyncSemaphore, callback: fun()): any

---@class NativeAsyncSystemCloser
---@field close fun(self: NativeAsyncSystemCloser, callback?: fun())
---@field is_closing fun(self: NativeAsyncSystemCloser): boolean

---@class NativeAsyncCancelEntry
---@field key any
---@field task NativeAsyncTask

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

---@param value any
---@param name? string
---@return NativeAsyncTask
local function assert_task(value, name)
  name = name or 'task'

  assert(type(value) == 'table', ('%s: expected vim.async task'):format(name))

  ---@cast value NativeAsyncTask
  assert_callable(name .. '.completed', value.completed)
  assert_callable(name .. '.on_complete', value.on_complete)
  assert_callable(name .. '.close', value.close)

  return value
end
---@param command string[]
---@return string[]
local function copy_command(command)
  assert(type(command) == 'table', 'command: expected string array')
  local count = #command
  assert(count > 0, 'command: must not be empty')
  assert(count <= COMMAND_ARGUMENTS_MAX, ('command: exceeds %d arguments'):format(COMMAND_ARGUMENTS_MAX))

  for key in pairs(command) do
    assert(type(key) == 'number' and key % 1 == 0 and key >= 1 and key <= count, 'command: expected dense string array')
  end

  ---@type string[]
  local copied = {}

  for index = 1, count do
    local argument = command[index]

    assert(type(argument) == 'string', ('command[%d]: expected string'):format(index))
    assert(argument:find('\0', 1, true) == nil, ('command[%d]: contains NUL byte'):format(index))

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

  local copied = {}

  for key, value in pairs(opts) do
    copied[key] = value
  end

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
  local stderr = type(result.stderr) == 'string' and vim.trim(result.stderr) or ''

  if stderr ~= '' then
    return truncate_error(stderr)
  end

  local stdout = type(result.stdout) == 'string' and vim.trim(result.stdout) or ''

  if stdout ~= '' then
    return truncate_error(stdout)
  end

  if result.signal ~= 0 then
    return ('%s exited with code %d after signal %d'):format(executable, result.code, result.signal)
  end

  return ('%s exited with code %d'):format(executable, result.code)
end

---@async
---@param command string[]
---@param opts vim.SystemOpts
---@return vim.SystemCompleted
local function await_system(command, opts)
  local exited = false
  local closing = false

  ---@type fun()[]
  local close_callbacks = {}

  ---@type vim.SystemObj?
  local process

  local function finish_close()
    local callbacks = close_callbacks

    close_callbacks = {}

    for index = 1, #callbacks do
      callbacks[index]()
    end
  end

  ---@param done fun(completed: vim.SystemCompleted)
  ---@return any
  local function start_process(done)
    process = vim.system(command, opts, function(completed)
      exited = true
      done(completed)
      finish_close()
      process = nil
    end)

    ---@type NativeAsyncSystemCloser
    local closer = {
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

        local terminated = pcall(active.kill, active, 'sigterm')

        if not terminated then
          local killed = pcall(active.kill, active, 'sigkill')

          if not killed then
            finish_close()
          end

          return
        end

        vim.defer_fn(function()
          if exited then
            return
          end

          local running = process

          if running == nil or not pcall(running.kill, running, 'sigkill') then
            finish_close()
          end
        end, SYSTEM_CANCEL_GRACE_MS)
      end,
      is_closing = function()
        return closing or exited
      end,
    }

    return closer
  end

  local result = async.await(start_process)

  ---@cast result any
  return result
end

---@param callback_or_name string|fun(...: any): any
---@param ... any
---@return NativeAsyncTask
---@overload fun(name: string, callback: fun(...: any): any, ...: any): NativeAsyncTask
function M.run(callback_or_name, ...)
  if type(callback_or_name) == 'string' then
    assert(callback_or_name ~= '', 'name: must not be empty')
    assert_callable('callback', select(1, ...))
  else
    assert_callable('callback', callback_or_name)
  end

  local task = async.run(callback_or_name, ...)

  ---@cast task NativeAsyncTask
  return task
end

---@param duration_ms integer
---@param callback? fun()
---@return NativeAsyncTask
function M.delay(duration_ms, callback)
  assert_integer('duration_ms', duration_ms, 0)

  if callback ~= nil then
    assert_callable('callback', callback)
  end

  return M.run(('delay:%d'):format(duration_ms), function()
    async.sleep(duration_ms)

    if callback ~= nil then
      callback()
    end
  end)
end

---@async
---@param duration_ms integer
function M.sleep(duration_ms)
  assert_integer('duration_ms', duration_ms, 0)
  async.sleep(duration_ms)
end

---@param command string[]
---@param opts? vim.SystemOpts
---@return NativeAsyncTask
function M.system(command, opts)
  local copied_command = copy_command(command)
  local copied_opts = copy_system_options(opts)

  return M.run('system:' .. copied_command[1], function()
    return await_system(copied_command, copied_opts)
  end)
end

---@param command string[]
---@param opts? vim.SystemOpts
---@return NativeAsyncTask
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
---@generic T
---@param items T[]
---@param opts? vim.ui.select.Opts
---@return T?, integer?
function M.select(items, opts)
  assert(type(items) == 'table', 'items: expected array')

  if opts ~= nil then
    assert(type(opts) == 'table', 'opts: expected vim.ui.select.Opts')
  end

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

  ---@param done fun(value: string?)
  local function request_input(done)
    vim.ui.input(opts or {}, done)
  end

  local value = async.await(request_input)

  ---@cast value any
  return value
end

---@async
---@param current NativeAsyncTask
---@param duration_ms integer
---@return ...
function M.timeout(current, duration_ms)
  local task = assert_task(current)

  assert_integer('duration_ms', duration_ms, 0)

  return async.timeout(duration_ms, task)
end

---@async
---@param current NativeAsyncTask
---@return ...
function M.await(current)
  return async.await(assert_task(current))
end

---@async
---@param current NativeAsyncTask
---@return boolean, ...
function M.pawait(current)
  return async.pawait(assert_task(current))
end

---@async
function M.checkpoint()
  async.checkpoint()
end

---@return boolean
function M.is_closing()
  return async.is_closing()
end

---@async
---@param tasks NativeAsyncTask[]
---@return fun(): NativeAsyncTask?
function M.iter(tasks)
  assert(type(tasks) == 'table', 'tasks: expected array')

  local count = #tasks

  assert(count <= TASKS_MAX, ('tasks: exceeds %d entries'):format(TASKS_MAX))

  for key in pairs(tasks) do
    assert(type(key) == 'number' and key % 1 == 0 and key >= 1 and key <= count, 'tasks: expected dense array')
  end

  ---@type NativeAsyncTask[]
  local copied = {}

  for index = 1, count do
    copied[index] = assert_task(tasks[index], ('tasks[%d]'):format(index))
  end

  local iterator = async.iter(copied)

  ---@cast iterator fun(): NativeAsyncTask?
  return iterator
end

---@param permits integer
---@return NativeAsyncSemaphore
function M.semaphore(permits)
  assert_integer('permits', permits, 1)

  local semaphore = async.semaphore(permits)

  ---@cast semaphore any
  return semaphore
end

---@param current NativeAsyncTask
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
      callback(err, unpack(values, 1, values.n))
    end)
  end)
end

---@param current? NativeAsyncTask
function M.cancel(current)
  if current == nil then
    return
  end

  local task = assert_task(current)

  if not task:completed() then
    task:close()
  end
end

---@param tasks table<any, NativeAsyncTask>
function M.cancel_all(tasks)
  assert(type(tasks) == 'table', 'tasks: expected table')

  ---@type NativeAsyncCancelEntry[]
  local entries = {}

  for key, current in pairs(tasks) do
    assert(#entries < TASKS_MAX, ('tasks: exceeds %d entries'):format(TASKS_MAX))

    entries[#entries + 1] = {
      key = key,
      task = assert_task(current, ('tasks[%s]'):format(tostring(key))),
    }
  end

  ---@type string[]
  local errors = {}

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

return M
