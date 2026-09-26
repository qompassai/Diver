-- /qompassai/Diver/lua/ai/mcp/webmcp.lua
-- WebMCP tool discovery: enumerate tools from a WebMCP bridge.
-- Copyright (C) 2026 Qompass AI, All rights reserved.
-- ----------------------------------------
--
-- Plain words: a WebMCP-enabled page (or another Diver bridge)
-- publishes tools. This module connects to that bridge over
-- WebSocket, asks for its tool list, and hands back normalized
-- tool definitions the agent workflow can use. It is a discovery
-- source in the same sense as ai.mcp.discovery: it finds tools,
-- it does not execute them. Execution stays behind ai.recon.gate.
---@module 'ai.mcp.webmcp'

local M = {}

local CONNECT_TIMEOUT_MS = 10000 ---@type integer
local CALL_TIMEOUT_MS = 30000 ---@type integer
local TOOL_COUNT_MAX = 256 ---@type integer

---@param url string
---@return string? hostport
local function parse_ws_url(url)
    return url:match('^ws://([^/]+)')
end

---Discover tools from a WebMCP bridge at url (ws://host:port).
---callback receives (ok, tools_or_err). Tools are normalized to
---{ name, title, description, inputSchema, annotations, source }.
---When the bridge requires tokens, pass one or discovery fails closed.
---@param url string
---@param callback fun(ok: boolean, result: table)
---@param token? string capability token for bridge.auth
function M.discover(url, callback, token)
    assert(type(url) == 'string', 'url must be a string')
    assert(type(callback) == 'function', 'callback must be a function')
    assert(token == nil or type(token) == 'string', 'token must be a string')
    if parse_ws_url(url) == nil then
        callback(false, { error = 'url must be ws://host:port' })
        return
    end
    local ok, wsclient = pcall(require, 'websocket.client')
    if not ok then
        callback(false, { error = 'websocket.client unavailable' })
        return
    end
    local seq = 0
    local pending = {} ---@type table<any, fun(ok: boolean, payload: table)>
    local settled = false
    local client = nil

    local function settle(ok2, result)
        if settled then
            return
        end
        settled = true
        if client ~= nil then
            client:try_disconnect()
        end
        vim.schedule(function()
            callback(ok2, result)
        end)
    end

    local function on_message(_, raw)
        local ok2, msg = pcall(vim.json.decode, raw)
        if not ok2 or type(msg) ~= 'table' then
            return
        end
        local cb = pending[msg.id]
        if cb ~= nil then
            pending[msg.id] = nil
            cb(msg.ok == true, msg.ok == true and msg.result or { error = tostring(msg.error) })
        end
    end

    client = wsclient.WebsocketClient.new({
        connect_addr = url,
        on_message = on_message,
        on_connect = function()
            local function call_tools()
                seq = seq + 1
                local id = seq
                pending[id] = function(ok2, result)
                    if not ok2 then
                        settle(false, { error = result.error or 'bridge.tools failed' })
                        return
                    end
                    local raw_tools = result.tools
                    if type(raw_tools) ~= 'table' then
                        settle(false, { error = 'bridge.tools returned no tools' })
                        return
                    end
                    if #raw_tools > TOOL_COUNT_MAX then
                        settle(false, { error = 'tool count exceeds bound' })
                        return
                    end
                    local tools = {}
                    for _, t in ipairs(raw_tools) do
                        if type(t) == 'table' and type(t.name) == 'string' then
                            tools[#tools + 1] = {
                                name = t.name,
                                title = t.title,
                                description = t.description,
                                inputSchema = t.inputSchema,
                                annotations = t.annotations,
                                source = url,
                            }
                        end
                    end
                    settle(true, { tools = tools })
                end
                local payload = vim.json.encode({ id = id, method = 'bridge.tools', params = {} })
                client:try_send_data(payload)
                vim.defer_fn(function()
                    if pending[id] ~= nil then
                        pending[id] = nil
                        settle(false, { error = 'bridge.tools timed out' })
                    end
                end, CALL_TIMEOUT_MS)
            end
            if token ~= nil then
                seq = seq + 1
                local aid = seq
                pending[aid] = function(aok, aresult)
                    if not aok then
                        settle(false, { error = 'bridge.auth failed: ' .. tostring(aresult.error):sub(1, 128) })
                        return
                    end
                    call_tools()
                end
                client:try_send_data(vim.json.encode({ id = aid, method = 'bridge.auth', params = { token = token } }))
            else
                call_tools()
            end
        end,
        on_error = function(err)
            settle(false, { error = 'connect failed: ' .. tostring(err):sub(1, 128) })
        end,
        on_disconnect = function()
            settle(false, { error = 'disconnected before discovery finished' })
        end,
    })
    -- try_connect is fire-and-forget: it returns nothing on success
    -- and reports failures via on_error/on_disconnect. Do not treat
    -- a nil return as failure.
    client:try_connect()
    vim.defer_fn(function()
        settle(false, { error = 'connect timed out' })
    end, CONNECT_TIMEOUT_MS)
end

return M
