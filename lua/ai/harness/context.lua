-- /qompassai/diver/lua/ai/harness/context.lua
-- Qompass AI Agent Harness: immutable budgeted context snapshots (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Context is an immutable snapshot assembled by explicit providers, never
-- an ever-growing transcript and never scraped ad hoc by adapters.
-- Providers are pure-ish functions returning typed items with provenance,
-- trust classification, byte estimates, and content hashes. Budgeting is
-- deterministic: required instructions first, retrieved context last.

local M = {}

local PROVIDERS_MAX = 64
local ITEMS_MAX = 4096

---@class AiHarnessContextItem
---@field provider string
---@field kind string
---@field path? string
---@field bytes integer
---@field hash string
---@field trust 'trusted'|'workspace'|'untrusted'
---@field data string

---Deterministic budget priority: lower wins.
M.PRIORITY = {
    required = 1,
    task_local = 2,
    diagnostics = 3,
    retrieved = 4,
}

---Create a snapshot for a workspace. Seal it after assembly.
---@param workspace string
---@return table? snapshot
---@return string? err
function M.new_snapshot(workspace)
    if type(workspace) ~= 'string' or workspace == '' then
        return nil, 'context workspace must be a non-empty string'
    end
    return { workspace = workspace, items = {}, sealed = false }
end

---Register a provider: pure-ish `produce(snapshot) -> items|nil, err`.
---@param name string
---@param priority integer one of M.PRIORITY values
---@param produce fun(snapshot: table): AiHarnessContextItem[]?, string?
---@return table? provider
---@return string? err
function M.new_provider(name, priority, produce)
    if type(name) ~= 'string' or name == '' then
        return nil, 'provider name must be a non-empty string'
    end
    local known = false
    for _, value in pairs(M.PRIORITY) do
        if value == priority then
            known = true
            break
        end
    end
    if not known then
        return nil, 'provider priority must be a known M.PRIORITY value'
    end
    if type(produce) ~= 'function' then
        return nil, 'provider produce must be a function'
    end
    return { name = name, priority = priority, produce = produce }
end

---@param item table
---@return boolean ok
---@return string? err
local function validate_item(item)
    if type(item) ~= 'table' then
        return nil, 'context item must be a table'
    end
    if type(item.kind) ~= 'string' or item.kind == '' then
        return nil, 'context item.kind must be a non-empty string'
    end
    if type(item.bytes) ~= 'number' or item.bytes < 0 then
        return nil, 'context item.bytes must be a non-negative number'
    end
    if type(item.hash) ~= 'string' or item.hash == '' then
        return nil, 'context item.hash must be a non-empty string'
    end
    if item.trust ~= 'trusted' and item.trust ~= 'workspace' and item.trust ~= 'untrusted' then
        return nil, 'context item.trust must be trusted, workspace, or untrusted'
    end
    return true
end

---Run a provider and attach its items to the snapshot.
---@param snapshot table
---@param provider table
---@return boolean ok
---@return string? err
function M.attach(snapshot, provider)
    assert(snapshot ~= nil, 'snapshot required')
    assert(provider ~= nil, 'provider required')
    if snapshot.sealed then
        return nil, 'snapshot is sealed'
    end
    if #snapshot.items >= ITEMS_MAX then
        return nil, 'snapshot item bound exceeded'
    end
    local ok, items_or_err = pcall(provider.produce, snapshot)
    if not ok then
        return nil, 'provider ' .. provider.name .. ' raised: ' .. tostring(items_or_err)
    end
    local items = items_or_err
    if items == nil then
        return true
    end
    if type(items) ~= 'table' then
        return nil, 'provider ' .. provider.name .. ' must return a table or nil'
    end
    for _, item in ipairs(items) do
        local valid, err = validate_item(item)
        if not valid then
            return nil, 'provider ' .. provider.name .. ': ' .. tostring(err)
        end
        item.provider = provider.name
        item.priority = provider.priority
        snapshot.items[#snapshot.items + 1] = item
    end
    return true
end

---No further attaches after sealing.
---@param snapshot table
function M.seal(snapshot)
    assert(snapshot ~= nil, 'snapshot required')
    snapshot.sealed = true
end

---Deterministic budgeting: sort by (priority, provider, kind), keep items
---that fit in max_bytes. Returns kept items and the dropped count.
---@param snapshot table
---@param max_bytes integer
---@return AiHarnessContextItem[] kept
---@return integer dropped
function M.budget(snapshot, max_bytes)
    assert(snapshot ~= nil, 'snapshot required')
    assert(type(max_bytes) == 'number' and max_bytes >= 0, 'max_bytes must be non-negative')
    local ordered = {}
    for _, item in ipairs(snapshot.items) do
        ordered[#ordered + 1] = item
    end
    table.sort(ordered, function(a, b)
        if a.priority ~= b.priority then
            return a.priority < b.priority
        end
        if a.provider ~= b.provider then
            return a.provider < b.provider
        end
        return a.kind < b.kind
    end)
    local kept = {}
    local used_bytes = 0
    local dropped = 0
    for _, item in ipairs(ordered) do
        if used_bytes + item.bytes <= max_bytes then
            kept[#kept + 1] = item
            used_bytes = used_bytes + item.bytes
        else
            dropped = dropped + 1
        end
    end
    return kept, dropped
end

---Manifest of items: metadata only, never full contents.
---@param snapshot table
---@return table
function M.manifest(snapshot)
    assert(snapshot ~= nil, 'snapshot required')
    local items = {}
    local total_bytes = 0
    for _, item in ipairs(snapshot.items) do
        items[#items + 1] = {
            provider = item.provider,
            kind = item.kind,
            path = item.path,
            bytes = item.bytes,
            hash = item.hash,
            trust = item.trust,
        }
        total_bytes = total_bytes + item.bytes
    end
    return { workspace = snapshot.workspace, total_bytes = total_bytes, items = items }
end

M.PROVIDERS_MAX = PROVIDERS_MAX

return M
