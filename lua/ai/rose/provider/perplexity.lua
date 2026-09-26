-- /qompassai/Diver/lua/ai/rose/provider/perplexity.lua
-- Perplexity legacy provider class (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Historical provider-class interface kept for compatibility. The modern
-- ai.rose.providers registry is the preferred native interface. The
-- experimental WebSocket query path is not ported: it depended on an
-- optional third-party websocket.client module.

local logger = require('ai.rose.logger')
local utils = require('ai.rose.utils')

---@class AiRoseProviderPerplexity
---@field endpoint string
---@field api_key string|string[]|nil
---@field name string
---@field model string|nil
local Perplexity = {}
Perplexity.__index = Perplexity

-- Available API parameters for Perplexity
-- https://docs.perplexity.ai/api-reference/chat-completions
local AVAILABLE_API_PARAMETERS = {
    -- required
    model = true,
    messages = true,
    -- optional
    max_tokens = false,
    temperature = true,
    top_p = true,
    return_citations = true,
    search_domain_filter = true,
    return_images = true,
    return_related_questions = true,
    search_recency_filter = true,
    top_k = true,
    stream = true,
    presence_penalty = true,
    frequency_penalty = true,
}

-- Allowed models for Perplexity API
local ALLOWED_MODELS = {
    'llama-3.1-sonar-small-128k-online',
    'llama-3.1-sonar-large-128k-online',
    'llama-3.1-sonar-huge-128k-online',
    'llama-3.1-sonar-small-128k-chat',
    'llama-3.1-sonar-large-128k-chat',
    'llama-3.1-8b-instruct',
    'llama-3.1-70b-instruct',
}

-- Creates a new Perplexity instance
---@param endpoint string
---@param api_key string|string[]|nil
---@return AiRoseProviderPerplexity
function Perplexity:new(endpoint, api_key)
    return setmetatable({
        endpoint = endpoint,
        api_key = api_key,
        name = 'pplx',
    }, self)
end

-- Sets the model for the Perplexity instance
---@param model string
function Perplexity:set_model(model)
    if vim.tbl_contains(ALLOWED_MODELS, model) then
        self.model = model
    else
        logger.error('Invalid model specified. Only Sonar models are supported by the API.')
    end
end

-- Preprocesses the payload before sending to the API
---@param payload table
---@return table|nil
function Perplexity:preprocess_payload(payload)
    if type(payload.messages) ~= 'table' then
        logger.error('Messages are required in the payload')
        return nil
    end
    for _, message in ipairs(payload.messages) do
        if type(message) ~= 'table' or type(message.content) ~= 'string' then
            logger.error('Messages must contain text content')
            return nil
        end
        message.content = message.content:gsub('^%s*(.-)%s*$', '%1')
    end
    -- Explicitly convert numeric parameters to ensure correct types
    if payload.temperature then
        payload.temperature = tonumber(payload.temperature)
    end
    if payload.max_tokens then
        payload.max_tokens = tonumber(payload.max_tokens)
    end
    if payload.top_p then
        payload.top_p = tonumber(payload.top_p)
    end
    if payload.presence_penalty then
        payload.presence_penalty = tonumber(payload.presence_penalty)
    end
    if payload.frequency_penalty then
        payload.frequency_penalty = tonumber(payload.frequency_penalty)
    end

    -- Ensure only Sonar models are used
    if not vim.tbl_contains(ALLOWED_MODELS, payload.model) then
        logger.error('Invalid model specified. Only Sonar models are supported by the API.')
        return nil
    end

    return utils.filter_payload_parameters(AVAILABLE_API_PARAMETERS, payload)
end

-- Returns the curl parameters for the API request
---@return table
function Perplexity:curl_params()
    return {
        self.endpoint .. '/chat/completions',
        '-H',
        'Authorization: Bearer ' .. self.api_key,
        '-H',
        'Content-Type: application/json',
    }
end

-- Verifies the API key or executes a routine to retrieve it
---@return boolean
function Perplexity:verify()
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
function Perplexity:process_stdout(response)
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
---@param response string
---@return string|nil
function Perplexity:process_onexit(response)
    local success, parsed = pcall(vim.json.decode, response)
    if not success or type(parsed) ~= 'table' then
        return
    end
    if type(parsed.error) == 'table' and type(parsed.error.message) == 'string' then
        logger.error(
            string.format(
                'Perplexity - code: %s message: %s type: %s',
                parsed.error.code or 'N/A',
                parsed.error.message,
                parsed.error.type or 'N/A'
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

-- Sends a user query to the API for text generation (async, argv-form vim.system).
---@param payload table
---@param callback fun(result: string)
function Perplexity:send_query(payload, callback)
    if not self:verify() then
        logger.error('API key verification failed')
        return
    end

    -- Preprocess the payload as per API guidelines
    local processed = self:preprocess_payload(payload)
    if not processed then
        return
    end
    payload = processed
    payload.stream = true

    -- Align payload with Perplexity API's message structure
    if not payload.messages then
        logger.error('Messages are required in the payload')
        return
    end

    for i, message in ipairs(payload.messages) do
        if not message.role then
            if i == 1 then
                message.role = 'system' -- Assume the first message is a system message
            else
                message.role = 'user' -- Default to "user" for the rest
            end
        end
    end

    local argv = { 'curl', '-sS', '-N', '-X', 'POST' }
    vim.list_extend(argv, self:curl_params())
    argv[#argv + 1] = '-d'
    argv[#argv + 1] = vim.json.encode(payload)
    local chunks = {}
    local ok, result = pcall(vim.system, argv, {
        text = true,
        stdout = function(_, data)
            if data then
                chunks[#chunks + 1] = data
            end
        end,
    }, function(completed)
        local response = table.concat(chunks, '')
        if completed.code ~= 0 or response == '' then
            logger.error('No query response received')
            return
        end
        local query_result = self:process_onexit(response)
        if query_result then
            callback(query_result)
        else
            logger.error('Failed to retrieve valid response')
        end
    end)
    if not ok then
        logger.error('Could not start Perplexity query: ' .. tostring(result))
    end
end

-- Returns the list of available models
---@return string[]
function Perplexity:get_available_models()
    return ALLOWED_MODELS
end

-- Fixes to prevent repeated outputs and hallucinations
---@param response string
---@return string
function Perplexity:remove_repeated_text(response)
    local cleaned = response:gsub('%b<>', ''):gsub('%f[%w](%w+)%f[%W]%s*%1', '%1')
    return cleaned
end

return Perplexity
