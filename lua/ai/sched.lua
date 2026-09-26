-- /qompassai/Diver/lua/ai/sched.lua
-- Control-first request pump shared by the ai/ socket servers (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved.
-- ----------------------------------------
--
-- Plain words: the herd/debugbridge socket servers used to serve
-- requests strictly first-in-first-out, so one slow request (a big
-- query, a build) made every tiny status check behind it wait. This
-- module is a tiny two-lane waiting line instead: requests marked
-- 'control' (small, latency-sensitive) always go before 'bulk'
-- requests (slow, heavy). It borrows Homa's SRPT idea — shortest
-- work first — but applied to our own dispatch loop on one machine,
-- not to a datacenter network.
--
-- v1 SCOPE: this changes *ordering* only. A bulk handler that blocks
-- the main loop still stalls everything behind it while it runs;
-- that pre-existing limitation is documented in each api.lua.

local M = {}

---Maximum requests waiting in the pump. Each queued line is at most
---64KB, so the pump holds at most ~16MB no matter the arrival rate.
local PENDING_COUNT_MAX = 256

---@class AiSchedItem
---@field client uv.uv_pipe_t
---@field state table
---@field line string

---@class AiSched
---@field classify fun(line: string): string
---@field handle fun(client: uv.uv_pipe_t, state: table, line: string)
---@field control AiSchedItem[]
---@field bulk AiSchedItem[]
---@field scheduled boolean

local AiSched = {}
AiSched.__index = AiSched

---Serve one queued request. A throwing handler is reported and the
---pump keeps going, matching the old one-callback-per-request
---isolation: one bad request never wedges the whole queue.
---@param self AiSched
---@param item AiSchedItem
local function serve(self, item)
    local ok, err = pcall(self.handle, item.client, item.state, item.line)
    if not ok then
        local msg = 'ai.sched: handler error: ' .. tostring(err)
        vim.notify(msg, vim.log.levels.ERROR)
    end
end

---Ask the main loop for one more pump turn, unless one is already
---waiting. Chained through vim.schedule, never real recursion.
---@param self AiSched
local function kick(self)
    if self.scheduled then
        return
    end
    self.scheduled = true
    vim.schedule(function()
        self.scheduled = false
        -- Control first: drain every waiting control request, then
        -- serve exactly one bulk request and yield. Serving one bulk
        -- item per turn lets newly arrived control requests jump ahead
        -- of the bulk backlog instead of waiting behind it.
        while #self.control > 0 do
            serve(self, table.remove(self.control, 1))
        end
        if #self.bulk > 0 then
            serve(self, table.remove(self.bulk, 1))
        end
        if #self.control > 0 or #self.bulk > 0 then
            kick(self)
        end
    end)
end

---Create a control-first pump. classify maps one framed request line
---to 'control' or 'bulk' (anything else counts as control); handle
---serves one line. classify runs in fast event context, so it must
---use only string matching, never vim.* calls; handle always runs
---scheduled on the main loop.
---@param classify fun(line: string): string
---@param handle fun(client: uv.uv_pipe_t, state: table, line: string)
---@return AiSched
function M.new(classify, handle)
    assert(type(classify) == 'function', 'classify must be a function')
    assert(type(handle) == 'function', 'handle must be a function')
    return setmetatable({
        classify = classify,
        handle = handle,
        control = {},
        bulk = {},
        scheduled = false,
    }, AiSched)
end

---Queue one framed request line for a future pump turn. Returns
---false when the pump is full; the line was NOT queued and the
---caller should refuse the request instead of silently dropping it.
---@param client uv.uv_pipe_t
---@param state table
---@param line string
---@return boolean accepted
function AiSched:enqueue(client, state, line)
    assert(type(line) == 'string', 'line must be a string')
    if #self.control + #self.bulk >= PENDING_COUNT_MAX then
        return false
    end
    local queue = self.control
    if self.classify(line) == 'bulk' then
        queue = self.bulk
    end
    queue[#queue + 1] = { client = client, state = state, line = line }
    kick(self)
    return true
end

return M
