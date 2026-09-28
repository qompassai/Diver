-- /qompassai/diver/lua/ai/harness/store.lua
-- Qompass AI Agent Harness: run persistence and checkpoints (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Phase 1 store is in-memory with deep copies at the boundary: runs,
-- checkpoints, and content-addressed artifacts. The database holds hashes
-- and metadata, never megabytes of tool output. On startup-equivalent
-- recovery, orphaned non-terminal runs are marked interrupted, never
-- blindly replayed. SQLite backing is Phase 5 work.

local types = require('ai.harness.types')

local M = {}

local RUNS_MAX = 1024
local ARTIFACTS_MAX = 4096
local ARTIFACT_BYTES_MAX = 10000000
local XOR_BITS_MAX = 32

---Deep copy with a bound on depth. Iterative to avoid recursion over
---attacker-controlled shapes.
---@param value any
---@param depth_max? integer
---@return any
local function deep_copy(value, depth_max)
    depth_max = depth_max or 8
    if type(value) ~= 'table' or depth_max <= 0 then
        return value
    end
    local out = {}
    for k, v in pairs(value) do
        out[k] = deep_copy(v, depth_max - 1)
    end
    return out
end

---Portable 32-bit xor without bitwise operators or the bit library.
---No LuaJIT bitop, no Lua 5.3+ operators: valid everywhere.
---Forward-declared: content_hash (below) runs before the definition.
---@param a integer
---@param b integer
---@return integer
local bxor32

---Content hash: sha256 when vim.fn is available, FNV-1a otherwise.
---The fallback is labeled in the hash prefix so it is never mistaken
---for a cryptographic digest. It only runs outside Neovim (tests), where
---Lua 5.4 integers keep the arithmetic exact.
---@param bytes string
---@return string
local function content_hash(bytes)
    if vim ~= nil and vim.fn ~= nil and vim.fn.sha256 ~= nil then
        return 'sha256:' .. vim.fn.sha256(bytes)
    end
    local hash = 2166136261
    for i = 1, #bytes do
        hash = bxor32(hash, bytes:byte(i)) % 4294967296
        hash = (hash * 16777619) % 4294967296
    end
    return string.format('fnv1a:%08x', hash)
end

---Portable 32-bit xor without bitwise operators or the bit library.
---No LuaJIT bitop, no Lua 5.3+ operators: valid everywhere.
---@param a integer
---@param b integer
---@return integer
function bxor32(a, b)
    local result = 0
    local place = 1
    for _ = 1, XOR_BITS_MAX do
        if a == 0 and b == 0 then
            break
        end
        local abit = a % 2
        local bbit = b % 2
        if abit ~= bbit then
            result = result + place
        end
        a = (a - abit) / 2
        b = (b - bbit) / 2
        place = place * 2
    end
    return result
end

---Create a store.
---@return table
function M.new()
    return { runs = {}, checkpoints = {}, artifacts = {}, artifact_count = 0 }
end

---@param store table
---@param run table
---@return boolean ok
---@return string? err
function M.save_run(store, run)
    assert(store ~= nil, 'store required')
    if type(run) ~= 'table' or type(run.id) ~= 'string' then
        return nil, 'run must be a table with an id'
    end
    local count = 0
    for _ in pairs(store.runs) do
        count = count + 1
    end
    if store.runs[run.id] == nil and count >= RUNS_MAX then
        return nil, 'run store is full'
    end
    local copy = deep_copy(run)
    copy.handle = nil
    store.runs[run.id] = copy
    return true
end

---@param store table
---@param id string
---@return table?
function M.get_run(store, id)
    assert(store ~= nil, 'store required')
    local run = store.runs[id]
    if run == nil then
        return nil
    end
    return deep_copy(run)
end

---Stored run ids, sorted for determinism.
---@param store table
---@return string[]
function M.list_runs(store)
    assert(store ~= nil, 'store required')
    local ids = {}
    for id in pairs(store.runs) do
        ids[#ids + 1] = id
    end
    table.sort(ids)
    return ids
end

---Checkpoint a run at a safe boundary: before a side effect, after its
---result is durably recorded, or while waiting for input/approval.
---@param store table
---@param run_id string
---@param label string
---@return boolean ok
---@return string? err
function M.checkpoint(store, run_id, label)
    assert(store ~= nil, 'store required')
    if type(label) ~= 'string' or label == '' then
        return nil, 'checkpoint label must be a non-empty string'
    end
    local run = store.runs[run_id]
    if run == nil then
        return nil, 'unknown run: ' .. tostring(run_id)
    end
    store.checkpoints[run_id] = store.checkpoints[run_id] or {}
    store.checkpoints[run_id][label] = {
        label = label,
        at_ns = types.now_ns(),
        state = deep_copy(run),
    }
    return true
end

---@param store table
---@param run_id string
---@param label string
---@return table?
function M.get_checkpoint(store, run_id, label)
    assert(store ~= nil, 'store required')
    local by_run = store.checkpoints[run_id]
    if by_run == nil then
        return nil
    end
    local checkpoint = by_run[label]
    if checkpoint == nil then
        return nil
    end
    return deep_copy(checkpoint)
end

---Mark orphaned non-terminal runs as interrupted. Never replays a
---mutating call.
---@param store table
---@return integer marked
function M.mark_interrupted(store)
    assert(store ~= nil, 'store required')
    local marked = 0
    for _, run in pairs(store.runs) do
        if not types.is_terminal(run.state) then
            run.state = 'interrupted'
            marked = marked + 1
        end
    end
    return marked
end

---Store artifact bytes under their content hash.
---@param store table
---@param bytes string
---@return string? hash
---@return string? err
function M.put_artifact(store, bytes)
    assert(store ~= nil, 'store required')
    if type(bytes) ~= 'string' then
        return nil, 'artifact bytes must be a string'
    end
    if #bytes > ARTIFACT_BYTES_MAX then
        return nil, 'artifact exceeds size bound'
    end
    if store.artifact_count >= ARTIFACTS_MAX then
        return nil, 'artifact store is full'
    end
    local hash = content_hash(bytes)
    if store.artifacts[hash] == nil then
        store.artifacts[hash] = bytes
        store.artifact_count = store.artifact_count + 1
    end
    return hash
end

---@param store table
---@param hash string
---@return string?
function M.get_artifact(store, hash)
    assert(store ~= nil, 'store required')
    return store.artifacts[hash]
end

return M
