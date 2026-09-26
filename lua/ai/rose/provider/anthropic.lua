-- /qompassai/Diver/lua/ai/rose/provider/anthropic.lua
-- Anthropic legacy provider class (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Historical provider-class interface kept for compatibility. The modern
-- ai.rose.providers registry is the preferred native interface.

local logger = require('ai.rose.logger')
local utils = require('ai.rose.utils')

---@class AiRoseProviderAnthropic
---@field endpoint string
---@field api_key string|string[]|nil
---@field name string
local Anthropic = {}
Anthropic.__index = Anthropic

-- Available API parameters for Anthropic
-- https://docs.anthropic.com/en/api/messages
local AVAILABLE_API_PARAMETERS = {
    -- required
    model = true,
    messages = true,
    max_tokens = true,
    -- optional
    metadata = true,
    stop_sequences = true,
    stream = true,
    system = true,
    temperature = true,
    tool_choice = true,
    tools = true,
    top_k = true,
    top_p = true,
}

-- Creates a new Anthropic instance
---@param endpoint string
---@param api_key string|string[]|nil
---@return AiRoseProviderAnthropic
function Anthropic:new(endpoint, api_key)
    return setmetatable({
        endpoint = endpoint,
        api_key = api_key,
        name = 'anthropic',
    }, self)
end

-- Placeholder for setting model (not implemented)
---@param _ any
function Anthropic:set_model(_) end

-- Preprocesses the payload before sending to the API
---@param payload table
---@return table
function Anthropic:preprocess_payload(payload)
    return utils.filter_payload_parameters(AVAILABLE_API_PARAMETERS, payload)
end

-- Returns the curl parameters for the API request
---@return table
function Anthropic:curl_params()
    return {
        self.endpoint,
        '-H',
        'x-api-key: ' .. self.api_key,
        '-H',
        'anthropic-version: 2023-06-01',
    }
end

-- Verifies the API key or executes a routine to retrieve it
---@return boolean
function Anthropic:verify()
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
function Anthropic:process_stdout(response)
    if response:match('content_block_delta') and response:match('text_delta') then
        local success, decoded_line = pcall(vim.json.decode, response)
        if
            success
            and type(decoded_line) == 'table'
            and type(decoded_line.delta) == 'table'
            and decoded_line.delta.type == 'text_delta'
            and type(decoded_line.delta.text) == 'string'
        then
            return decoded_line.delta.text
        else
            logger.debug('Could not process response: ' .. response)
        end
    end
end

-- Processes the onexit event from the API response
---@param res string
function Anthropic:process_onexit(res)
    local success, parsed = pcall(vim.json.decode, res)
    if
        success
        and type(parsed) == 'table'
        and type(parsed.error) == 'table'
        and type(parsed.error.message) == 'string'
    then
        logger.error(string.format('Anthropic - message: %s type: %s', parsed.error.message, parsed.error.type))
    end
end

-- Returns the list of available models
---@return string[]
function Anthropic:get_available_models()
    return {
        'claude-3-5-sonnet-latest',
        'claude-3-5-sonnet-20241022',
        'claude-3-5-sonnet-20240620',
        'claude-3-5-haiku-latest',
        'claude-3-5-haiku-20241022',
        'claude-3-sonnet-20240229',
        'claude-3-haiku-20240307',
        'claude-3-opus-20240229',
        'claude-3-opus-latest',
    }
end

return Anthropic
