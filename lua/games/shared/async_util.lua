-- /qompassai/Diver/lua/games/shared/async_util.lua
-- Qompass AI Games Shared Async Helpers
---@module 'games.shared.async_util'

local M = {}

M.DEFAULT_PROBE_TIMEOUT_MS = 4000
M.MAX_CONCURRENT_TASKS = 8

---Typed pcall-style await for a task.
---
---Plain-language version: waits for one background task and tells you whether
---it worked. Use this instead of calling vim.async.pawait directly: the
---generic binds here, so the checker knows the result's type.
---@generic R
---@param task vim.async.Task<R> task to await (usually from M.system_task)
---@return boolean ok false when the await failed
---@return R? result task result, or nil when the await failed
---@async
function M.pawait_task(task)
    assert(task ~= nil, 'games.shared.async_util.pawait_task: task is required')

    return vim.async.pawait(task)
end

---@param body async fun(): ...
---@param timeout_ms integer?
---@return boolean ok
---@return any result_or_err
function M.run_bounded(body, timeout_ms)
    assert(type(body) == 'function', 'games.shared.async_util.run_bounded: body must be a function')

    timeout_ms = timeout_ms or M.DEFAULT_PROBE_TIMEOUT_MS

    assert(
        type(timeout_ms) == 'number' and timeout_ms > 0,
        'games.shared.async_util.run_bounded: timeout_ms must be a positive number'
    )

    assert(vim.async ~= nil and vim.async.run ~= nil, 'games.shared.async_util.run_bounded: vim.async is unavailable')

    local task = vim.async.run(body)
    local ok, result = task:pwait(timeout_ms)

    if not ok then
        task:close()
    end

    return ok, result
end

---@param jobs (async fun(): any)[]
---@param timeout_ms integer?
---@return (boolean|any)[][] results List of { ok, value_or_err, job_index }.
function M.run_concurrent(jobs, timeout_ms)
    assert(type(jobs) == 'table', 'games.shared.async_util.run_concurrent: jobs must be a list')

    assert(#jobs > 0, 'games.shared.async_util.run_concurrent: jobs must be non-empty')

    assert(
        #jobs <= M.MAX_CONCURRENT_TASKS,
        ('games.shared.async_util.run_concurrent: %d jobs exceeds MAX_CONCURRENT_TASKS=%d'):format(
            #jobs,
            M.MAX_CONCURRENT_TASKS
        )
    )

    ---@async
    local function run_all()
        local async = vim.async

        ---@type vim.async.Task[]
        local children = {}

        ---@type table<vim.async.Task, integer>
        local index_of = {}

        for index = 1, #jobs do
            local child = async.run(jobs[index])

            index_of[child] = index
            children[index] = child
        end

        ---@type table[]
        local collected = {}

        for task in async.iter(children) do
            local task_ok, value = async.pawait(task)

            collected[#collected + 1] = {
                task_ok,
                value,
                index_of[task],
            }
        end

        return collected
    end

    local ok, results = M.run_bounded(run_all, timeout_ms)

    if not ok then
        return {}
    end

    return results
end

---@type fun(...): any
local function wrapped_system()
    assert(
        vim.async ~= nil and vim.async.wrap ~= nil,
        'games.shared.async_util: vim.async is unavailable -- requires Neovim 0.13+'
    )

    return vim.async.wrap(3, vim.system)
end

---@param cmd string[]
---@param opts table?
---@return vim.async.Task<vim.SystemCompleted> awaitable Pass directly to vim.async.await() or M.pawait_task().
function M.system_task(cmd, opts)
    assert(type(cmd) == 'table' and #cmd > 0, 'games.shared.async_util.system_task: cmd must be a non-empty argv list')

    local run_system = wrapped_system()

    return run_system(cmd, opts or { text = true })
end

return M
