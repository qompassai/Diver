-- /qompassai/Diver/lua/ai/security/annotations.lua
-- WebMCP ToolAnnotations model for Diver's agent tools.
--
-- Plain words: every tool an agent can call gets safety labels
-- borrowed from the WebMCP standard, so both the agent and any
-- human watching know what the tool is allowed to do:
--
--   readOnlyHint         the tool only looks, it never changes
--                        anything (SCIP queries, passive recon)
--   consequentialHint    the tool does something real: writes
--                        files, runs a refactor, or touches a live
--                        target (active scanning, exploitation)
--   untrustedContentHint the tool drinks from the open internet,
--                        so its output must be treated as possibly
--                        hostile before anyone acts on it
--   debugging            the tool is developer tooling, not for
--                        end-user interaction (always false here;
--                        carried so the wire shape matches the spec)
--
-- The gate in lua/ai/recon/gate.lua reads these labels to decide
-- whether a call needs an explicit confirmation first.
---@module 'security.annotations'

local M = {}

---Tags that mark a skill as actively touching the target.
local ACTIVE_TAGS = {
    attack = true,
    bypass = true,
    exploitation = true,
    injection = true,
    privesc = true,
    takeover = true,
}

---Categories whose tools always count as consequential.
local CONSEQUENTIAL_CATEGORIES = {
    auth = true,
    chains = true,
    infra = true,
    redteam = true,
}

---Tags that mark a recon skill as purely passive observation.
local PASSIVE_TAGS = {
    enumeration = true,
    fingerprinting = true,
    osint = true,
    passive = true,
}

---Skill categories that only observe. Everything else is consequential
---until proven otherwise: default-deny beats default-allow.
local READ_ONLY_CATEGORIES = {
    meta = true,
}

---@class ToolAnnotations
---@field consequentialHint boolean
---@field debugging boolean
---@field readOnlyHint boolean
---@field untrustedContentHint boolean

---Blank annotations: no hints set.
---@return ToolAnnotations
function M.blank()
    return {
        consequentialHint = false,
        debugging = false,
        readOnlyHint = false,
        untrustedContentHint = false,
    }
end

---Annotate a bridge endpoint by its effect kind.
---@param kind string 'read' | 'write' | 'execute'
---@return ToolAnnotations
function M.for_endpoint(kind)
    assert(kind == 'read' or kind == 'write' or kind == 'execute', 'kind must be read, write, or execute')
    local ann = M.blank()
    if kind == 'read' then
        ann.readOnlyHint = true
        return ann
    end
    ann.consequentialHint = true
    if kind == 'execute' then
        ann.untrustedContentHint = true
    end
    return ann
end

---Classify a recon skill into WebMCP annotations.
---skill = { name: string, category: string?, tags: string[]? }
---@param skill table
---@return ToolAnnotations
function M.for_skill(skill)
    assert(type(skill) == 'table', 'skill must be a table')
    assert(type(skill.name) == 'string', 'skill.name must be a string')
    local ann = M.blank()
    local category = skill.category or ''
    local tags = skill.tags or {}

    if CONSEQUENTIAL_CATEGORIES[category] then
        ann.consequentialHint = true
        return ann
    end

    local passive = READ_ONLY_CATEGORIES[category] == true
    local active = false
    for _, tag in ipairs(tags) do
        local t = tostring(tag):lower()
        if PASSIVE_TAGS[t] then
            passive = true
        end
        if ACTIVE_TAGS[t] then
            active = true
        end
    end

    if active then
        ann.consequentialHint = true
        return ann
    end
    if passive or category == 'recon' then
        ann.readOnlyHint = true
        -- Recon output comes from live hosts: treat it as untrusted
        -- content before the agent acts on it.
        ann.untrustedContentHint = true
        return ann
    end
    -- Unknown category: consequential until classified.
    ann.consequentialHint = true
    return ann
end

---True when the annotations require an explicit confirmation before
---the tool may run (unless auto-authorize is enabled for the caller).
---@param ann ToolAnnotations
---@return boolean
function M.needs_confirmation(ann)
    assert(type(ann) == 'table', 'ann must be a table')
    return ann.consequentialHint == true
end

return M
