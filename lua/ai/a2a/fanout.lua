-- /qompassai/Diver/lua/ai/a2a/fanout.lua
-- Qompass AI A2A Scatter-Gather (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- The multi-agent primitive: hand the same job (or a per-agent
-- variant) to N agents at once and get one callback with every
-- result in spec order. Dispatch still flows through the task
-- supervisor, so concurrency bounds, timeouts, and cancellation
-- apply exactly as they do to single tasks. A fan-out-wide timeout
-- cancels whatever is still in flight and reports partial results
-- rather than hanging.

local uv = vim.uv

local tasks = require('ai.a2a.tasks')

local M = {}

local FANOUT_MAX_SPECS = 32
local FANOUT_TIMEOUT_MS = 600000

---@class A2aFanoutSpec
---@field agent string|table Directory name or inline AgentCard.
---@field message string Prompt text for this agent.

---@class A2aFanoutResult
---@field agent string
---@field ok boolean
---@field state string Terminal task state.
---@field artifacts table[]
---@field error? string

---@param specs A2aFanoutSpec[] Nonempty list, at most FANOUT_MAX_SPECS.
---@param opts? { timeout_ms?: integer }
---@param on_done fun(results: A2aFanoutResult[]) Called once, spec order.
function M.run(specs, opts, on_done)
    assert(type(specs) == 'table' and #specs >= 1, 'specs must be a nonempty list')
    assert(#specs <= FANOUT_MAX_SPECS, 'fanout spec bound exceeded')
    assert(type(on_done) == 'function', 'on_done must be a function')
    opts = opts or {}

    local results = {}
    local settled = 0
    local finished = false
    local ids = {}
    local timer = uv.new_timer()

    local function finish()
        if finished then
            return
        end
        finished = true
        timer:stop()
        timer:close()
        local ordered = {}
        for i = 1, #specs do
            ordered[i] = results[i]
        end
        vim.schedule(function()
            on_done(ordered)
        end)
    end

    local function maybe_finish()
        if settled == #specs then
            finish()
        end
    end

    timer:start(opts.timeout_ms or FANOUT_TIMEOUT_MS, 0, function()
        vim.schedule(function()
            for _, id in ipairs(ids) do
                tasks.cancel(id, 'fanout timeout')
            end
            -- Each cancel settles its task, which drives maybe_finish.
        end)
    end)

    for i, spec in ipairs(specs) do
        assert(type(spec) == 'table', 'each spec must be a table')
        local id, err = tasks.submit({
            agent = spec.agent,
            message = spec.message,
            on_done = function(task)
                settled = settled + 1
                results[i] = {
                    agent = task.agent,
                    ok = task.state == 'completed',
                    state = task.state,
                    artifacts = task.artifacts,
                    error = task.error,
                }
                maybe_finish()
            end,
        })
        if id then
            ids[#ids + 1] = id
        else
            settled = settled + 1
            results[i] = {
                agent = type(spec.agent) == 'string' and spec.agent or '?',
                ok = false,
                state = 'failed',
                artifacts = {},
                error = err,
            }
            maybe_finish()
        end
    end
end

return M
