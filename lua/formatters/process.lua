-- #################################################################
-- /qompassai/lua/formatters/process.lua
-- Qompass AI Formatter bounded asynchronous process queue
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
---@source https://github.com/qompassai/diver
local M = {}
local queue = {}
local active = 0
local stopped = false

local CONCURRENCY = 2
local OUTPUT_LIMIT = 2 * 1024 * 1024
local processes = {}

local pump

local function deliver(callback, result)
    local ok, err = pcall(callback, result)
    if not ok then
        vim.notify(tostring(err), vim.log.levels.ERROR)
    end
end

pump = function()
    while not stopped and active < CONCURRENCY and #queue > 0 do
        local task = table.remove(queue, 1)
        active = active + 1

        local chunks = {}
        local size = 0
        local problem
        local process

        local function capture(err, data)
            if err then
                problem = tostring(err)
            end
            if data and not problem then
                size = size + #data
                if size > OUTPUT_LIMIT then
                    problem = 'Process output limit exceeded'
                else
                    chunks[#chunks + 1] = data
                end
            end
            if problem and process then
                pcall(process.kill, process, 9)
            end
        end

        local ok, handle = pcall(vim.system, task.argv, {
            cwd = task.cwd,
            env = task.env,
            timeout = task.timeout,
            stdout = capture,
            stderr = capture,
        }, function(result)
            vim.schedule(function()
                if process then
                    processes[process] = nil
                end
                active = active - 1

                if not stopped then
                    deliver(task.callback, {
                        ok = problem == nil and result.code == 0 and result.signal == 0,
                        code = result.code,
                        text = table.concat(chunks),
                        error = problem,
                    })
                    pump()
                end
            end)
        end)

        if ok then
            process = handle
            processes[handle] = true
        else
            active = active - 1
            deliver(task.callback, {
                ok = false,
                text = '',
                error = tostring(handle),
            })
        end
    end
end

---@param argv string[]
---@param options table
---@param callback fun(result: table)
function M.run(argv, options, callback)
    assert(not stopped, 'Process queue is stopped')
    assert(type(argv) == 'table' and #argv > 0, 'argv is required')
    for _, value in ipairs(argv) do
        assert(type(value) == 'string' and not value:find('%z'), 'Invalid argv')
    end

    queue[#queue + 1] = {
        argv = argv,
        cwd = options.cwd,
        env = options.env,
        timeout = options.timeout or 10000,
        callback = callback,
    }
    pump()
end

local group = vim.api.nvim_create_augroup('FormatterToolProcesses', {
    clear = true,
})

vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    callback = function()
        stopped = true
        queue = {}
        for process in pairs(processes) do
            pcall(process.kill, process, 9)
        end
    end,
})

return M
