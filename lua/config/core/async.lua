-- #################################################################
-- /qompassai/Diver/lua/config/core/async.lua
-- Qompass AI Diver Native Async Utilities
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

local async = vim.async

local M = {}

---@param name? string
---@param callback async fun(): ...
---@return vim.async.Task
function M.run(name, callback)
    if callback == nil then
        return async.run(name)
    end

    return async.run(
        name,
        callback
    )
end

---@param ms integer
---@param callback? fun()
---@return vim.async.Task
function M.delay(ms, callback)
    return async.run(
        'delay:' .. tostring(ms),
        function()
            async.sleep(ms)

            if callback ~= nil then
                callback()
            end
        end
    )
end

---@param ms integer
function M.sleep(ms)
    async.sleep(ms)
end

---@param command string[]
---@param opts? vim.SystemOpts
---@return vim.async.Task
function M.system(command, opts)
    assert(
        #command > 0,
        'async.system: command must not be empty'
    )

    return async.run(
        'system:' .. command[1],
        function()
            return async.await(
                function(done)
                    return vim.system(
                        command,
                        opts or {},
                        done
                    )
                end
            )
        end
    )
end

---@param command string[]
---@param opts? vim.SystemOpts
---@return vim.async.Task
function M.system_checked(command, opts)
    assert(
        #command > 0,
        'async.system_checked: command must not be empty'
    )

    return async.run(
        'system_checked:' .. command[1],
        function()
            local result =
                async.await(
                    M.system(
                        command,
                        opts
                    )
                )

            if result.code ~= 0 then
                local message =
                    result.stderr

                if
                    type(message) ~= 'string'
                    or message == ''
                then
                    message =
                        (
                            '%s exited with code %d'
                        ):format(
                            command[1],
                            result.code
                        )
                end

                error(
                    message,
                    0
                )
            end

            return result
        end
    )
end

---@generic T
---@param items T[]
---@param opts? vim.ui.select.Opts
---@return T?, integer?
function M.select(items, opts)
    return async.await(
        function(done)
            vim.ui.select(
                items,
                opts or {},
                function(item, index)
                    done(
                        item,
                        index
                    )
                end
            )
        end
    )
end

---@param opts? vim.ui.input.Opts
---@return string?
function M.input(opts)
    return async.await(
        function(done)
            vim.ui.input(
                opts or {},
                function(value)
                    done(value)
                end
            )
        end
    )
end

---@param current vim.async.Task
---@param timeout integer
---@return ...
function M.timeout(current, timeout)
    return async.timeout(
        timeout,
        current
    )
end

---@param current vim.async.Task
---@return ...
function M.await(current)
    return async.await(current)
end

---@param current vim.async.Task
---@return boolean, ...
function M.pawait(current)
    return async.pawait(current)
end

function M.checkpoint()
    async.checkpoint()
end

---@return boolean
function M.is_closing()
    return async.is_closing()
end

---@param tasks vim.async.Task[]
---@return fun(): vim.async.Task?
function M.iter(tasks)
    return async.iter(tasks)
end

---@param permits integer
---@return vim.async.Semaphore
function M.semaphore(permits)
    return async.semaphore(permits)
end

---@param current vim.async.Task
---@param callback fun(err?: any, ...)
---@return fun()
function M.observe(current, callback)
    return current:on_complete(
        function(err, ...)
            local values = {
                ...,
            }

            vim.schedule(
                function()
                    callback(
                        err,
                        unpack(values)
                    )
                end
            )
        end
    )
end

---@param current vim.async.Task?
function M.cancel(current)
    if
        current == nil
        or current:completed()
    then
        return
    end

    current:close()
end

---@param tasks table<any, vim.async.Task>
function M.cancel_all(tasks)
    for key, current in pairs(tasks) do
        if not current:completed() then
            current:close()
        end

        tasks[key] = nil
    end
end

return M