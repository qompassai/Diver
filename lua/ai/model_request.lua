-- /qompassai/Diver/lua/ai/model_request.lua
-- Provider-neutral ModelRequest for Phlow forward-compatibility (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- NEUTRAL SHAPE (this module) <-> LEGACY PER-PROVIDER SHAPE (existing code)
--
-- Neutral (forward-compatible with Phlow's ModelRequest contract):
--   objective            string?               what the workflow tries to accomplish
--   messages             table[]?              normalized chat messages {role, content, ...}
--   context              table?                workflow-supplied context (buffers, facts, notes)
--   tools                table[]?              function tool schemas {type='function', ['function']={...}}
--   output_schema        table?                desired output shape (JSON schema)
--   required_capabilities table<string,boolean> SET OF CAPABILITY STRINGS, never vendor names
--   privacy              table?                egress policy (e.g. allow_cloud, redaction)
--   budget               table?                per-request limits (max_context, max_tool_calls, ...)
--   preferences          table?                routing preferences; never a vendor/model name
--   provenance_policy    table?                replay/audit/migrate requirements
--
-- Legacy (unchanged behavior, ai.rose.model.chat(config, messages, tools, cb)):
--   * provider chosen by NAME in config.providers.provider ('ollama', 'openai',
--     'anthropic', ...); model chosen by vendor MODEL STRING in config.ollama.model
--     or config.providers[<name>].model. to_legacy() keeps those in the config.
--   * messages/tools map 1:1 onto the legacy chat arguments; objective,
--     context, output_schema, budget, privacy, preferences and provenance_policy
--     have no legacy slot and are retained (not forwarded) so behavior is unchanged.
--   * Legacy vendor-only params pass through untouched (documented with PHLOW):
--     - rose/ollama.lua merges config.options verbatim into the Ollama payload.
--     - rose/providers/common.lua merges config.options into chat/messages/
--       responses payloads (reserved keys model/messages/input/tools/stream excluded).
--     - rose/providers/common.lua pins _provider history to the same endpoint,
--       API and model; replay is not canonical state.
--   * Privacy: allow_cloud still lives in config.providers.allow_cloud; the
--     neutral privacy.allow_cloud is validated but not wired into the legacy
--     config here.

local M = {}

local CAPABILITY_STRINGS_MAX = 16
local FIELD_BYTES_MAX = 1024

-- Capability strings Phlow routing understands; vendor/model names are rejected.
local KNOWN_CAPABILITIES = {
    streaming = true,
    tools = true,
    vision = true,
    long_context = true,
    structured_output = true,
    citations = true,
}

---@class AiModelRequest
---@field objective string?
---@field messages table[]?
---@field context table?
---@field tools table[]?
---@field output_schema table?
---@field required_capabilities table<string,boolean>
---@field privacy table?
---@field budget table?
---@field preferences table?
---@field provenance_policy table?

---@param value any
---@param name string
---@return string? err
local function check_string(value, name)
    if value == nil then
        return nil
    end
    if type(value) ~= 'string' or #value > FIELD_BYTES_MAX then
        return name .. ' must be a string of at most ' .. FIELD_BYTES_MAX .. ' bytes'
    end
    return nil
end

-- Normalize required_capabilities (accept a set or an array of capability
-- strings) and reject anything that is not a known capability string.
---@param given table?
---@return table<string,boolean>? set
---@return string? err
local function capability_set(given)
    if given == nil then
        return {}, nil
    end
    if type(given) ~= 'table' then
        return nil, 'required_capabilities must be a set or array of capability strings'
    end
    local set, count = {}, 0
    for key, value in pairs(given) do
        count = count + 1
        if count > CAPABILITY_STRINGS_MAX then
            return nil, 'required_capabilities holds too many entries'
        end
        local capability = type(key) == 'string' and key or value
        if type(capability) ~= 'string' or not KNOWN_CAPABILITIES[capability] then
            return nil, 'required_capabilities accepts capability strings only, got: ' .. tostring(capability)
        end
        set[capability] = true
    end
    return set, nil
end

-- Build or normalize a provider-neutral ModelRequest. Idempotent: a request
-- produced by M.new passes through unchanged. Never embeds vendor names.
---@param spec table? raw neutral spec
---@return AiModelRequest? request
---@return string? err
function M.new(spec)
    spec = spec == nil and {} or spec
    if type(spec) ~= 'table' then
        return nil, 'model request must be a table'
    end
    local err = check_string(spec.objective, 'objective')
    if err then
        return nil, err
    end
    if spec.messages ~= nil and type(spec.messages) ~= 'table' then
        return nil, 'messages must be a message array'
    end
    if spec.tools ~= nil and type(spec.tools) ~= 'table' then
        return nil, 'tools must be a tool-schema array'
    end
    if spec.output_schema ~= nil and type(spec.output_schema) ~= 'table' then
        return nil, 'output_schema must be a table'
    end
    local capabilities, cap_err = capability_set(spec.required_capabilities)
    if not capabilities then
        return nil, cap_err
    end
    for _, field in ipairs({ 'context', 'privacy', 'budget', 'preferences', 'provenance_policy' }) do
        if spec[field] ~= nil and type(spec[field]) ~= 'table' then
            return nil, field .. ' must be a table'
        end
    end
    -- Preferences describe routing wants; vendor/model selection stays in the
    -- legacy config, so naming one here is a caller bug, not a routing input.
    local preferences = spec.preferences
    if
        preferences ~= nil
        and (preferences.provider ~= nil or preferences.vendor ~= nil or preferences.model ~= nil)
    then
        return nil, 'preferences must describe capabilities, never vendor or model names'
    end
    return {
        objective = spec.objective,
        messages = spec.messages,
        context = spec.context,
        tools = spec.tools,
        output_schema = spec.output_schema,
        required_capabilities = capabilities,
        privacy = spec.privacy,
        budget = spec.budget,
        preferences = preferences,
        provenance_policy = spec.provenance_policy,
    },
        nil
end

-- Map a neutral request onto the existing per-provider call shape without
-- changing provider behavior. Legacy call: ai.rose.model.chat(config, messages,
-- tools, callback), where config.providers.provider names the provider.
-- Objective, context, output_schema, budget, privacy, preferences and
-- provenance_policy are retained on the returned table for future Phlow
-- routing but are NOT forwarded to the provider.
---@param request table neutral ModelRequest (normalized or raw)
---@param provider string legacy provider name for ai.rose.model routing
---@return table? legacy  -- { provider, messages, tools, objective, output_schema, provenance_policy }
---@return string? err
function M.to_legacy(request, provider)
    if type(provider) ~= 'string' or provider == '' then
        return nil, 'to_legacy requires a legacy provider name'
    end
    local normalized, err = M.new(request)
    if not normalized then
        return nil, err
    end
    return {
        provider = provider,
        messages = normalized.messages or {},
        tools = normalized.tools,
        objective = normalized.objective,
        output_schema = normalized.output_schema,
        provenance_policy = normalized.provenance_policy,
    },
        nil
end

return M
