-- #################################################################
-- /qompassai/lua/scip/state.lua
-- Qompass AI SCIP State
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

local uv = vim.uv

local M = {}

---@class QompassScipState
---@field indexer string? Name of the currently running SCIP indexer.
---@field job vim.SystemObj? Active asynchronous SCIP process.
---@field root string? Project root being indexed.
---@field started_at integer High-resolution start timestamp from vim.uv.hrtime().

---@type QompassScipState
M.current = {
        indexer = nil,
        job = nil,
        root = nil,
        started_at = 0,
}

---Return whether a SCIP indexer is currently running.
---
---The active `vim.SystemObj` is the authoritative indicator of whether an
---indexing operation is in progress.
---
---@return boolean
function M.running()
        return M.current.job ~= nil
end

---Return the elapsed runtime of the active SCIP indexer in seconds.
---
---If no valid start timestamp has been recorded, zero is returned.
---
---@return number
function M.elapsed()
        if M.current.started_at == 0 then
                return 0
        end

        return (uv.hrtime() - M.current.started_at) / 1e9
end

---Record a newly started SCIP indexing process.
---
---This should be called immediately after `vim.system()` returns its
---`vim.SystemObj`, allowing the rest of the SCIP subsystem to inspect,
---cancel, or report on the active job.
---
---@param job vim.SystemObj Active SCIP process.
---@param indexer string Name of the SCIP indexer.
---@param root string Project root being indexed.
---@param started_at? integer Optional vim.uv.hrtime() timestamp.
---@return nil
function M.start(job, indexer, root, started_at)
        M.current.job = job
        M.current.indexer = indexer
        M.current.root = vim.fs.normalize(root)
        M.current.started_at = started_at or uv.hrtime()
end

---Clear all active SCIP process state.
---
---This does not terminate the running process itself. Call `M.cancel()` when
---the process should also be stopped.
---
---@return nil
function M.clear()
        M.current.indexer = nil
        M.current.job = nil
        M.current.root = nil
        M.current.started_at = 0
end

---Cancel the active SCIP indexing process.
---
---SIGTERM is used on Unix-like systems so the indexer has an opportunity to
---shut down cleanly. State is cleared immediately after the signal is sent.
---
---@return boolean cancelled True when a process was active and signalled.
function M.cancel()
        local job = M.current.job

        if job == nil then
                return false
        end

        job:kill(15)
        M.clear()

        return true
end

---Return the name of the currently active SCIP indexer.
---@return string?
function M.indexer()
        return M.current.indexer
end

---Return the active SCIP process object.
---@return vim.SystemObj?
function M.job()
        return M.current.job
end

---Return the project root currently being indexed.
---@return string?
function M.root()
        return M.current.root
end

---Return the recorded high-resolution start timestamp.
---@return integer
function M.started_at()
        return M.current.started_at
end

return M
