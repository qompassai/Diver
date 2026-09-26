-- /qompassai/Diver/lua/ai/a2a/client.lua
-- Qompass AI A2A JSON-RPC Client (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Speaks the Agent2Agent v0.3.x JSON-RPC 2.0 binding over HTTP(S)
-- with curl through vim.system in argv form: no shell, no extra
-- dependencies. (A2A also defines GRPC and HTTP+JSON bindings and a
-- v1.0 ProtoJSON wire shape; this module implements the v0.3 JSON-RPC
-- shape — message/send, message/stream, tasks/get, tasks/cancel —
-- since JSONRPC is the default binding when a card expresses no
-- preference.) Plain http:// is
-- accepted only for loopback hosts (local flow workers); every other
-- host must be https://, and URLs with embedded credentials are
-- rejected outright. Streaming uses message/stream over SSE parsed
-- incrementally, so progress updates arrive without running an
-- inbound webhook server.

local M = {}

local CONNECT_TIMEOUT_S = 5
local REQUEST_TIMEOUT_MS = 30000
local RESPONSE_MAX_BYTES = 8 * 1024 * 1024
local USER_AGENT = 'Diver-a2a-client'

local next_id = 1

---@param url string
---@return boolean, string?
function M.check_url(url)
    if type(url) ~= 'string' then
        return false, 'URL must be a string'
    end
    local scheme, rest = url:match('^(https?)://(.+)$')
    if not scheme then
        return false, 'URL must start with http:// or https://'
    end
    if url:find('@', 1, true) then
        return false, 'URL must not embed credentials'
    end
    local host = rest:match('^%[([^%]]+)%]') or rest:match('^([^:/?#]+)')
    if not host or host == '' then
        return false, 'URL has no host'
    end
    if scheme == 'http' then
        local loopback = host == 'localhost' or host == '127.0.0.1' or host == '::1'
        if not loopback then
            return false, 'plain http:// is allowed only for loopback hosts'
        end
    end
    return true
end

-- A2A v0.3 cards carry a top-level `url`; v1.0 cards replaced it with
-- `supportedInterfaces[]` (first entry preferred, JSONRPC binding
-- preferred). Accept either; the URL policy in check_url still
-- applies to whatever comes out.
---@param card table
---@return string? endpoint URL, or nil plus a reason.
---@return string?
function M.card_endpoint(card)
    if type(card) ~= 'table' then
        return nil, 'card must be a table'
    end
    if type(card.url) == 'string' and card.url ~= '' then
        local ok, err = M.check_url(card.url)
        if not ok then
            return nil, err
        end
        return card.url
    end
    local ifaces = card.supportedInterfaces or card.supported_interfaces
    if type(ifaces) == 'table' then
        for _, iface in ipairs(ifaces) do
            local binding = iface.protocolBinding or iface.protocol_binding
            if type(iface.url) == 'string' and iface.url ~= '' and (binding == nil or binding == 'JSONRPC') then
                local ok = M.check_url(iface.url)
                if ok then
                    return iface.url
                end
            end
        end
    end
    return nil, 'card has no usable JSONRPC endpoint URL'
end

---@param url string Already validated by check_url.
---@return string[] argv
local function curl_base(url)
    local proto = url:match('^https://') and '=https' or '=http,https'
    return {
        'curl',
        '--disable',
        '--fail',
        '--silent',
        '--show-error',
        '--location',
        '--proto',
        proto,
        '--connect-timeout',
        tostring(CONNECT_TIMEOUT_S),
        '--header',
        'Accept: application/json',
        '--user-agent',
        USER_AGENT,
    }
end

---@param result vim.SystemCompleted
---@param max_bytes integer
---@return boolean, table?, string?
local function decode_document(result, max_bytes)
    if result.code ~= 0 then
        local detail = tostring(result.stderr or ''):sub(1, 200)
        return false, nil, 'HTTP request failed: ' .. detail
    end
    if #result.stdout > max_bytes then
        return false, nil, 'response exceeds size bound'
    end
    local ok, decoded = pcall(vim.json.decode, result.stdout)
    if not ok or type(decoded) ~= 'table' then
        return false, nil, 'response was not valid JSON'
    end
    return true, decoded, nil
end

---@param result vim.SystemCompleted
---@param max_bytes integer
---@return boolean, table?, string?
local function decode_response(result, max_bytes)
    local ok, decoded, err = decode_document(result, max_bytes)
    if not ok or decoded == nil then
        return false, nil, err
    end
    if decoded.error ~= nil then
        local err_node = decoded.error
        local detail = 'A2A error ' .. tostring(err_node.code) .. ': ' .. tostring(err_node.message)
        return false, nil, detail
    end
    return true, decoded.result, nil
end

---@param url string
---@param body table JSON-RPC payload
---@param opts? { timeout_ms?: integer, max_bytes?: integer }
---@param callback fun(ok: boolean, result: table?, err: string?)
local function post_json(url, body, opts, callback)
    opts = opts or {}
    local timeout_ms = opts.timeout_ms or REQUEST_TIMEOUT_MS
    local max_bytes = opts.max_bytes or RESPONSE_MAX_BYTES
    local argv = curl_base(url)
    argv[#argv + 1] = '--max-time'
    argv[#argv + 1] = tostring(math.max(1, math.floor(timeout_ms / 1000)))
    argv[#argv + 1] = '--header'
    argv[#argv + 1] = 'Content-Type: application/json'
    argv[#argv + 1] = '--data'
    argv[#argv + 1] = '@-'
    argv[#argv + 1] = url
    vim.system(argv, {
        stdin = vim.json.encode(body),
        timeout = timeout_ms + 2000,
    }, function(result)
        local ok, decoded, err = decode_response(result, max_bytes)
        vim.schedule(function()
            callback(ok, decoded, err)
        end)
    end)
end

---@param url string
---@param opts? { timeout_ms?: integer, max_bytes?: integer }
---@param callback fun(ok: boolean, result: table?, err: string?)
function M.get(url, opts, callback)
    assert(type(url) == 'string', 'url must be a string')
    assert(type(callback) == 'function', 'callback must be a function')
    local valid, err = M.check_url(url)
    if not valid then
        callback(false, nil, err)
        return
    end
    opts = opts or {}
    local timeout_ms = opts.timeout_ms or REQUEST_TIMEOUT_MS
    local max_bytes = opts.max_bytes or RESPONSE_MAX_BYTES
    local argv = curl_base(url)
    argv[#argv + 1] = '--max-time'
    argv[#argv + 1] = tostring(math.max(1, math.floor(timeout_ms / 1000)))
    argv[#argv + 1] = url
    vim.system(argv, { timeout = timeout_ms + 2000 }, function(result)
        local ok, decoded, derr = decode_document(result, max_bytes)
        vim.schedule(function()
            callback(ok, decoded, derr)
        end)
    end)
end

---@param raw string One SSE event block, newlines normalized.
---@return string? Concatenated data payload, or nil when no data lines.
local function parse_sse_event(raw)
    local parts = {}
    for line in (raw .. '\n'):gmatch('([^\n]*)\n') do
        local datum = line:match('^data:%s?(.*)$')
        if datum then
            parts[#parts + 1] = datum
        end
    end
    if #parts == 0 then
        return nil
    end
    return table.concat(parts, '\n')
end

---@param url string
---@param body table JSON-RPC payload
---@param on_event fun(event: table)
---@param on_done fun(ok: boolean, err: string?)
---@return vim.SystemObj? handle Kill it to cancel; nil when spawn failed.
local function stream_post(url, body, on_event, on_done)
    local buffer = ''
    local finished = false
    local proc = nil

    local function finish(ok, err)
        if finished then
            return
        end
        finished = true
        vim.schedule(function()
            on_done(ok, err)
        end)
    end

    local function handle_chunk(data)
        buffer = (buffer .. data):gsub('\r\n', '\n')
        if #buffer > RESPONSE_MAX_BYTES then
            if proc then
                pcall(proc.kill, proc, 15)
            end
            finish(false, 'stream exceeds size bound')
            return
        end
        while true do
            local sep = buffer:find('\n\n', 1, true)
            if not sep then
                break
            end
            local raw = buffer:sub(1, sep - 1)
            buffer = buffer:sub(sep + 2)
            local datum = parse_sse_event(raw)
            if datum and datum ~= '[DONE]' then
                local ok, event = pcall(vim.json.decode, datum)
                if ok and type(event) == 'table' then
                    local event_copy = event
                    vim.schedule(function()
                        on_event(event_copy)
                    end)
                end
            end
        end
    end

    local argv = curl_base(url)
    argv[#argv + 1] = '--no-buffer'
    argv[#argv + 1] = '--header'
    argv[#argv + 1] = 'Content-Type: application/json'
    argv[#argv + 1] = '--data'
    argv[#argv + 1] = '@-'
    argv[#argv + 1] = url

    local spawned, handle = pcall(vim.system, argv, {
        stdin = vim.json.encode(body),
        stdout = function(err, data)
            if err then
                finish(false, 'stream read failed: ' .. tostring(err))
            elseif data then
                handle_chunk(data)
            end
        end,
    }, function(result)
        if result.code == 0 then
            finish(true, nil)
        else
            local detail = tostring(result.stderr or ''):sub(1, 200)
            finish(false, 'stream ended: ' .. detail)
        end
    end)
    if not spawned then
        finish(false, 'failed to spawn curl: ' .. tostring(handle))
        return nil
    end
    proc = handle
    return proc
end

---@param method string
---@return table JSON-RPC 2.0 envelope with a fresh id.
local function rpc_body(method, params)
    local id = next_id
    next_id = next_id + 1
    return { jsonrpc = '2.0', id = id, method = method, params = params }
end

local message_seq = 0
---@param text string
---@return table A2A v0.3 message with a single text part.
local function text_message(text)
    message_seq = message_seq + 1
    return {
        kind = 'message',
        messageId = 'diver-msg-' .. message_seq,
        role = 'user',
        parts = { { kind = 'text', text = text } },
    }
end

---@param card A2aAgentCard
---@param text string
---@param opts? { timeout_ms?: integer, max_bytes?: integer }
---@param callback fun(ok: boolean, result: table?, err: string?)
function M.message_send(card, text, opts, callback)
    assert(type(card) == 'table', 'card must be a table')
    assert(type(text) == 'string' and text ~= '', 'text must be nonempty')
    assert(type(callback) == 'function', 'callback must be a function')
    local url, err = M.card_endpoint(card)
    if not url then
        callback(false, nil, err)
        return
    end
    local body = rpc_body('message/send', { message = text_message(text) })
    post_json(url, body, opts or {}, callback)
end

---@param card A2aAgentCard
---@param text string
---@param on_event fun(event: table)
---@param on_done fun(ok: boolean, err: string?)
---@return vim.SystemObj? handle Kill it to cancel; nil when spawn failed.
function M.message_stream(card, text, on_event, on_done)
    assert(type(card) == 'table', 'card must be a table')
    assert(type(text) == 'string' and text ~= '', 'text must be nonempty')
    assert(type(on_event) == 'function', 'on_event must be a function')
    assert(type(on_done) == 'function', 'on_done must be a function')
    local url, err = M.card_endpoint(card)
    if not url then
        vim.schedule(function()
            on_done(false, err)
        end)
        return nil
    end
    local body = rpc_body('message/stream', { message = text_message(text) })
    return stream_post(url, body, on_event, on_done)
end

---@param card A2aAgentCard
---@param task_id string Remote task id.
---@param callback fun(ok: boolean, result: table?, err: string?)
function M.task_get(card, task_id, callback)
    assert(type(card) == 'table', 'card must be a table')
    assert(type(task_id) == 'string' and task_id ~= '', 'task_id must be nonempty')
    assert(type(callback) == 'function', 'callback must be a function')
    local url, err = M.card_endpoint(card)
    if not url then
        callback(false, nil, err)
        return
    end
    post_json(url, rpc_body('tasks/get', { id = task_id }), {}, callback)
end

---@param card A2aAgentCard
---@param task_id string Remote task id.
---@param callback fun(ok: boolean, result: table?, err: string?)
function M.task_cancel(card, task_id, callback)
    assert(type(card) == 'table', 'card must be a table')
    assert(type(task_id) == 'string' and task_id ~= '', 'task_id must be nonempty')
    assert(type(callback) == 'function', 'callback must be a function')
    local url, err = M.card_endpoint(card)
    if not url then
        callback(false, nil, err)
        return
    end
    local body = rpc_body('tasks/cancel', { id = task_id })
    post_json(url, body, {}, callback)
end

return M
