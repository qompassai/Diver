-- /qompassai/Diver/lua/ai/rose/model.lua
-- Full-config model router: Ollama default, cloud strictly opt-in (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------

local M = {}

---@param config table resolved Rose config
---@return string name  -- selected provider name, 'ollama' when unconfigured
local function name(config)
    return type(config.providers) == 'table' and config.providers.provider or 'ollama'
end

---@param config table
---@return boolean? ok
---@return string? err
function M.validate(config)
    if type(config) ~= 'table' then
        return nil, 'model configuration must be a table'
    end
    if name(config) == 'ollama' then
        return true
    end
    local ok, result = pcall(require('ai.rose.providers').resolve, config)
    if not ok then
        local cleaned = tostring(result):gsub('^.-:%d+:%s*', '')
        return nil, cleaned
    end
    return true
end

---@param config table
---@return table info  -- { provider, model, cloud }
function M.describe(config)
    local provider = name(config)
    local selected = provider == 'ollama' and config.ollama or (config.providers and config.providers[provider])
    return {
        provider = provider,
        model = type(selected) == 'table' and selected.model or nil,
        cloud = provider ~= 'ollama',
    }
end

---@param config table
---@return table capabilities
function M.capabilities(config)
    if name(config) == 'ollama' then
        return {
            provider = 'ollama',
            cloud = false,
            tools = true,
            chat = true,
            json_request = false,
            sse = false,
        }
    end
    local ok, selected, api = pcall(require('ai.rose.providers').resolve, config)
    if not ok then
        return { provider = name(config), cloud = true, enabled = false, tools = false }
    end
    return {
        provider = selected.name,
        api = selected.api,
        cloud = true,
        enabled = true,
        chat = true,
        tools = api.tools and selected.capabilities.tools == true,
        json_request = true,
        sse = true,
        chat_streaming = false,
        opaque_replay = true,
        citations = true,
        realtime = false,
        multipart = false,
        binary_media = false,
    }
end

---@param config table
---@param messages table[]
---@param tools table[]?
---@param callback fun(err: string?, message: table?)
---@return table token
function M.chat(config, messages, tools, callback)
    if name(config) == 'ollama' then
        return require('ai.rose.ollama').chat(config.ollama, messages, tools, callback)
    end
    return require('ai.rose.providers').chat(config, messages, tools, callback)
end

---@param config table
---@param spec table raw JSON request spec
---@param callback fun(err: string?, result: any)
---@return table token
function M.request(config, spec, callback)
    if type(spec) ~= 'table' or type(spec.path) ~= 'string' or spec.path == '' then
        vim.schedule(function()
            callback('raw JSON request spec requires a path string')
        end)
        return { cancel = function() end }
    end
    -- providers.request validates the exact field set; copy it explicitly.
    ---@type AiRoseRawRequestSpec
    local request_spec = {
        path = spec.path,
        method = spec.method,
        body = spec.body,
        stream = spec.stream,
        on_event = spec.on_event,
    }
    if name(config) == 'ollama' then
        vim.schedule(function()
            callback('raw JSON requests need an explicitly selected cloud provider')
        end)
        return { cancel = function() end }
    end
    return require('ai.rose.providers').request(config, request_spec, callback)
end

-- Cancel in-flight cloud provider requests.
--- Cancel in-flight model requests.
function M.stop()
    if package.loaded['ai.rose.providers.transport'] then
        package.loaded['ai.rose.providers.transport'].stop()
    end
end

return M
