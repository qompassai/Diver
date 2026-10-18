-- /qompassai/Diver/lua/ai/webmcp/mcp_adapter.lua
-- MCP (Model Context Protocol) surface for the WebMCP bridge.
--
-- Plain words: the bridge speaks its own tiny frame protocol
-- ({ "id": 1, "method": "bridge.ping", "params": {} }). This adapter
-- gives the SAME endpoints a second, standard dialect -- MCP
-- JSON-RPC (initialize, tools/list, tools/call), served by
-- ai.mcp.server.protocol over the same WebSocket -- so a stock MCP
-- client, or the WebMCP page shim passing CallToolResult through
-- untouched the way Cloudflare's bridge does, can drive the bridge
-- without learning the native frames.
--
-- Contracts:
--   * The adapter owns no endpoints and no auth state. The bridge
--     injects its capabilities as deps: tool_defs() (the same
--     projection bridge.tools serves), dispatch(name, params,
--     respond) (the bridge's own endpoint dispatcher -- handlers
--     keep owning their gating and audit), is_authed() for this
--     client, and write(line) back to the socket.
--   * Authorization mirrors the native dispatcher exactly: public
--     endpoints are callable before auth; everything else needs an
--     authed client while the bridge runs with require_token.
--     tools/list shows only what this client may call.
--   * Endpoint handlers answer through respond(ok, payload), which
--     may fire after dispatch returns (job-backed work). MCP's
--     tools/call is return-shaped, so an endpoint that has not
--     responded when dispatch returns fails THIS call with a clear
--     error; the native protocol remains the way to drive it.
--     Nothing is queued and no reply is ever fabricated.
--   * Result shape is decided here, once: a payload that already
--     carries a `content` array passes through untouched; any
--     other table becomes one JSON text block plus
--     structuredContent; a string becomes one text block. Tool
--     failures are results with isError = true (the MCP
--     convention), not protocol errors.
---@module 'ai.webmcp.mcp_adapter'

local M = {}

---JSON-RPC error code for calls refused by bridge authorization.
local ERR_UNAUTHORIZED = -32001
---JSON-RPC error code for endpoints that answer asynchronously.
local ERR_ASYNC_ENDPOINT = -32002
---JSON-RPC error code for unknown tools (MCP uses InvalidParams).
local ERR_UNKNOWN_TOOL = -32602
---Max characters kept from a native error payload.
local ERROR_TEXT_MAX = 512
---Max characters of a tool name echoed into an error message.
local NAME_ECHO_MAX = 64

---@class McpAdapterDeps
---@field dispatch fun(name: string, params: table, respond: fun(ok: boolean, payload: any)): boolean
---@field is_authed fun(): boolean
---@field public_methods table<string, boolean>
---@field require_token fun(): boolean
---@field tool_defs fun(): table[]
---@field write fun(line: string)

---Translate one native respond(ok, payload) into a CallToolResult.
---@param ok boolean
---@param payload any
---@return table
local function to_call_result(ok, payload)
    if not ok then
        return {
            content = {
                { text = tostring(payload):sub(1, ERROR_TEXT_MAX), type = 'text' },
            },
            isError = true,
        }
    end
    if payload == nil then
        payload = {}
    end
    if type(payload) == 'table' and type(payload.content) == 'table' then
        return payload
    end
    if type(payload) == 'string' then
        return {
            content = {
                { text = payload, type = 'text' },
            },
            isError = false,
        }
    end
    local encoded = vim.json.encode(payload)
    assert(type(encoded) == 'string')
    local result = {
        content = {
            { text = encoded, type = 'text' },
        },
        isError = false,
    }
    if type(payload) == 'table' then
        result.structuredContent = payload
    end
    return result
end

---Create one MCP session bound to a single bridge client.
---@param deps McpAdapterDeps
---@return table session A table with handle_line(raw)
function M.new_session(deps)
    assert(type(deps) == 'table', 'deps must be a table')
    assert(type(deps.dispatch) == 'function', 'deps.dispatch must be a function')
    assert(type(deps.is_authed) == 'function', 'deps.is_authed must be a function')
    assert(type(deps.public_methods) == 'table', 'deps.public_methods must be a table')
    assert(type(deps.require_token) == 'function', 'deps.require_token must be a function')
    assert(type(deps.tool_defs) == 'function', 'deps.tool_defs must be a function')
    assert(type(deps.write) == 'function', 'deps.write must be a function')

    ---May this session's client call `name` right now? Mirrors the
    ---native dispatcher's rule in bridge.on_message_main.
    ---@param name string
    ---@return boolean
    local function may_call(name)
        if not deps.require_token() then
            return true
        end
        if deps.public_methods[name] then
            return true
        end
        return deps.is_authed()
    end

    local tools = {}

    ---@return table[] MCP tool descriptors this client may call
    function tools.list()
        local out = {}
        for _, def in ipairs(deps.tool_defs()) do
            if may_call(def.name) then
                out[#out + 1] = def
            end
        end
        return out
    end

    ---@param name string
    ---@param args table
    ---@return table? result
    ---@return table? error
    function tools.call(name, args)
        if not may_call(name) then
            return nil,
                {
                    code = ERR_UNAUTHORIZED,
                    message = 'unauthorized: authenticate via bridge.auth or initialize _meta.token first',
                }
        end
        local responded = false
        local cap_ok = false
        local cap_payload = nil
        local known = deps.dispatch(name, args, function(ok, payload)
            responded = true
            cap_ok = ok
            cap_payload = payload
        end)
        if not known then
            return nil,
                {
                    code = ERR_UNKNOWN_TOOL,
                    message = 'unknown tool: ' .. name:sub(1, NAME_ECHO_MAX),
                }
        end
        if not responded then
            return nil,
                {
                    code = ERR_ASYNC_ENDPOINT,
                    message = 'endpoint answers asynchronously; use the native bridge protocol for '
                        .. name:sub(1, NAME_ECHO_MAX),
                }
        end
        return to_call_result(cap_ok, cap_payload)
    end

    local server = require('ai.mcp.server.protocol').new({
        on_log = function() end,
        tools = tools,
        write = deps.write,
    })

    local session = {}

    ---Feed one raw JSON-RPC frame (no trailing newline needed).
    ---@param raw string
    function session.handle_line(raw)
        server:handle_line(raw)
    end

    return session
end

return M
