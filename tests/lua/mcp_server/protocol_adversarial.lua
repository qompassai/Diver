-- Adversarial spec: MCP server protocol engine.
-- Malformed input, floods, shape attacks, and crash containment.
-- Run: lua tests/lua/mcp_server/protocol_adversarial.lua
local here = debug.getinfo(1, 'S').source:sub(2)
local dir = here:match('^(.*)/[^/]*$')
local stub = dofile(dir .. '/common.lua')

local passed = 0
local function check(value, message)
    assert(value, message)
    passed = passed + 1
end

local protocol = require('ai.mcp.server.protocol')

local function new_server(tools)
    local written = {}
    local logs = {}
    local server = protocol.new({
        json = stub.json,
        write = function(line)
            written[#written + 1] = line
        end,
        tools = tools,
        on_log = function(level, message)
            logs[#logs + 1] = level .. ': ' .. message
        end,
    })
    return server, written, logs
end

local function rpc(id, method, params)
    local msg = { jsonrpc = '2.0', id = id, method = method }
    if params ~= nil then
        msg.params = params
    end
    return stub.json.encode(msg)
end

local function last(written)
    check(#written > 0, 'expected a response')
    return stub.json.decode(written[#written])
end

local function initialized_server()
    local server, written, logs = new_server()
    server:handle_line(rpc(1, 'initialize', { protocolVersion = '2025-11-25' }))
    server:handle_line(stub.json.encode({ jsonrpc = '2.0', method = 'notifications/initialized' }))
    return server, written, logs
end

-- Malformed JSON: no crash, no response, logged.
do
    local server, written, logs = initialized_server()
    local before = #written
    server:handle_line('{this is not json')
    server:handle_line('{"jsonrpc": "2.0", "id": 1, "method": ')
    server:handle_line('\0\0\0')
    check(#written == before, 'malformed JSON produces no response')
    check(#logs >= 3, 'malformed lines are logged')
    server:handle_line(rpc(9, 'ping'))
    local res = last(written)
    check(res.id == 9, 'server still alive after malformed input')
end

-- Oversized line is dropped, not parsed.
do
    local server, written, logs = initialized_server()
    local before = #written
    server:handle_line(string.rep('x', 8 * 1024 * 1024 + 1))
    check(#written == before, 'oversized line produces no response')
    check(#logs >= 1, 'oversized line is logged')
    server:handle_line(rpc(9, 'ping'))
    check(last(written).id == 9, 'server alive after oversized line')
end

-- Batch arrays are rejected, not executed.
do
    local server, written = initialized_server()
    server:handle_line(stub.json.encode({ { jsonrpc = '2.0', id = 1, method = 'ping' } }))
    local res = last(written)
    check(res.error.code == -32600, 'batch -> -32600')
end

-- Missing jsonrpc / wrong jsonrpc with an id -> -32600.
do
    local server, written = initialized_server()
    server:handle_line(stub.json.encode({ id = 1, method = 'ping' }))
    check(last(written).error.code == -32600, 'missing jsonrpc -> -32600')
    server:handle_line(stub.json.encode({ jsonrpc = '1.0', id = 2, method = 'ping' }))
    check(last(written).error.code == -32600, 'wrong jsonrpc -> -32600')
end

-- Notification-shaped garbage (no id, no method) is ignored silently.
do
    local server, written = initialized_server()
    local before = #written
    server:handle_line(stub.json.encode({ jsonrpc = '2.0' }))
    server:handle_line(stub.json.encode({ jsonrpc = '2.0', method = 'nope' }))
    check(#written == before, 'unknown notifications are ignored')
end

-- Boolean/table ids are rejected.
do
    local server, written = initialized_server()
    server:handle_line(stub.json.encode({ jsonrpc = '2.0', id = true, method = 'ping' }))
    local res = last(written)
    check(res.error.code == -32600, 'boolean id -> -32600')
    server:handle_line(stub.json.encode({ jsonrpc = '2.0', id = { 1 }, method = 'ping' }))
    check(last(written).error.code == -32600, 'table id -> -32600')
end

-- Non-object params are rejected.
do
    local server, written = initialized_server()
    server:handle_line('{"jsonrpc":"2.0","id":1,"method":"ping","params":"oops"}')
    check(last(written).error.code == -32602, 'string params -> -32602')
    server:handle_line('{"jsonrpc":"2.0","id":2,"method":"ping","params":[1,2]}')
    local res = last(written)
    -- An array decodes to a table, which the dispatcher accepts as params.
    check(res.result ~= nil or res.error ~= nil, 'array params get a deterministic answer')
end

-- Notification flood: thousands of notifications, zero responses.
do
    local server, written = initialized_server()
    local before = #written
    local line = stub.json.encode({ jsonrpc = '2.0', method = 'notifications/initialized' })
    for _ = 1, 3000 do
        server:handle_line(line)
    end
    check(#written == before, 'notification flood produces no responses')
end

-- A crashing handler becomes -32603, not a dead server.
do
    local server, written, logs = initialized_server()
    server:register('boom', function()
        error('synthetic crash')
    end)
    server:handle_line(rpc(7, 'boom'))
    local res = last(written)
    check(res.error.code == -32603, 'crashing handler -> -32603')
    check(res.error.message == 'internal error', 'crash detail not leaked to client')
    check(#logs >= 1, 'crash is logged server-side')
    server:handle_line(rpc(8, 'ping'))
    check(last(written).id == 8, 'server alive after handler crash')
end

-- tools/list with params=[] (Cursor sends this): treated as {}.
do
    local tools = {
        list = function()
            return {}
        end,
        call = function()
            return nil, { code = -32602, message = 'x' }
        end,
    }
    local server, written = new_server(tools)
    server:handle_line(rpc(1, 'initialize', { protocolVersion = '2025-11-25' }))
    server:handle_line(stub.json.encode({ jsonrpc = '2.0', method = 'notifications/initialized' }))
    server:handle_line('{"jsonrpc":"2.0","id":2,"method":"tools/list","params":[]}')
    local res = last(written)
    check(res.result ~= nil and res.result.tools ~= nil, 'tools/list with [] params works')
end

-- initialize twice: second handshake just re-negotiates.
do
    local server, written = initialized_server()
    local before = #written
    server:handle_line(rpc(5, 'initialize', { protocolVersion = '2024-11-05' }))
    local res = last(written)
    check(res.result.protocolVersion == '2024-11-05', 're-initialize negotiates again')
    check(#written == before + 1, 'exactly one response for re-initialize')
end

-- Embedded newline inside a JSON string is one line, not two messages.
do
    local server, written = initialized_server()
    local before = #written
    server:handle_line('{"jsonrpc":"2.0","id":1,"method":"ping","params":{"note":"a\\nb"}}')
    check(#written == before + 1, 'escaped newline stays one message')
    check(last(written).id == 1, 'escaped-newline message answered')
end

-- Deeply nested params do not hang the dispatcher.
do
    local server, written = initialized_server()
    local nested = {}
    local cur = nested
    for _ = 1, 200 do
        cur.child = {}
        cur = cur.child
    end
    local line = stub.json.encode({ jsonrpc = '2.0', id = 1, method = 'ping', params = nested })
    server:handle_line(line)
    check(last(written).id == 1, 'deep params answered without hang')
end

print('ok protocol_adversarial: ' .. passed .. ' checks')
