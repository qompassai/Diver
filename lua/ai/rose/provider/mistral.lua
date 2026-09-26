-- /qompassai/Diver/lua/ai/rose/provider/mistral.lua
-- Mistral legacy provider class (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Historical provider-class interface kept for compatibility. The modern
-- ai.rose.providers registry is the preferred native interface.

local logger = require('ai.rose.logger')
local utils = require('ai.rose.utils')

---@class AiRoseProviderMistral
---@field endpoint string
---@field api_key string|string[]|nil
---@field name string
local Mistral = {}
Mistral.__index = Mistral

-- Available API parameters for Mistral
-- https://docs.mistral.ai/api/
local AVAILABLE_API_PARAMETERS = {
    -- required
    model = true,
    messages = true,
    -- optional
    temperature = true,
    top_p = true,
    max_tokens = true,
    min_tokens = true,
    stream = true,
    stop = true,
    random_seed = true,
    safe_prompt = true,
}

-- Creates a new Mistral instance
---@param endpoint string
---@param api_key string|string[]|nil
---@return AiRoseProviderMistral
function Mistral:new(endpoint, api_key)
    return setmetatable({
        endpoint = endpoint,
        api_key = api_key,
        name = 'mistral',
    }, self)
end

-- Placeholder for setting model (not implemented)
---@param _ any
function Mistral:set_model(_) end

-- Preprocesses the payload before sending to the API
---@param payload table
---@return table
function Mistral:preprocess_payload(payload)
    for _, message in ipairs(payload.messages) do
        message.content = message.content:gsub('^%s*(.-)%s*$', '%1')
    end
    return utils.filter_payload_parameters(AVAILABLE_API_PARAMETERS, payload)
end

-- Returns the curl parameters for the API request
---@return table
function Mistral:curl_params()
    return {
        self.endpoint,
        '-H',
        'authorization: Bearer ' .. self.api_key,
    }
end

-- Verifies the API key or executes a routine to retrieve it
---@return boolean
function Mistral:verify()
    local current_key = self.api_key
    if type(current_key) == 'table' then
        local key, err = utils.key_from_command(current_key)
        if not key then
            logger.error('Error reading API key of ' .. self.name .. ': ' .. tostring(err))
            return false
        end
        self.api_key = key
        return true
    elseif type(current_key) == 'string' and current_key:match('%S') then
        return true
    else
        logger.error('Error with API key ' .. self.name .. ' ' .. vim.inspect(self.api_key))
        return false
    end
end

-- Processes the stdout from the API response
---@param response string
---@return string|nil
function Mistral:process_stdout(response)
    if response:match('chat%.completion%.chunk') or response:match('chat%.completion') then
        local success, content = pcall(vim.json.decode, response)
        if
            success
            and type(content) == 'table'
            and type(content.choices) == 'table'
            and type(content.choices[1]) == 'table'
            and type(content.choices[1].delta) == 'table'
            and type(content.choices[1].delta.content) == 'string'
        then
            return content.choices[1].delta.content
        else
            logger.debug('Could not process response: ' .. response)
        end
    end
end

-- Processes the onexit event from the API response
---@param res string
function Mistral:process_onexit(res)
    local success, parsed = pcall(vim.json.decode, res)
    if success and type(parsed) == 'table' and type(parsed.message) == 'string' then
        logger.error('Mistral - message: ' .. parsed.message)
    end
end

-- Returns the list of available models
---@return string[]
function Mistral:get_available_models()
    return {
        'codestral-latest',
        'mistral-tiny',
        'mistral-small-latest',
        'mistral-medium-latest',
        'mistral-large-latest',
        'open-mistral-7b',
        'open-mixtral-8x7b',
        'open-mixtral-8x22b',
    }
end

return Mistral
