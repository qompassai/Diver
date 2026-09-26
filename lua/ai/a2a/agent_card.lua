-- /qompassai/Diver/lua/ai/a2a/agent_card.lua
-- Qompass AI A2A Agent Directory (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- An AgentCard is A2A's discovery document: who the agent is, where to
-- POST JSON-RPC, and what it can do. This module validates cards
-- against the required fields, fetches them from well-known URIs, and
-- keeps the local directory that tasks dispatch against. Cards are
-- never executed; only their resolved endpoint URL is ever used,
-- and only after the client's scheme/host checks pass.

local client = require('ai.a2a.client')

local M = {}

local WELL_KNOWN_PATH = '/.well-known/agent-card.json'
local CARD_MAX_BYTES = 256 * 1024
local FETCH_TIMEOUT_MS = 10000

---@class A2aAgentSkill
---@field id string
---@field name string
---@field description? string

---@class A2aAgentCard
---@field name string
---@field url? string POST endpoint (v0.3 card)
---@field supportedInterfaces? table v1.0 interfaces; first JSONRPC entry preferred
---@field version string
---@field description? string
---@field capabilities? { streaming?: boolean, pushNotifications?: boolean }
---@field skills? A2aAgentSkill[]

---@type table<string, A2aAgentCard>
local directory = {}

---@param card table
---@return boolean, string?
function M.validate(card)
    if type(card) ~= 'table' then
        return false, 'card must be a table'
    end
    if type(card.name) ~= 'string' or card.name == '' then
        return false, 'card.name must be a nonempty string'
    end
    -- v0.3 cards carry card.url; v1.0 cards carry
    -- card.supportedInterfaces[]. card_endpoint accepts either.
    local _, url_err = client.card_endpoint(card)
    if url_err then
        return false, 'card endpoint: ' .. tostring(url_err)
    end
    if type(card.version) ~= 'string' or card.version == '' then
        return false, 'card.version must be a nonempty string'
    end
    if card.skills ~= nil then
        if type(card.skills) ~= 'table' then
            return false, 'card.skills must be a list'
        end
        for i, skill in ipairs(card.skills) do
            if type(skill) ~= 'table' then
                return false, 'card.skills[' .. i .. '] must be a table'
            end
            if type(skill.id) ~= 'string' or type(skill.name) ~= 'string' then
                local where = 'card.skills[' .. i .. ']'
                return false, where .. ' needs string id and name'
            end
        end
    end
    return true
end

---@param name string
---@param card A2aAgentCard
---@return boolean, string?
function M.register(name, card)
    if type(name) ~= 'string' or name == '' then
        return false, 'name must be a nonempty string'
    end
    local ok, err = M.validate(card)
    if not ok then
        return false, err
    end
    directory[name] = card
    return true
end

---@param name string
---@return A2aAgentCard?
function M.get(name)
    return directory[name]
end

---@return string[] Sorted directory names.
function M.list()
    local names = {}
    for name in pairs(directory) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

---@param base_url string Agent origin, e.g. http://127.0.0.1:8100
---@param callback fun(ok: boolean, card: A2aAgentCard?, err: string?)
function M.fetch(base_url, callback)
    assert(type(base_url) == 'string', 'base_url must be a string')
    assert(type(callback) == 'function', 'callback must be a function')
    local url_ok, url_err = client.check_url(base_url)
    if not url_ok then
        callback(false, nil, url_err)
        return
    end
    local url = base_url:gsub('/+$', '') .. WELL_KNOWN_PATH
    client.get(url, {
        timeout_ms = FETCH_TIMEOUT_MS,
        max_bytes = CARD_MAX_BYTES,
    }, function(ok, result, err)
        if not ok then
            callback(false, nil, err)
            return
        end
        local valid, verr = M.validate(result)
        if not valid then
            callback(false, nil, 'fetched card invalid: ' .. tostring(verr))
            return
        end
        callback(true, result, nil)
    end)
end

return M
