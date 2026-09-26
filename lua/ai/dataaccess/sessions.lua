-- /qompassai/Diver/lua/ai/dataaccess/sessions.lua
-- Qompass AI Data Access Session Registry (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- Refcounted session manager over the lua/config/data/ adapters. One
-- session object exists per (adapter, dsn-key); acquiring the same key
-- twice returns the same object with its refcount raised, never a
-- second client. Releasing drops the refcount, and the session is
-- forgotten at zero.
--
-- Plain words: this is the coat check for database connections. The
-- first agent to ask for a database gets a ticket; every later agent
-- asking for the same one shares the ticket instead of opening a new
-- connection. When the last agent hands its ticket back, the entry is
-- thrown away.
--
-- Honest scope note: the underlying config.data adapters run each
-- query as one bounded subprocess (vim.system with a timeout) rather
-- than holding a persistent client process, so there is no live socket
-- or handle to keep warm here. Session reuse means one shared session
-- record per key -- no duplicate bookkeeping, no repeat validation --
-- and the guarantee that this layer never asks an adapter to spawn two
-- clients for the same key at once. The session never stores query
-- text or result rows.

local M = {}

local SESSION_COUNT_MAX = 64
local KEY_BYTES_MAX = 2048

---@class DataSession
---@field key string Session key: 'dataaccess:' .. adapter .. '|' .. dsn identity.
---@field adapter_name string Canonical adapter name.
---@field adapter table The config.data adapter module.
---@field target string|table File path or cleaned connection table.
---@field label string Human-readable, secret-free session label.
---@field refcount integer Live acquisitions.
---@field created_at integer os.time() at creation.
---@field query_count integer Queries run through this session.
---@field write_count integer Write queries run through this session.
---@field last_error string? Redacted last failure, or nil.

local sessions = {} ---@type table<string, DataSession>

---@param key any
---@return boolean
local function valid_key(key)
    return type(key) == 'string' and key ~= '' and #key <= KEY_BYTES_MAX and key:find('%z') == nil
end

---Acquire the session for key, creating it on first use. The same key
---always yields the same session object; the refcount tracks how many
---callers currently hold it.
---@param key string Session key.
---@param adapter_name string Canonical adapter name.
---@param adapter table config.data adapter module.
---@param target string|table File path or cleaned connection table.
---@param label string Secret-free session label.
---@return DataSession? session
---@return string? err
function M.acquire(key, adapter_name, adapter, target, label)
    assert(type(adapter_name) == 'string', 'adapter_name must be a string')
    assert(type(adapter) == 'table', 'adapter must be a table')
    assert(type(label) == 'string', 'label must be a string')
    if not valid_key(key) then
        return nil, 'session key is invalid'
    end
    local session = sessions[key]
    if session ~= nil then
        session.refcount = session.refcount + 1
        return session, nil
    end
    local count = 0
    for _ in pairs(sessions) do
        count = count + 1
    end
    if count >= SESSION_COUNT_MAX then
        return nil, 'too many data sessions'
    end
    session = {
        key = key,
        adapter_name = adapter_name,
        adapter = adapter,
        target = target,
        label = label,
        refcount = 1,
        created_at = os.time(),
        query_count = 0,
        write_count = 0,
        last_error = nil,
    }
    sessions[key] = session
    return session, nil
end

---Release one acquisition. The session is forgotten when the last
---holder releases it. Releasing an unknown key is a no-op returning 0.
---@param key string Session key.
---@return integer remaining Refcount after release, 0 when forgotten.
function M.release(key)
    if not valid_key(key) then
        return 0
    end
    local session = sessions[key]
    if session == nil then
        return 0
    end
    session.refcount = session.refcount - 1
    if session.refcount <= 0 then
        sessions[key] = nil
        return 0
    end
    return session.refcount
end

---Look up a session without changing its refcount.
---@param key string Session key.
---@return DataSession? session
function M.get(key)
    if not valid_key(key) then
        return nil
    end
    return sessions[key]
end

---List sessions sorted by label for deterministic output. The target
---connection tables are never exposed here: only the secret-free
---label leaves this module.
---@return DataSession[] list
function M.list()
    local list = {}
    for _, session in pairs(sessions) do
        list[#list + 1] = session
    end
    table.sort(list, function(a, b)
        return a.label < b.label
    end)
    return list
end

---Forget every session regardless of refcount. Used at shutdown and
---in tests; normal callers use release().
function M.reset()
    for key in pairs(sessions) do
        sessions[key] = nil
    end
end

return M
