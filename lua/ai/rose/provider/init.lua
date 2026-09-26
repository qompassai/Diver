-- /qompassai/Diver/lua/ai/rose/provider/init.lua
-- Legacy provider-class registry (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Builds the legacy provider-class instances used by the historical chat
-- handler path. The modern ai.rose.providers registry is the preferred
-- native interface; these classes exist for compatibility.

local Anthropic = require('ai.rose.provider.anthropic')
local Gemini = require('ai.rose.provider.gemini')
local GitHub = require('ai.rose.provider.github')
local Groq = require('ai.rose.provider.groq')
local Mistral = require('ai.rose.provider.mistral')
local Nvidia = require('ai.rose.provider.nvidia')
local OpenAI = require('ai.rose.provider.openai')
local Perplexity = require('ai.rose.provider.perplexity')
local Qompass = require('ai.rose.provider.qompass')
local logger = require('ai.rose.logger')
local xAI = require('ai.rose.provider.xai')

local M = {}

---@param prov_name string
---@param endpoint string
---@param api_key string|string[]|nil
---@return table
function M.init_provider(prov_name, endpoint, api_key)
    local providers = {
        anthropic = Anthropic,
        gemini = Gemini,
        github = GitHub,
        groq = Groq,
        mistral = Mistral,
        nvidia = Nvidia,
        qompass = Qompass,
        openai = OpenAI,
        pplx = Perplexity,
        xai = xAI,
    }

    local ProviderClass = providers[prov_name]
    if not ProviderClass then
        logger.error('Unknown provider ' .. prov_name)
        return {}
    end

    if prov_name == 'qompass' then
        return ProviderClass:new(endpoint, {}) -- Pass an empty table for the API key
    end

    -- Check if API key is provided for other providers
    if not api_key or (type(api_key) == 'table' and #api_key == 0) then
        vim.ui.input({ prompt = 'Enter API key for ' .. prov_name .. ': ' }, function(input)
            if input then
                vim.fn.setenv(prov_name:upper() .. '_API_KEY', input)
                ProviderClass:new(endpoint, input)
                return
            else
                logger.error('API key is required for provider ' .. prov_name)
            end
        end)
        return {}
    end
    return ProviderClass:new(endpoint, api_key)
end

---@return string[] names
function M.names()
    local names = {}
    for name in pairs({
        anthropic = true,
        gemini = true,
        github = true,
        groq = true,
        mistral = true,
        nvidia = true,
        openai = true,
        perplexity = true,
        qompass = true,
        xai = true,
    }) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

return M
