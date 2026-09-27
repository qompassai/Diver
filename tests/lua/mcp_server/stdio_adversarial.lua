-- Adversarial spec: stdio transport abuse.
-- Run: lua tests/lua/mcp_server/stdio_adversarial.lua
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

local function fake_deps()
    local deps = { written = {}, errors = {}, exited = nil }
    deps.open_stdin = function(on_data, on_eof)
        deps.on_data = on_data
        deps.on_eof = on_eof
        return { close = function() end }
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

local function new_server(deps)
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

local function ping(id)
    return stub.json.encode({ jsonrpc = '2.0', id = id, method = 'ping' }) .. '\n'
end

-- Oversized line: dropped, logged to stderr, server keeps working.
do
    local deps = fake_deps()
    stdio.start(new_server(deps), deps)
    local before = #deps.written
    deps.on_data(string.rep('z', 8 * 1024 * 1024 + 100) .. '\n')
    check(#deps.written == before, 'oversized line: no response')
    check(#deps.errors >= 1, 'oversized line: stderr logged')
    deps.on_data(ping(1))
    check(#deps.written == before + 1, 'server works after oversized line')
end

-- Oversized partial line (no newline, ever): buffer reset, no growth.
do
    local deps = fake_deps()
    stdio.start(new_server(deps), deps)
    deps.on_data(string.rep('z', 8 * 1024 * 1024 + 1))
    check(#deps.written == 0, 'partial oversized: no response')
    check(#deps.errors >= 1, 'partial oversized: stderr logged')
    deps.on_data(ping(1))
    check(#deps.written == 1, 'buffer was reset; next line works')
end

-- Partial line held across many chunks until the newline arrives.
do
    local deps = fake_deps()
    stdio.start(new_server(deps), deps)
    local line = ping(7)
    for i = 1, #line - 1 do
        deps.on_data(line:sub(i, i))
    end
    check(#deps.written == 0, 'no response before newline')
    deps.on_data('\n')
    check(#deps.written == 1, 'response once newline arrives')
    check(stub.json.decode(deps.written[1]).id == 7, 'byte-fed line answered')
end

-- Notification flood: zero stdout bytes, stderr stays quiet-ish, no crash.
do
    local deps = fake_deps()
    stdio.start(new_server(deps), deps)
    local line = stub.json.encode({ jsonrpc = '2.0', method = 'notifications/initialized' }) .. '\n'
    local chunk = string.rep(line, 500)
    for _ = 1, 4 do
        deps.on_data(chunk)
    end
    check(#deps.written == 0, 'notification flood: zero stdout bytes')
    deps.on_data(ping(1))
    check(#deps.written == 1, 'server alive after flood')
end

-- Rapid mixed stream: valid, garbage, oversized, valid -- all handled.
do
    local deps = fake_deps()
    stdio.start(new_server(deps), deps)
    local before_err = #deps.errors
    deps.on_data(ping(1) .. '{garbage\n' .. ping(2) .. '\n\n' .. ping(3))
    check(#deps.written == 3, 'three valid pings answered out of mixed stream')
    check(#deps.errors > before_err, 'garbage logged to stderr')
    local ids = {}
    for _, line in ipairs(deps.written) do
        ids[#ids + 1] = stub.json.decode(line).id
    end
    check(ids[1] == 1 and ids[2] == 2 and ids[3] == 3, 'mixed stream order preserved')
end

-- A throwing write_stdout cannot crash the server.
do
    local deps = fake_deps()
    local writes = 0
    deps.write_stdout = function(_)
        writes = writes + 1
        error('stdout is broken')
    end
    stdio.start(new_server(deps), deps)
    deps.on_data(ping(1))
    check(writes == 1, 'write attempted exactly once')
    check(#deps.errors >= 1, 'write failure logged to stderr')
    deps.on_data(ping(2))
    check(writes == 2, 'server survives transport write failures')
end

-- open_stdin failing: stderr logged, exit(1), handle still stoppable.
do
    local deps = fake_deps()
    deps.open_stdin = function(_, _)
        error('no stdin here')
    end
    local handle = stdio.start(new_server(deps), deps)
    check(deps.exited == 1, 'stdin failure exits 1')
    check(#deps.errors >= 1, 'stdin failure logged')
    handle.stop()
    check(true, 'handle from failed start is stoppable')
end

-- Empty and nil data chunks are ignored.
do
    local deps = fake_deps()
    stdio.start(new_server(deps), deps)
    deps.on_data('')
    deps.on_data(nil)
    check(#deps.written == 0 and #deps.errors == 0, 'empty chunks ignored silently')
    deps.on_data(ping(1))
    check(#deps.written == 1, 'server fine after empty chunks')
end

print('ok stdio_adversarial: ' .. passed .. ' checks')
