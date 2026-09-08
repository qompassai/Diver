-- #################################################################
-- /qompassai/Diver/lua/utils/games/shared/async_util.lua
-- Qompass AI Games Shared Async Helpers
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
local M = {}

M.DEFAULT_PROBE_TIMEOUT_MS = 4000
M.MAX_CONCURRENT_TASKS = 8 -- sanity ceiling; we never juggle more than 5 engines

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
---@return any awaitable  pass directly to vim.async.await/pawait
function M.system_task(cmd, opts)
  assert(type(cmd) == 'table' and #cmd > 0, 'games.shared.async_util.system_task: cmd must be a non-empty argv list')
  local run_system = wrapped_system()
  return run_system(cmd, opts or { text = true })
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
---@return (boolean|any)[][] results  -- list of {ok, value_or_err, job_index}
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

  local ok, results = M.run_bounded(function()
    local async = vim.async
    ---@type vim.async.Task[]
    local children = {}

    for index = 1, #jobs do
      -- Creating the task here attaches it to the CURRENT task (this
      -- run_bounded body), so it is a child, not a top-level task --
      -- it starts running the moment we hit the checkpoint below,
      -- same as a backgrounded shell job starts once you hit `&` and
      -- the shell yields back to its own event loop.
      children[index] = async.run(jobs[index])
      children[index].job_index = index
    end

    ---@type table[]
    local collected = {}
    for task in async.iter(children) do
      local task_ok, value = async.pawait(task)
      collected[#collected + 1] = { task_ok, value, task.job_index }
    end
    return collected
  end, timeout_ms)

  if not ok then
    return {}
  end

  return results
end

return M
