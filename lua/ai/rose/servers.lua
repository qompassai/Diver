-- /qompassai/Diver/lua/ai/rose/servers.lua
-- Named MCP server registry with explicit trust gates (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Third-party executable trust is distinct from workspace edit trust: a
-- server is callable only when its config carries trusted=true AND
-- read_only=true, and only for tools named in its allow_tools list.

local M = { clients = {} }

---@param config table resolved Rose config
function M.setup(config)
    assert(type(config) == 'table', 'servers.setup: config must be a table')
    M.stop()
    M.config = config
end

---@param server_name string
---@param tool_name string
---@param args table?
---@param callback fun(err: string?, result: table?)
---@return table token
function M.call(server_name, tool_name, args, callback)
    assert(type(server_name) == 'string', 'servers.call: server_name must be a string')
    assert(type(tool_name) == 'string', 'servers.call: tool_name must be a string')
    assert(type(callback) == 'function', 'servers.call: callback must be a function')
    local config = M.config.mcp.servers[server_name]
    local cancelled, request = false, nil
    local token = {
        cancel = function()
            cancelled = true
            if request then
                request.cancel()
            end
        end,
    }
    local function reject(message)
        vim.schedule(function()
            callback(message)
        end)
        return token
    end
    if type(config) ~= 'table' or config.trusted ~= true or config.read_only ~= true then
        return reject('MCP server requires explicit trusted=true and read_only=true configuration')
    end
    local allowed = false
    for _, name in ipairs(config.allow_tools or {}) do
        if name == tool_name then
            allowed = true
        end
    end
    if not allowed then
        return reject('MCP tool is not in server allow_tools')
    end
    local function invoke(err, client)
        if cancelled then
            callback('cancelled')
            return
        end
        if err or not client then
            callback(err or 'MCP connected without a client')
            return
        end
        request = client:call_tool(tool_name, args, function(call_err, result)
            if not call_err and type(result) == 'table' and result.isError then
                call_err = 'MCP tool returned isError=true'
            end
            callback(call_err, result)
        end, config.timeout)
    end
    local client = M.clients[server_name]
    if client and client.ready and not client.closed then
        invoke(nil, client)
    elseif client and not client.closed then
        return reject('MCP server is still initializing; retry after initialization')
    else
        M.clients[server_name] = require('ai.rose.mcp').start({
            cmd = config.cmd,
            cwd = M.config.workspace,
            timeout = config.timeout,
            env = config.env,
        }, invoke)
    end
    return token
end

-- Close every named server client.
--- Stop every configured MCP server client.
function M.stop()
    for _, client in pairs(M.clients) do
        client:close('MCP servers stopped')
    end
    M.clients = {}
end

return M
