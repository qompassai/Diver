-- /qompassai/Diver/lua/config/core/async.lua
local M = {}

local async = vim.async

---@param ms integer
---@param callback? fun()
---@return vim.async.Task
function M.delay(ms, callback)
    return async.run(function()
        async.sleep(ms)

        if callback ~= nil then
            callback()
        end
    end)
end

---@param command string[]
---@param opts? vim.SystemOpts
---@return vim.async.Task
function M.system(command, opts)
    return async.run(function()
        local result = async.await(function(done)
            return vim.system(
                command,
                opts or {},
                done
            )
        end)

        return result
    end)
end

---@param ms integer
function M.sleep(ms)
    async.sleep(ms)
end

---@param task vim.async.Task
---@param timeout integer
---@return ...
function M.timeout(task, timeout)
    return async.timeout(timeout, task)
end

M.await = async.await
M.pawait = async.pawait
M.run = async.run
M.checkpoint = async.checkpoint

return M