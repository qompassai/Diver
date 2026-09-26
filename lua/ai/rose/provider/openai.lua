-- /qompassai/Diver/lua/ai/rose/provider/openai.lua
-- OpenAI legacy provider class (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Historical provider-class interface kept for compatibility. The modern
-- ai.rose.providers registry is the preferred native interface.

local logger = require('ai.rose.logger')
local utils = require('ai.rose.utils')

---@class AiRoseProviderOpenAI
---@field endpoint string
---@field api_key string|string[]|nil
---@field name string
local OpenAI = {}
OpenAI.__index = OpenAI

-- Available API parameters for OpenAI
-- https://platform.openai.com/docs/api-reference/chat
local AVAILABLE_API_PARAMETERS = {
    -- required
    messages = true,
    model = true,
    -- optional
    frequency_penalty = true,
    logit_bias = true,
    logprobs = true,
    top_logprobs = true,
    max_tokens = true,
    max_completion_tokens = true,
    presence_penalty = true,
    seed = true,
    stop = true,
    stream = true,
    temperature = true,
    top_p = true,
    tools = true,
    tool_choice = true,
}

-- Creates a new OpenAI instance
---@param endpoint string
---@param api_key string|string[]|nil
---@return AiRoseProviderOpenAI
function OpenAI:new(endpoint, api_key)
    return setmetatable({
        endpoint = endpoint,
        api_key = api_key,
        name = 'openai',
    }, self)
end

-- Placeholder for setting model (not implemented)
---@param _ any
function OpenAI:set_model(_) end

-- Preprocesses the payload before sending to the API
---@param payload table
---@return table
function OpenAI:preprocess_payload(payload)
    for _, message in ipairs(payload.messages) do
        message.content = message.content:gsub('^%s*(.-)%s*$', '%1')
    end
    -- Changes according to beta limitations of the reasoning API
    -- https://platform.openai.com/docs/guides/reasoning
    if payload.model and string.find(payload.model, 'o1', 1, true) then
        -- remove system prompt
        if payload.messages[1] and payload.messages[1].role == 'system' then
            table.remove(payload.messages, 1)
        end
        payload.logprobs = nil
        payload.temperature = 1
        payload.top_p = 1
        payload.top_n = 1
        payload.presence_penalty = 0
        payload.frequency_penalty = 0
    end
    return utils.filter_payload_parameters(AVAILABLE_API_PARAMETERS, payload)
end

-- Returns the curl parameters for the API request
---@return table
function OpenAI:curl_params()
    return {
        self.endpoint,
        '-H',
        'authorization: Bearer ' .. self.api_key,
    }
end

-- Verifies the API key or executes a routine to retrieve it
---@return boolean
function OpenAI:verify()
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
function OpenAI:process_stdout(response)
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
function OpenAI:process_onexit(res)
    local success, parsed = pcall(vim.json.decode, res)
    if not success or type(parsed) ~= 'table' then
        return
    end
    if type(parsed.error) == 'table' and type(parsed.error.message) == 'string' then
        logger.error(
            string.format(
                'OpenAI - code: %s message: %s type: %s',
                parsed.error.code,
                parsed.error.message,
                parsed.error.type
            )
        )
    elseif
        type(parsed.choices) == 'table'
        and type(parsed.choices[1]) == 'table'
        and type(parsed.choices[1].message) == 'table'
        and type(parsed.choices[1].message.content) == 'string'
    then
        return parsed.choices[1].message.content
    end
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
function OpenAI:get_available_models(online)
    local ids = {
        'gpt-4o',
        'gpt-4-turbo',
        'gpt-4-turbo-2024-04-09',
        'chatgpt-4o-latest',
        'gpt-4-turbo-preview',
        'gpt-3.5-turbo-instruct',
        'gpt-4-0125-preview',
        'gpt-3.5-turbo-0125',
        'gpt-3.5-turbo',
        'o1-preview-2024-09-12',
        'o1-preview',
        'gpt-4o-mini',
        'gpt-4o-2024-05-13',
        'gpt-4o-mini-2024-07-18',
        'gpt-4-1106-preview',
        'gpt-3.5-turbo-16k',
        'gpt-4o-2024-08-06',
        'gpt-3.5-turbo-1106',
        'gpt-4-0613',
        'o1-mini',
        'gpt-4',
        'o1-mini-2024-09-12',
        'gpt-3.5-turbo-instruct-0914',
    }
    if online and self:verify() then
        local key = self.api_key
        if type(key) ~= 'string' then
            logger.error('OpenAI - API key unavailable after verification')
            return ids
        end
        local stdout = curl_get('https://api.openai.com/v1/models', key)
        local parsed_response = utils.parse_raw_response(stdout)
        ids = {}
        if not parsed_response then
            logger.error('OpenAI - No model response received')
            return ids
        end
        self:process_onexit(parsed_response)
        local success, decoded = pcall(vim.json.decode, parsed_response)
        if success and type(decoded) == 'table' and type(decoded.data) == 'table' then
            for _, item in ipairs(decoded.data) do
                if type(item) == 'table' and type(item.id) == 'string' then
                    table.insert(ids, item.id)
                end
            end
        end
    end
    return ids
end

return OpenAI
