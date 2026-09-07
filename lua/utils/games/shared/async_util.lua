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
--
-- LEARN LUA VIA WHAT YOU ALREADY KNOW (networking/Linux background):
--
--   `vim.async` (added in Nvim 0.13, see :h lua-async) gives Lua the
--   same shape of concurrency you already reason about with epoll/
--   select(2): many outstanding operations, one thread, no
--   preemption. A "Task" is like a process group's leader: it owns
--   child tasks the way a shell job owns its process group, and
--   closing/killing the parent is expected to bring down the
--   children too ("structured concurrency" == "no orphan processes").
--
--   `vim.system(cmd, opts, on_exit)` is fork()+exec()+waitpid() with
--   the plumbing (pipes for stdout/stderr, an exit code) already
--   wired up for you -- it just delivers the result via a Lua
--   callback instead of blocking your caller, the same way an
--   asynchronous socket read delivers bytes via a completion
--   callback instead of blocking on recv(2).
--
--   `vim.async.wrap(argc, func)` exists because raw callbacks nest:
--   "run this, and when it's done, run that, and when THAT's done,
--   ...". That's the Lua equivalent of deeply nested `ssh host1 "cmd
--   && ssh host2 'cmd && ...'"` -- functionally fine, but every
--   added step makes the indentation (and your blood pressure)
--   worse. Wrapping a callback API turns it into a normal-looking
--   function you can `await`, so a 3-step remote bootstrap reads
--   top-to-bottom like a shell script instead of a staircase.
--
-- This module only wraps `vim.system`; it does not change what gets
-- executed or how errors are reported (still argv lists, still exit
-- codes, still stderr text) -- it only changes *how the caller waits*.
local M = {}

-- Fixed, explicit bounds (Tiger Style: no unbounded waits, ever).
-- A GamesDoctor probe or a metadata query has no excuse to hang the
-- editor; a real build/export can legitimately take a long time, so
-- callers of run_with_progress (unbounded, streaming) are unaffected
-- by these constants -- they only gate the NEW vim.async call sites.
M.DEFAULT_PROBE_TIMEOUT_MS = 4000
M.MAX_CONCURRENT_TASKS = 8 -- sanity ceiling; we never juggle more than 5 engines

---@type fun(...): any
-- `vim.async.wrap(3, vim.system)`: position 3 is where vim.system
-- expects its `on_exit` callback, so the wrapped function is an
-- `async fun(cmd: string[], opts: table?): vim.SystemCompleted`.
-- Precondition/postcondition pair (Tiger Style): vim.async must
-- exist (Nvim 0.13+) before we ever reach for it -- fail loudly here
-- instead of producing a confusing "attempt to index nil" far away.
local function wrapped_system()
  assert(
    vim.async ~= nil and vim.async.wrap ~= nil,
    'games.shared.async_util: vim.async is unavailable -- requires Neovim 0.13+'
  )
  return vim.async.wrap(3, vim.system)
end

-- IMPORTANT USAGE NOTE, because this is the one place the "wrap"
-- indirection is easy to get backwards: `vim.async.wrap(...)` gives
-- back a function that, when CALLED, produces an awaitable -- the
-- call itself does not suspend anything (same distinction as `dig
-- example.com &` starting a background query vs. `wait` collecting
-- its result). So call sites must do:
--   local completed = vim.async.await(async_util.system_task(cmd))
-- and BOTH the call to `system_task` and the `await` must happen
-- from code already running inside a task (created by
-- `vim.async.run`) -- exactly like `await` itself.
---@param cmd string[]
---@param opts table?
---@return any awaitable  pass directly to vim.async.await/pawait
function M.system_task(cmd, opts)
  assert(type(cmd) == 'table' and #cmd > 0, 'games.shared.async_util.system_task: cmd must be a non-empty argv list')
  local run_system = wrapped_system()
  return run_system(cmd, opts or { text = true })
end

-- Runs `body` (an async function taking no arguments) as a bounded,
-- synchronous-looking task: the caller blocks the current *editor
-- command*, not the whole UI thread (Nvim keeps rendering while
-- `Task:wait()` pumps the event loop) -- comparable to `timeout(1)`
-- wrapping a shell command: either it finishes in time, or it is
-- cooperatively asked to stop and we move on.
--
-- Precondition: body is callable and timeout_ms is a positive integer.
-- Postcondition: always returns (ok, result_or_err); never raises.
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
    -- Cooperative cancellation: like sending SIGTERM instead of
    -- SIGKILL -- we ask the task (and any children it owns) to wind
    -- down at their next checkpoint rather than leaking a coroutine.
    task:close()
  end

  return ok, result
end

-- Runs several zero-argument async functions as SIBLING child tasks
-- of one parent, then collects every result in COMPLETION order
-- (fastest first) -- this is the direct Lua analogue of firing N
-- concurrent probes and reading responses off an epoll_wait() loop
-- as they arrive, instead of blocking on each socket in turn.
--
-- `jobs` is bounded by MAX_CONCURRENT_TASKS (Tiger Style: explicit
-- fixed limit) because this plugin only ever probes five engines --
-- if that assumption changes, the assertion below fails loudly
-- instead of silently degrading.
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
