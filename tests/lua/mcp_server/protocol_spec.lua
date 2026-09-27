-- Validation spec: MCP server protocol engine (dispatch, handshake, errors).
-- Run: lua tests/lua/mcp_server/protocol_spec.lua
--  or: nvim --headless -l tests/lua/mcp_server/protocol_spec.lua
local here = debug.getinfo(1, 'S').source:sub(2)
local dir = here:match('^(.*)/[^/]*$')
local stub = dofile(dir .. '/common.lua')

local passed = 0
local function check(value, message)
    assert(value, message)
    passed = passed + 1
end

local protocol = require('ai.mcp.server.protocol')

local seen_meta = nil
local fake_tools = {
    list = function()
        return { { name = 'fake', description = 'd', inputSchema = { type = 'object' } } }
    end,
    call = function(name, args, meta)
        seen_meta = meta
        if name == 'explode' then
            return { content = { { type = 'text', text = 'kaboom' } }, isError = true }
        end
        return nil, { code = -32602, message = 'unknown tool: ' .. name }
    end,
}

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

local function notify(method, params)
    return stub.json.encode({ jsonrpc = '2.0', method = method, params = params or {} })
end

local function last(written)
    check(#written > 0, 'expected a response')
    return stub.json.decode(written[#written])
end

local function init_params(version)
    return {
        protocolVersion = version,
        capabilities = {},
        clientInfo = { name = 'spec', version = '0' },
    }
end

-- Version negotiation matrix.
local cases = {
    { client = '2025-11-25', expect = '2025-11-25' },
    { client = '2024-11-05', expect = '2024-11-05' },
    { client = '1999-01-01', expect = '2025-11-25' },
    { client = '2030-99-99', expect = '2025-11-25' },
}
for _, case in ipairs(cases) do
    local server, written = new_server(fake_tools)
    server:handle_line(rpc(1, 'initialize', init_params(case.client)))
    local res = last(written)
    check(res.result.protocolVersion == case.expect, 'negotiate ' .. case.client)
    check(res.result.serverInfo.name == 'diver-mcp-server', 'serverInfo.name present')
    check(res.result.serverInfo.version == '0.1.0', 'serverInfo.version present')
    check(res.result.capabilities.tools ~= nil, 'capabilities.tools present')
    check(res.id == 1, 'response echoes numeric id')
end

-- Missing protocolVersion is a shape error, not a negotiation.
do
    local server, written = new_server(fake_tools)
    server:handle_line(rpc(1, 'initialize', { capabilities = {} }))
    local res = last(written)
    check(res.error.code == -32602, 'missing protocolVersion -> -32602')
end

-- Non-string protocolVersion is a shape error.
do
    local server, written = new_server(fake_tools)
    server:handle_line(rpc(1, 'initialize', { protocolVersion = 20251125 }))
    local res = last(written)
    check(res.error.code == -32602, 'numeric protocolVersion -> -32602')
end

-- ping works before initialization; everything else is gated.
do
    local server, written = new_server(fake_tools)
    server:handle_line(rpc(1, 'ping'))
    local res = last(written)
    check(res.result ~= nil and next(res.result) == nil, 'ping -> {} before init')
    server:handle_line(rpc(2, 'tools/list', {}))
    res = last(written)
    check(res.error.code == -32600, 'tools/list before initialized -> -32600')
    check(server:is_initialized() == false, 'not initialized yet')
    server:handle_line(notify('notifications/initialized'))
    check(#written == 2, 'notification produces no response')
    check(server:is_initialized() == true, 'initialized after notification')
    server:handle_line(rpc(3, 'tools/list', {}))
    res = last(written)
    check(res.result.tools[1].name == 'fake', 'tools/list works after initialized')
end

-- Unknown method -> -32601.
do
    local server, written = new_server(fake_tools)
    server:handle_line(rpc(1, 'initialize', init_params('2025-11-25')))
    server:handle_line(notify('notifications/initialized'))
    server:handle_line(rpc(2, 'frobnicate'))
    local res = last(written)
    check(res.error.code == -32601, 'unknown method -> -32601')
    check(res.id == 2, 'error echoes id')
end

-- tools/call: unknown tool is a protocol error; execution failure is isError.
do
    local server, written = new_server(fake_tools)
    server:handle_line(rpc(1, 'initialize', init_params('2024-11-05')))
    server:handle_line(notify('notifications/initialized'))
    server:handle_line(rpc(2, 'tools/call', { name = 'nope', arguments = {} }))
    local res = last(written)
    check(res.error.code == -32602, 'unknown tool -> -32602 protocol error')
    check(res.result == nil, 'no result on protocol error')
    server:handle_line(rpc(3, 'tools/call', { name = 'explode', arguments = {} }))
    res = last(written)
    check(res.error == nil, 'execution failure is not a protocol error')
    check(res.result.isError == true, 'execution failure -> isError=true')
    check(res.result.content[1].text == 'kaboom', 'isError content preserved')
end

-- _meta is forwarded to the tool provider.
do
    local server, written = new_server(fake_tools)
    server:handle_line(rpc(1, 'initialize', init_params('2025-11-25')))
    server:handle_line(notify('notifications/initialized'))
    local params = { name = 'explode', arguments = {}, _meta = { grant = 'g' } }
    server:handle_line(rpc(2, 'tools/call', params))
    last(written)
    check(type(seen_meta) == 'table' and seen_meta.grant == 'g', '_meta forwarded to tools.call')
end

-- String ids round-trip.
do
    local server, written = new_server(fake_tools)
    server:handle_line(rpc('abc', 'ping'))
    local res = last(written)
    check(res.id == 'abc', 'string id echoed')
end

-- Empty line and blank input are ignored silently.
do
    local server, written = new_server(fake_tools)
    server:handle_line('')
    server:handle_line('   ')
    check(#written == 0, 'blank lines produce no response')
end

print('ok protocol_spec: ' .. passed .. ' checks')
