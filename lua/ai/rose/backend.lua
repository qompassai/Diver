-- /qompassai/Diver/lua/ai/rose/backend.lua
-- Rose chat backend over the bounded native HTTP client (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Rose speaks the Ollama API dialect; this module is the client for the
-- local rose server (see the rose section of ai.rose.config).

local M = {}

---@param config table rose section of the resolved config
---@param messages table[] normalized chat messages
---@param tools table[]? tool schemas
---@param callback fun(err: string?, message: table?)
---@return table token  -- token.cancel() aborts the request
function M.chat(config, messages, tools, callback)
    assert(type(config) == 'table', 'rose.chat: config must be a table')
    assert(type(messages) == 'table', 'rose.chat: messages must be a table')
    assert(type(callback) == 'function', 'rose.chat: callback must be a function')
    local payload = { model = config.model, messages = messages, stream = false }
    if tools and #tools > 0 then
        payload.tools = tools
    end
    -- PHLOW: config.options is vendor-only behavior passed verbatim into the
    -- chat payload; a neutral budget/preferences map is future work, not here.
    if config.options then
        payload.options = config.options
    end
    local ok, body = pcall(vim.json.encode, payload)
    if not ok then
        vim.schedule(function()
            callback('cannot encode model request: ' .. tostring(body))
        end)
        return { cancel = function() end }
    end
    return require('ai.rose.http').request({
        url = config.base_url:gsub('/+$', '') .. '/api/chat',
        body = body,
        timeout = config.timeout,
        allow_remote = config.allow_remote,
        transport = config.transport,
    }, function(err, data)
        if err then
            callback(err)
            return
        end
        local decoded, response = pcall(vim.json.decode, data)
        if not decoded or type(response) ~= 'table' then
            callback('invalid rose JSON response')
            return
        end
        if response.error then
            callback('rose: ' .. tostring(response.error))
            return
        end
        local message = response.message
        if type(message) ~= 'table' or (type(message.content) ~= 'string' and type(message.tool_calls) ~= 'table') then
            callback('rose response is missing an assistant message')
            return
        end
        message.role = 'assistant'
        callback(nil, message)
    end)
end

return M
