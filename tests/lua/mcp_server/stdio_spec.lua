-- Validation spec: stdio transport + full-stack dogfood.
-- Run: lua tests/lua/mcp_server/stdio_spec.lua
local here = debug.getinfo(1, 'S').source:sub(2)
local dir = here:match('^(.*)/[^/]*$')
local stub = dofile(dir .. '/common.lua')

local passed = 0
local function check(value, message)
    assert(value, message)
    passed = passed + 1
end

local protocol = require('ai.mcp.server.protocol')
local stdio = require('ai.mcp.server.stdio')
local policy = require('ai.mcp.server.policy')
local tools = require('ai.mcp.server.tools')

-- Injectable fake transport: captures stdout/stderr, records exit.
local function fake_deps()
    local deps = { written = {}, errors = {}, exited = nil }
    deps.open_stdin = function(on_data, on_eof)
        deps.on_data = on_data
        deps.on_eof = on_eof
        return { closed = false, close = function(self)
            self.closed = true
        end }
    end
    deps.write_stdout = function(line)
        deps.written[#deps.written + 1] = line
    end
    deps.log_stderr = function(message)
        deps.errors[#deps.errors + 1] = message
    end
    deps.exit = function(code)
        deps.exited = code
    end
    return deps
end

local function echo_server(deps)
    return protocol.new({
        json = stub.json,
        write = function(line)
            deps.write_stdout(line)
        end,
        on_log = function(level, message)
            deps.log_stderr(level .. ': ' .. message)
        end,
    })
end

local function rpc(id, method, params)
    local msg = { jsonrpc = '2.0', id = id, method = method }
    if params ~= nil then
        msg.params = params
    end
    return stub.json.encode(msg)
end

-- Line buffering: a message split across chunks is reassembled.
do
    local deps = fake_deps()
    local server = echo_server(deps)
    local handle = stdio.start(server, deps)
    local line = rpc(1, 'ping') .. '\n'
    deps.on_data(line:sub(1, 10))
    check(#deps.written == 0, 'partial line produces no response yet')
    deps.on_data(line:sub(11))
    check(#deps.written == 1, 'completed line answered')
    check(stub.json.decode(deps.written[1]).id == 1, 'response id matches')
    handle.stop()
end

-- Multiple messages in one chunk each get a response, in order.
do
    local deps = fake_deps()
    local server = echo_server(deps)
    stdio.start(server, deps)
    deps.on_data(rpc(1, 'ping') .. '\n' .. rpc(2, 'ping') .. '\n' .. rpc(3, 'ping') .. '\n')
    check(#deps.written == 3, 'three lines -> three responses')
    for i = 1, 3 do
        check(stub.json.decode(deps.written[i]).id == i, 'response order preserved')
    end
end

-- CRLF line endings are tolerated.
do
    local deps = fake_deps()
    local server = echo_server(deps)
    stdio.start(server, deps)
    deps.on_data(rpc(1, 'ping') .. '\r\n')
    check(#deps.written == 1, 'CRLF line answered')
end

-- Stdout discipline: every stdout line is a JSON-RPC message; logs use stderr.
do
    local deps = fake_deps()
    local server = echo_server(deps)
    stdio.start(server, deps)
    deps.on_data(rpc(1, 'ping') .. '\n')
    deps.on_data('{broken\n')
    deps.on_data(rpc(2, 'nope') .. '\n')
    for _, line in ipairs(deps.written) do
        local ok, msg = pcall(stub.json.decode, line)
        check(ok and type(msg) == 'table' and msg.jsonrpc == '2.0', 'stdout line is JSON-RPC')
    end
    check(#deps.errors >= 1, 'broken line logged to stderr, not stdout')
end

-- EOF exits the server; stop() is idempotent.
do
    local deps = fake_deps()
    local server = echo_server(deps)
    local handle = stdio.start(server, deps)
    deps.on_eof()
    check(deps.exited == 0, 'EOF exits 0')
    deps.on_eof()
    check(deps.exited == 0, 'double EOF still 0')
    handle.stop()
    handle.stop()
    check(true, 'stop() is idempotent')
end

-- Full-stack dogfood: initialize -> initialized -> tools/list ->
-- tools/call read_file, then a denied write and a granted write.
do
    local tmp = stub.fresh_dir('stdio_dogfood')
    stub.write_file(tmp .. '/hello.txt', 'dogfood ok\n')
    policy.setup({ roots = { tmp }, grant_token = 'tok' })
    tools.setup()

    local deps = fake_deps()
    local server = protocol.new({
        json = stub.json,
        write = function(line)
            deps.write_stdout(line)
        end,
        tools = tools,
        on_log = function(level, message)
            deps.log_stderr(level .. ': ' .. message)
        end,
    })
    stdio.start(server, deps)

    local function roundtrip(id, method, params)
        deps.on_data(rpc(id, method, params) .. '\n')
        check(#deps.written > 0, 'response for ' .. method)
        return stub.json.decode(deps.written[#deps.written])
    end

    local init = roundtrip(1, 'initialize', {
        protocolVersion = '2025-11-25',
        capabilities = {},
        clientInfo = { name = 'dogfood', version = '0' },
    })
    check(init.result.protocolVersion == '2025-11-25', 'dogfood: negotiated 2025-11-25')
    local note = { jsonrpc = '2.0', method = 'notifications/initialized' }
    local initialized_note = stub.json.encode(note)
    deps.on_data(initialized_note .. '\n')

    local list = roundtrip(2, 'tools/list', {})
    check(#list.result.tools == 7, 'dogfood: 7 tools listed')

    local read = roundtrip(3, 'tools/call', {
        name = 'read_file',
        arguments = { path = tmp .. '/hello.txt' },
    })
    check(read.error == nil, 'dogfood: read_file no protocol error')
    check(read.result.content[1].text == 'dogfood ok', 'dogfood: file content round-trips')

    local denied = roundtrip(4, 'tools/call', {
        name = 'write_file',
        arguments = { path = tmp .. '/new.txt', content = 'x', mode = 'create' },
    })
    check(denied.error ~= nil and denied.error.code == -32000, 'dogfood: ungranted write denied')

    local granted = roundtrip(5, 'tools/call', {
        name = 'write_file',
        arguments = { path = tmp .. '/new.txt', content = 'granted\n', mode = 'create' },
        _meta = { grant = 'tok' },
    })
    check(granted.error == nil and granted.result.isError ~= true, 'dogfood: granted write allowed')
    local back = roundtrip(6, 'tools/call', {
        name = 'read_file',
        arguments = { path = tmp .. '/new.txt' },
    })
    check(back.result.content[1].text == 'granted', 'dogfood: written file reads back')

    -- Stdout discipline across the whole session.
    for _, line in ipairs(deps.written) do
        local ok, msg = pcall(stub.json.decode, line)
        check(ok and msg.jsonrpc == '2.0', 'dogfood: stdout stays pure JSON-RPC')
    end

    os.execute('rm -rf ' .. stub.shquote(tmp))
end

print('ok stdio_spec: ' .. passed .. ' checks')
