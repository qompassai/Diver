-- Purpose: minimal synchronous HTTP/1.1 client over native vim.uv TCP.
-- Built for loopback automation endpoints only (the WebDriver BiDi
-- `/session` handshake and the CDP discovery client share it). Localhost
-- only: any non-loopback host is a hard error naming the policy. The call
-- blocks the editor up to timeout_ms via vim.wait; responses are bounded
-- and malformed replies return (nil, err), never partial success.

local M = {}

---@class BrowserHttpOpts
---@field host string must be loopback: 127.0.0.1, ::1, or localhost, else (nil, err)
---@field port integer
---@field method 'GET'|'POST'|'PUT'
---@field path string must start with /
---@field body? string
---@field headers? table<string,string>
---@field timeout_ms? integer default TIMEOUT_MS_DEFAULT = 5000

---@class BrowserHttpResponse
---@field status integer
---@field headers table<string,string>
---@field body string bounded by BODY_BYTES_MAX = 1048576

---Default per-request timeout, milliseconds.
M.TIMEOUT_MS_DEFAULT = 5000
---Hard cap on response body bytes. Over it -> (nil, err).
M.BODY_BYTES_MAX = 1048576

local PORT_MIN = 1
local PORT_MAX = 65535
local HEADER_BYTES_MAX = 16384 -- status line + headers, before body
local POLL_INTERVAL_MS = 25 -- vim.wait pump granularity

local LOOPBACK_HOSTS = {
    ['127.0.0.1'] = true,
    ['::1'] = true,
    ['localhost'] = true,
}
local METHODS = { GET = true, POST = true, PUT = true }

---True when host is one of the loopback names this client allows.
---@param host string
---@return boolean
function M._is_loopback(host)
    return LOOPBACK_HOSTS[host] == true
end

---Validate opts into a normalized table. Pure; no I/O.
---@param opts BrowserHttpOpts
---@return table? normalized {host,port,method,path,body,headers,timeout_ms}
---@return string? err
function M._validate_opts(opts)
    if type(opts) ~= 'table' then
        return nil, 'opts must be a table'
    end
    local host = opts.host
    if type(host) ~= 'string' or host == '' then
        return nil, 'host must be a non-empty string'
    end
    if not M._is_loopback(host) then
        return nil, 'browser.http: non-loopback host refused (policy: localhost-only): ' .. host
    end
    local port = opts.port
    if type(port) ~= 'number' or port ~= math.floor(port) or port < PORT_MIN or port > PORT_MAX then
        return nil, 'port must be an integer 1-65535'
    end
    local method = opts.method
    if METHODS[method] ~= true then
        return nil, "method must be one of 'GET', 'POST', 'PUT'"
    end
    local path = opts.path
    if type(path) ~= 'string' or path:sub(1, 1) ~= '/' then
        return nil, 'path must be a string starting with /'
    end
    local body = opts.body
    if body == nil then
        body = ''
    end
    if type(body) ~= 'string' then
        return nil, 'body must be a string'
    end
    local headers = opts.headers
    if headers == nil then
        headers = {}
    end
    if type(headers) ~= 'table' then
        return nil, 'headers must be a table<string,string>'
    end
    for name, value in pairs(headers) do
        if type(name) ~= 'string' or type(value) ~= 'string' then
            return nil, 'headers must be a table<string,string>'
        end
    end
    local timeout_ms = opts.timeout_ms
    if timeout_ms == nil then
        timeout_ms = M.TIMEOUT_MS_DEFAULT
    end
    if type(timeout_ms) ~= 'number' or timeout_ms <= 0 then
        return nil, 'timeout_ms must be a positive number'
    end
    return {
        host = host,
        port = port,
        method = method,
        path = path,
        body = body,
        headers = headers,
        timeout_ms = timeout_ms,
    }, nil
end

---Build the raw HTTP/1.1 request text. Pure; no I/O.
---@param norm table normalized opts from _validate_opts
---@return string
function M._build_request(norm)
    local names = {}
    for name in pairs(norm.headers) do
        names[#names + 1] = name
    end
    table.sort(names) -- deterministic serialization
    local lines = {
        norm.method .. ' ' .. norm.path .. ' HTTP/1.1',
        'Host: ' .. norm.host .. ':' .. norm.port,
        'Connection: close',
    }
    if #norm.body > 0 then
        lines[#lines + 1] = 'Content-Length: ' .. #norm.body
    end
    for i = 1, #names do
        lines[#lines + 1] = names[i] .. ': ' .. norm.headers[names[i]]
    end
    return table.concat(lines, '\r\n') .. '\r\n\r\n' .. norm.body
end

---@param line string status line, e.g. 'HTTP/1.1 200 OK'
---@return integer? status
---@return string? err
local function parse_status_line(line)
    local status = line:match('^HTTP/%d%.%d%s+(%d%d%d)%s')
        or line:match('^HTTP/%d%.%d%s+(%d%d%d)$')
    if status == nil then
        return nil, 'malformed status line: ' .. line:sub(1, 64)
    end
    return tonumber(status), nil
end

---@param block string raw header block (no trailing blank line)
---@return table<string,string> lowercased header names
local function parse_headers(block)
    local headers = {}
    for line in block:gmatch('[^\r\n]+') do
        local name, value = line:match('^([^:]+):%s*(.-)%s*$')
        if name ~= nil then
            headers[name:lower()] = value
        end
    end
    return headers
end

---Parse a response buffer. Returns response, or (nil, nil, true) when more
---bytes are needed, or (nil, err) on malformed/oversize input. When eof is
---true, an incomplete body is a truncation error, not a wait.
---@param buf string bytes received so far
---@param eof boolean remote closed the connection
---@return BrowserHttpResponse? resp
---@return string? err
---@return boolean? incomplete
function M._parse_response(buf, eof)
    local eoh = buf:find('\r\n\r\n', 1, true)
    if eoh == nil then
        if #buf > HEADER_BYTES_MAX then
            return nil, 'response header too large', false
        end
        return nil, nil, true
    end
    local head = buf:sub(1, eoh - 1)
    local rest = buf:sub(eoh + 4)
    local first_nl = head:find('\r\n', 1, true)
    local status_line = first_nl and head:sub(1, first_nl - 1) or head
    local status, serr = parse_status_line(status_line)
    if status == nil then
        return nil, serr, false
    end
    local headers = parse_headers(first_nl and head:sub(first_nl + 2) or '')
    local content_length = tonumber(headers['content-length'])
    local body
    if content_length ~= nil then
        if content_length < 0 then
            return nil, 'negative content-length', false
        end
        if content_length > M.BODY_BYTES_MAX then
            return nil, 'response body exceeds BODY_BYTES_MAX', false
        end
        if #rest < content_length then
            if eof then
                return nil,
                    'truncated body: expected ' .. content_length .. ', got ' .. #rest,
                    false
            end
            return nil, nil, true
        end
        body = rest:sub(1, content_length)
    else
        -- No length framing: body runs to connection close.
        if #rest > M.BODY_BYTES_MAX then
            return nil, 'response body exceeds BODY_BYTES_MAX', false
        end
        if not eof then
            return nil, nil, true
        end
        body = rest
    end
    return { status = status, headers = headers, body = body }, nil, nil
end

---Feed one received chunk into the response parser. Leaf for run_exchange.
---@param state table request state
---@param chunk string? nil on EOF
---@param finish fun(resp: table?, rerr: string?)
local function on_chunk(state, chunk, finish)
    if chunk == nil then
        local resp, perr = M._parse_response(state.buf, true)
        if resp ~= nil then
            finish(resp, nil)
        else
            finish(nil, perr or 'truncated response')
        end
        return
    end
    state.buf = state.buf .. chunk
    if #state.buf > HEADER_BYTES_MAX + M.BODY_BYTES_MAX then
        finish(nil, 'response exceeds BODY_BYTES_MAX')
        return
    end
    local resp, perr, incomplete = M._parse_response(state.buf, false)
    if resp ~= nil then
        finish(resp, nil)
    elseif perr ~= nil then
        finish(nil, perr)
    elseif not incomplete then
        finish(nil, 'response parse stalled')
    end
    -- incomplete: keep reading until EOF or timeout.
end

---Open the TCP connection and run the HTTP exchange. Leaf for M.request.
---@param state table request state
---@param norm table normalized opts
---@param finish fun(resp: table?, rerr: string?)
---@return string? err
local function run_exchange(state, norm, finish)
    local uv = vim.uv
    -- 'localhost' always resolves to 127.0.0.1 here; no DNS is attempted.
    local host = norm.host == 'localhost' and '127.0.0.1' or norm.host
    local sock = uv.new_tcp()
    if sock == nil then
        return 'cannot allocate TCP handle'
    end
    state.sock = sock
    sock:connect(host, norm.port, function(connect_err)
        if connect_err ~= nil then
            finish(nil, 'connect failed: ' .. connect_err)
            return
        end
        sock:write(M._build_request(norm))
        sock:read_start(function(read_err, chunk)
            if read_err ~= nil then
                finish(nil, 'read error: ' .. read_err)
                return
            end
            on_chunk(state, chunk, finish)
        end)
    end)
    return nil
end

---Perform one HTTP/1.1 request over a fresh TCP connection
---(`Connection: close`, no keep-alive). Synchronous: pumps the event loop
---with vim.wait up to timeout_ms.
---@param opts BrowserHttpOpts
---@return BrowserHttpResponse|nil, string|nil
function M.request(opts)
    local norm, verr = M._validate_opts(opts)
    if norm == nil then
        return nil, verr
    end
    local state = {
        done = false,
        resp = nil,
        rerr = nil,
        buf = '',
        sock = nil,
        timer = nil,
    }
    local function finish(resp, rerr)
        if state.done then
            return
        end
        state.done = true
        state.resp = resp
        state.rerr = rerr
        if state.timer ~= nil then
            local timer = state.timer
            state.timer = nil
            if not timer:is_closing() then
                timer:stop()
                timer:close()
            end
        end
        if state.sock ~= nil then
            local sock = state.sock
            state.sock = nil
            if not sock:is_closing() then
                sock:close()
            end
        end
    end
    local xerr = run_exchange(state, norm, finish)
    if xerr ~= nil then
        return nil, xerr
    end
    local timer = vim.uv.new_timer()
    if timer ~= nil then
        state.timer = timer
        timer:start(norm.timeout_ms, 0, function()
            finish(nil, 'timeout after ' .. norm.timeout_ms .. 'ms')
        end)
    end
    vim.wait(norm.timeout_ms + 1000, function()
        return state.done
    end, POLL_INTERVAL_MS)
    if not state.done then
        finish(nil, 'timeout after ' .. norm.timeout_ms .. 'ms')
    end
    return state.resp, state.rerr
end

return M
