-- HTTP over an owned curl process; credentials/body travel through stdin, never argv.
-- Copyright (C) 2025 Qompass AI, All rights reserved
local config, util = require('acp.config'), require('acp.util')
local sse = require('acp.sse')
local M = {}
local active = {}
local REQUESTS_MAX, WIRE_BYTES_MAX, HEAD_BYTES_MAX = 32, 8 * 1024 * 1024, 16384

local function quoted(value)
    return '"'
        .. value
            :gsub('\\', '\\\\')
            :gsub('"', '\\"')
            :gsub('\r', '\\r')
            :gsub('\n', '\\n')
            :gsub('\t', '\\t')
        .. '"'
end

local function input(agent, request)
    local origin, err = config.url(request.url)
    if not origin or origin ~= config.url(agent.url) then
        return nil, err or 'HTTP origin is not the configured agent origin'
    end
    local lines =
        { 'url = ' .. quoted(request.url), 'request = ' .. quoted(request.method or 'GET') }
    lines[#lines + 1] = 'header = "Accept: application/json, text/event-stream"'
    lines[#lines + 1] = 'header = "Content-Type: application/json"'
    lines[#lines + 1] = 'header = "Expect:"'
    if agent.protocol == 'a2a' then
        lines[#lines + 1] = 'header = ' .. quoted('A2A-Version: ' .. agent.version)
    end
    if agent.token_env then
        local token = vim.env[agent.token_env]
        if not util.string(token, 8192) or token:find('[%c]') then
            return nil, 'Missing or invalid token in ' .. agent.token_env
        end
        lines[#lines + 1] = 'header = ' .. quoted('Authorization: Bearer ' .. token)
    end
    if request.body then
        local body, failure = util.json(request.body)
        if not body then
            return nil, failure
        end
        lines[#lines + 1] = 'data-binary = ' .. quoted(body)
    end
    return table.concat(lines, '\n') .. '\n'
end

local function body_chunk(state, chunk)
    if state.status < 200 or state.status >= 300 then
        return true -- Do not display an error body which could echo credentials.
    end
    if state.streaming then
        return sse.feed(state.parser, chunk)
    end
    state.body[#state.body + 1] = chunk
    return true
end

local function consume(state, chunk)
    if state.status then
        return body_chunk(state, chunk)
    end
    state.head = state.head .. chunk
    for _ = 1, 8 do
        local first, last = state.head:find('\r\n\r\n', 1, true)
        if not first then
            if #state.head > HEAD_BYTES_MAX then
                return nil, 'HTTP header limit'
            end
            return true
        end
        if last > HEAD_BYTES_MAX then
            return nil, 'HTTP header limit'
        end
        local header = state.head:sub(1, first - 1)
        local status = tonumber(header:match('^HTTP/[%d.]+ (%d%d%d)'))
        state.head = state.head:sub(last + 1)
        if not status then
            return nil, 'Malformed HTTP status'
        end
        if status >= 200 then
            state.status = status
            state.streaming = header:lower():find('\r\ncontent%-type:%s*text/event%-stream') ~= nil
            if state.streaming and not state.event then
                return nil, 'Unexpected event stream'
            end
            local rest = state.head
            state.head = ''
            return body_chunk(state, rest)
        end
    end
    return nil, 'Too many interim HTTP responses'
end

local function drain(state)
    state.scheduled = false
    local queue = state.queue
    state.queue = {}
    if state.done or state.failure then
        return
    end
    for _, chunk in ipairs(queue) do
        local called, ok, err = pcall(consume, state, chunk)
        if not called then
            err, ok = 'HTTP consumer failed: ' .. tostring(ok):sub(1, 1024), nil
        end
        if not ok then
            state.failure = err
            if state.process then
                state.process:kill(9)
            end
            break
        end
    end
end

local function complete(state, result)
    drain(state)
    if state.done then
        return
    end
    state.done = true
    active[state] = nil
    local err = state.failure ---@type string?
    if not err and (result.code ~= 0 or result.signal ~= 0) then
        err = ('HTTP process failed (%d); remote outcome may be unknown'):format(result.code)
    end
    if not err and (not state.status or state.status < 200 or state.status >= 300) then
        err = 'HTTP status ' .. tostring(state.status or 'missing')
    end
    local value
    if not err and state.streaming then
        local ok, failure = sse.finish(state.parser)
        err = not ok and failure or nil
    elseif not err then
        value, err = util.decode(table.concat(state.body))
    end
    state.queue, state.body, state.head = {}, {}, ''
    util.call(state.callback, value, err, state.streaming)
end

function M.request(agent, request, callback, event)
    local methods = { GET = true, POST = true, DELETE = true }
    if not methods[request.method or 'GET'] then
        return nil, 'Unsupported HTTP method'
    end
    if vim.tbl_count(active) >= REQUESTS_MAX then
        return nil, 'HTTP concurrency limit'
    end
    local stdin, err = input(agent, request)
    if not stdin then
        return nil, err
    end
    local executable = vim.fn.exepath(config.options.curl)
    if executable == '' then
        return nil, 'curl is required'
    end
    local state = {
        body = {},
        callback = callback,
        event = event,
        head = '',
        queue = {},
        bytes = 0,
    }
    state.parser = sse.new(function(data)
        local value, failure = util.decode(data)
        if not value then
            return nil, failure
        end
        return event(value)
    end)
    local timeout = request.stream and config.options.timeouts.turn_ms
        or config.options.timeouts.request_ms
    local argv = {
        executable,
        '--disable',
        '--config',
        '-',
        '--silent',
        '--show-error',
        '--no-buffer',
        '--include',
        '--globoff',
        '--proto',
        '=http,https',
        '--proxy',
        '',
        '--max-redirs',
        '0',
        '--connect-timeout',
        '10',
        '--max-time',
        tostring(timeout / 1000),
    }
    active[state] = true
    local ok, process = pcall(vim.system, argv, {
        cwd = vim.fn.getcwd(),
        clear_env = true,
        env = {},
        stdin = stdin,
        stdout = function(read_error, data)
            if state.done or state.failure then
                return
            end
            state.bytes = state.bytes + #(data or '')
            if read_error or state.bytes > WIRE_BYTES_MAX or #state.queue >= 4096 then
                state.failure = 'HTTP read or output limit failure'
                if state.process then
                    state.process:kill(9)
                end
                return
            end
            if data then
                state.queue[#state.queue + 1] = data
                if not state.scheduled then
                    state.scheduled = true
                    vim.schedule(function()
                        drain(state)
                    end)
                end
            end
        end,
        stderr = function() end,
    }, function(result)
        vim.schedule(function()
            complete(state, result)
        end)
    end)
    stdin = nil
    if not ok then
        active[state] = nil
        return nil, 'Could not launch curl'
    end
    state.process = process
    return {
        cancel = function()
            if not state.done and not state.failure then
                state.failure = 'Local HTTP observation cancelled; remote work may continue'
                process:kill(9)
            end
        end,
    }
end

function M.stop_all()
    for state in pairs(active) do
        state.failure = 'HTTP client closed'
        if state.process then
            state.process:kill(9)
        end
    end
end
return M
