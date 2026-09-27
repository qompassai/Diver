-- http.lua contract tests. The pure parts (validation, request
-- building, response parsing) run under plain Lua 5.4. Live TCP tests
-- need real Neovim (vim.uv + vim.wait) and SKIP otherwise.
-- run: ~/workspace/tools/lua-5.4.8/src/lua tests/lua/bidi/bidi_http.lua

local src = debug.getinfo(1, 'S').source:sub(2)
local dir = src:match('^(.*)/[^/]+$')
local H = dofile(dir .. '/harness.lua')

local http = require('dev.browser.http')

local function resp_200(body)
    return 'HTTP/1.1 200 OK\r\nContent-Length: '
        .. #body
        .. '\r\nContent-Type: application/json\r\n\r\n'
        .. body
end

-- ---------------------------------------------------------- validation

H.test('200 with Content-Length parses fully', false, function()
    local r, err, incomplete = http._parse_response(resp_200('{"a":1}'), false)
    H.is_nil(err)
    H.is_nil(incomplete)
    H.not_nil(r)
    H.eq(r.status, 200)
    H.eq(r.headers['content-type'], 'application/json')
    H.eq(r.body, '{"a":1}')
end)

H.test('header names are case-insensitive', false, function()
    local raw = 'HTTP/1.1 200 OK\r\nX-Custom-Thing: yes\r\nCONTENT-LENGTH: 2\r\n\r\nhi'
    local r = http._parse_response(raw, false)
    H.not_nil(r)
    H.eq(r.headers['x-custom-thing'], 'yes')
    H.eq(r.body, 'hi')
end)

H.test('no Content-Length completes at EOF', false, function()
    local raw = 'HTTP/1.1 200 OK\r\nConnection: close\r\n\r\nhello'
    local r, _, incomplete = http._parse_response(raw, true)
    H.is_nil(incomplete)
    H.not_nil(r)
    H.eq(r.body, 'hello')
end)

H.test('no Content-Length before EOF is incomplete, not an error', false, function()
    local raw = 'HTTP/1.1 200 OK\r\n\r\npartial'
    local r, err, incomplete = http._parse_response(raw, false)
    H.is_nil(r)
    H.is_nil(err)
    H.is_true(incomplete)
end)

H.test('default timeout is TIMEOUT_MS_DEFAULT', false, function()
    local norm = http._validate_opts({
        host = '127.0.0.1',
        port = 9515,
        method = 'GET',
        path = '/status',
    })
    H.not_nil(norm)
    H.eq(norm.timeout_ms, http.TIMEOUT_MS_DEFAULT)
    H.eq(norm.timeout_ms, 5000)
end)

H.test('request text is well-formed and deterministic', false, function()
    local norm = http._validate_opts({
        host = 'localhost',
        port = 4444,
        method = 'POST',
        path = '/session',
        body = '{}',
        headers = { ['Content-Type'] = 'application/json', ['X-B'] = '2', ['X-A'] = '1' },
    })
    local text = http._build_request(norm)
    H.matches(text, 'POST /session HTTP/1.1\r\n')
    H.matches(text, 'Host: localhost:4444\r\n')
    H.matches(text, 'Connection: close\r\n')
    H.matches(text, 'Content-Length: 2\r\n')
    -- custom headers sorted byte-wise: Content-Type < X-A < X-B
    local ct = text:find('Content-Type: application/json', 1, true)
    local a = text:find('X-A: 1', 1, true)
    local b = text:find('X-B: 2', 1, true)
    H.is_true(ct < a and a < b)
    H.is_true(text:sub(-2) == '{}')
end)

H.test('localhost and ::1 are accepted loopback hosts', false, function()
    for _, host in ipairs({ 'localhost', '127.0.0.1', '::1' }) do
        local norm = http._validate_opts({ host = host, port = 80, method = 'GET', path = '/' })
        H.not_nil(norm, 'host ' .. host)
    end
end)

-- ---------------------------------------------------------- adversarial

H.test('non-loopback hosts are refused naming the policy', true, function()
    for _, host in ipairs({ '8.8.8.8', 'example.com', '0.0.0.0', '[::1]' }) do
        local norm, err =
            http._validate_opts({ host = host, port = 80, method = 'GET', path = '/' })
        H.is_nil(norm)
        H.matches(err, 'non-loopback host refused')
        H.matches(err, 'localhost-only')
    end
end)

H.test('path must start with /', true, function()
    local norm, err = http._validate_opts({
        host = '127.0.0.1',
        port = 80,
        method = 'GET',
        path = 'status',
    })
    H.is_nil(norm)
    H.matches(err, 'starting with /')
end)

H.test('method outside GET/POST/PUT is refused', true, function()
    for _, method in ipairs({ 'DELETE', 'delete', 'PATCH', '' }) do
        local norm, err =
            http._validate_opts({ host = '127.0.0.1', port = 80, method = method, path = '/' })
        H.is_nil(norm)
        H.matches(err, 'GET')
    end
end)

H.test('malformed status line is an error, never a response', true, function()
    local r, err = http._parse_response('GARBAGE\r\n\r\n', true)
    H.is_nil(r)
    H.matches(err, 'malformed status line')
end)

H.test('truncated body is an error, never partial success', true, function()
    local raw = 'HTTP/1.1 200 OK\r\nContent-Length: 100\r\n\r\n' .. string.rep('x', 40)
    local r, err = http._parse_response(raw, true) -- eof with short body
    H.is_nil(r)
    H.matches(err, 'truncated body')
end)

H.test('oversize body is rejected', true, function()
    local raw = 'HTTP/1.1 200 OK\r\nContent-Length: ' .. (http.BODY_BYTES_MAX + 1) .. '\r\n\r\n'
    local r, err = http._parse_response(raw, false)
    H.is_nil(r)
    H.matches(err, 'BODY_BYTES_MAX')
end)

H.test('invalid ports and timeouts are refused', true, function()
    local bad_ports = { 0, 99999, 1.5, '80' }
    for _, port in ipairs(bad_ports) do
        local norm =
            http._validate_opts({ host = '127.0.0.1', port = port, method = 'GET', path = '/' })
        H.is_nil(norm, 'port ' .. tostring(port))
    end
    local norm, err = http._validate_opts({
        host = '127.0.0.1',
        port = 80,
        method = 'GET',
        path = '/',
        timeout_ms = -5,
    })
    H.is_nil(norm)
    H.matches(err, 'timeout_ms')
end)

-- ---------------------------------------------------------- live (Neovim only)

H.test('live: request round-trips against a local TCP server', false, function()
    if not H.live() then
        error('SKIP', 0)
    end
    local uv = vim.uv
    local server = uv.new_tcp()
    server:bind('127.0.0.1', 0)
    local _, bound_port = server:getsockname()
    server:listen(1, function()
        local client = uv.new_tcp()
        server:accept(client)
        client:read_start(function(_, chunk)
            if chunk and chunk:find('\r\n\r\n', 1, true) then
                client:write(resp_200('{"ready":true}'), function()
                    client:close()
                end)
            end
        end)
    end)
    local resp, err = http.request({
        host = '127.0.0.1',
        port = bound_port,
        method = 'GET',
        path = '/status',
        timeout_ms = 3000,
    })
    server:close()
    H.is_nil(err, 'request error: ' .. tostring(err))
    H.not_nil(resp)
    H.eq(resp.status, 200)
    H.eq(resp.body, '{"ready":true}')
end)

H.test('live: silent server triggers the timeout, not a hang', true, function()
    if not H.live() then
        error('SKIP', 0)
    end
    local uv = vim.uv
    local server = uv.new_tcp()
    server:bind('127.0.0.1', 0)
    local _, bound_port = server:getsockname()
    server:listen(1, function()
        local client = uv.new_tcp()
        server:accept(client) -- accept and never reply
        _ = client
    end)
    local resp, err = http.request({
        host = '127.0.0.1',
        port = bound_port,
        method = 'GET',
        path = '/status',
        timeout_ms = 800,
    })
    server:close()
    H.is_nil(resp)
    H.matches(err, 'timeout')
end)

os.exit(H.run('bidi_http'))
