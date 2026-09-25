-- /qompassai/Diver/lua/acp/rpc.lua
-- Qompass AI ACP JSON-RPC Transport (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- ACP is JSON-RPC 2.0 framed as one JSON object per newline-delimited
-- line over the agent process's stdio -- no Content-Length headers, unlike
-- LSP. This module owns exactly that framing and dispatch, nothing else.

local M = {}

local MAX_LINE_BYTES = 8 * 1024 * 1024
local MAX_PENDING_REQUESTS = 256

---@class AcpClient
---@field proc vim.SystemObj?
---@field pending table<integer, fun(err: table?, result: any)>
---@field handlers table<string, fun(params: table): any, table?>
---@field buffer string
---@field next_id integer
---@field on_exit? fun(code: integer)

---@param cmd string[]
---@param opts { cwd?: string, env?: table, on_exit?: fun(code: integer) }
---@return AcpClient?, string?
function M.start(cmd, opts)
    assert(type(cmd) == 'table' and #cmd > 0, 'cmd must be a nonempty argv list')
    if vim.fn.executable(cmd[1]) ~= 1 then
        return nil, 'Executable not found: ' .. cmd[1]
    end

    ---@type AcpClient
    local client = {
        proc = nil,
        pending = {},
        handlers = {},
        buffer = '',
        next_id = 1,
        on_exit = opts.on_exit,
    }

    local function handle_line(line)
        if line == '' then
            return
        end
        assert(#line <= MAX_LINE_BYTES, 'ACP message exceeds line size bound')
        local ok, message = pcall(vim.json.decode, line)
        if not ok or type(message) ~= 'table' then
            return
        end

        if message.id ~= nil and (message.result ~= nil or message.error ~= nil) then
            local callback = client.pending[message.id]
            if callback then
                client.pending[message.id] = nil
                callback(message.error, message.result)
            end
            return
        end

        if message.method ~= nil then
            local handler = client.handlers[message.method]
            if handler then
                local result, err = handler(message.params or {})
                if message.id ~= nil then
                    M.reply(client, message.id, result, err)
                end
            elseif message.id ~= nil then
                M.reply(client, message.id, nil, { code = -32601, message = 'Method not found' })
            end
        end
    end

    local function on_stdout(err, data)
        if err or data == nil then
            return
        end
        client.buffer = client.buffer .. data
        while true do
            local newline = client.buffer:find('\n', 1, true)
            if not newline then
                break
            end
            local line = client.buffer:sub(1, newline - 1)
            client.buffer = client.buffer:sub(newline + 1)
            handle_line(line)
        end
    end

    local spawned, process = pcall(vim.system, cmd, {
        cwd = opts.cwd,
        env = opts.env,
        stdin = true,
        stdout = on_stdout,
        stderr = function() end,
    }, function(result)
        client.proc = nil
        if client.on_exit then
            vim.schedule(function()
                client.on_exit(result.code)
            end)
        end
    end)

    if not spawned then
        return nil, tostring(process)
    end

    client.proc = process
    return client, nil
end

---@param client AcpClient
---@param method string
---@param params table
---@param callback? fun(err: table?, result: any)
---@return integer? id
function M.request(client, method, params, callback)
    assert(client.proc, 'ACP client is not running')
    assert(vim.tbl_count(client.pending) < MAX_PENDING_REQUESTS, 'Pending ACP request bound exceeded')

    local id = client.next_id
    client.next_id = client.next_id + 1

    if callback then
        client.pending[id] = callback
    end

    local payload = vim.json.encode({
        jsonrpc = '2.0',
        id = id,
        method = method,
        params = params,
    })
    client.proc:write(payload .. '\n')
    return id
end

---@param client AcpClient
---@param method string
---@param params table
function M.notify(client, method, params)
    assert(client.proc, 'ACP client is not running')
    local payload = vim.json.encode({
        jsonrpc = '2.0',
        method = method,
        params = params,
    })
    client.proc:write(payload .. '\n')
end

---@param client AcpClient
---@param id integer
---@param result any
---@param err table?
function M.reply(client, id, result, err)
    assert(client.proc, 'ACP client is not running')
    local payload = vim.json.encode({
        jsonrpc = '2.0',
        id = id,
        result = err == nil and (result or vim.NIL) or nil,
        error = err,
    })
    client.proc:write(payload .. '\n')
end

---@param client AcpClient
---@param method string
---@param handler fun(params: table): any, table?
function M.on(client, method, handler)
    client.handlers[method] = handler
end

---@param client AcpClient
function M.stop(client)
    if client.proc then
        pcall(client.proc.kill, client.proc, 15)
    end
end

return M
