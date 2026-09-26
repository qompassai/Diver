-- /qompassai/Diver/lua/ai/rose/provider/xai.lua
-- xAI legacy provider class (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Historical provider-class interface kept for compatibility. The modern
-- ai.rose.providers registry is the preferred native interface.

local OpenAI = require('ai.rose.provider.openai')
local logger = require('ai.rose.logger')
local utils = require('ai.rose.utils')

local xAI = setmetatable({}, { __index = OpenAI })
xAI.__index = xAI

-- Available API parameters for xAI
-- https://docs.x.ai/api/endpoints
local AVAILABLE_API_PARAMETERS = {
    -- required
    messages = true,
    model = true,
    -- optional
    frequency_penalty = true,
    logit_bias = true,
    logprobs = true,
    max_tokens = true,
    n = true,
    presence_penalty = true,
    response_format = true,
    seed = true,
    stop = true,
    stream = true,
    stream_options = true,
    temperature = true,
    tool_choice = true,
    tools = true,
    top_logprobs = true,
    top_p = true,
    user = true,
}

-- Creates a new xAI instance
---@param endpoint string
---@param api_key string|string[]|nil
---@return table
function xAI:new(endpoint, api_key)
    local instance = OpenAI.new(self, endpoint, api_key)
    instance.name = 'xai'
    return setmetatable(instance, self)
end

-- Preprocesses the payload before sending to the API
---@param payload table
---@return table
function xAI:preprocess_payload(payload)
    for _, message in ipairs(payload.messages) do
        message.content = message.content:gsub('^%s*(.-)%s*$', '%1')
    end
    return utils.filter_payload_parameters(AVAILABLE_API_PARAMETERS, payload)
end

-- Blocking curl GET through argv-form vim.system.
---@param url string
---@param api_key string
---@return string? stdout
local function curl_get(url, api_key)
    local ok, result = pcall(vim.system, {
        'curl',
        '-sS',
        url,
        '-H',
        'Authorization: Bearer ' .. api_key,
    }, { text = true })
    if not ok then
        return nil
    end
    local completed = result:wait()
    if completed.code ~= 0 then
        return nil
    end
    return completed.stdout
end

-- Returns the list of available models
---@param online boolean Whether to fetch models online
---@return string[]
function xAI:get_available_models(online)
    local ids = {
        'grok-beta',
    }
    if online and self:verify() then
        local key = self.api_key
        if type(key) ~= 'string' then
            logger.error('xAI - API key unavailable after verification')
            return ids
        end
        local stdout = curl_get('https://api.x.ai/v1/language-models', key)
        local parsed_response = utils.parse_raw_response(stdout)
        ids = {}
        if not parsed_response then
            logger.error('xAI - No model response received')
            return ids
        end
        self:process_onexit(parsed_response)
        local success, decoded = pcall(vim.json.decode, parsed_response)
        if success and type(decoded) == 'table' and type(decoded.models) == 'table' then
            for _, item in ipairs(decoded.models) do
                if type(item) == 'table' and type(item.id) == 'string' then
                    table.insert(ids, item.id)
                end
            end
        end
    end
    return ids
end

return xAI
