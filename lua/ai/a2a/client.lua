-- /qompassai/Diver/lua/ai/a2a/client.lua
-- Qompass AI A2A JSON-RPC Client (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Speaks the Agent2Agent v1.0.1 JSON-RPC 2.0 binding over HTTP(S)
-- with curl through vim.system in argv form: no shell, no extra
-- dependencies. (A2A also defines GRPC and HTTP+JSON bindings and a
-- v1.0 ProtoJSON wire shape; this module implements the JSON-RPC
-- shape — SendMessage, SendStreamingMessage, GetTask, ListTasks,
-- CancelTask — since JSONRPC is the default binding when a card
-- expresses no preference. ProtoJSON enum names are used on the
-- wire: TASK_STATE_* states, ROLE_USER/ROLE_AGENT roles, no kind
-- discriminators on messages or parts.) Plain http:// is
-- accepted only for loopback hosts (local flow workers); every other
-- host must be https://, and URLs with embedded credentials are
-- rejected outright. Streaming uses SendStreamingMessage over SSE
-- parsed incrementally, so progress updates arrive without running an
-- inbound webhook server. Every request carries the A2A-Version: 1.0
-- service header.

local M = {}

local CONNECT_TIMEOUT_S = 5
local REQUEST_TIMEOUT_MS = 30000
local RESPONSE_MAX_BYTES = 8 * 1024 * 1024
local USER_AGENT = 'Diver-a2a-client'

local next_id = 1

local A2A_PROTOCOL_VERSION = '1.0'
local BINDING_JSONRPC = 'JSONRPC'

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

-- Picks the AgentInterface diver talks to. Legacy v0.3 cards carry
-- a top-level `url` and are treated as a single JSONRPC interface;
-- v1.0 cards carry `supportedInterfaces[]` (first entry preferred per
-- spec). Among valid JSONRPC entries the one advertising
-- protocolVersion '1.0' wins; otherwise the first valid one does.
-- The interface's `tenant`, when set, must be echoed in the `tenant`
-- field of every request (§4.4.6).
---@param card table
---@return table? interface, or nil plus a reason.
---@return string?
function M.interface(card)
    if type(card) ~= 'table' then
        return nil, 'card must be a table'
    end
    local ifaces = {}
    if type(card.url) == 'string' and card.url ~= '' then
        ifaces[1] = { url = card.url, protocolBinding = BINDING_JSONRPC }
    else
        local raw = card.supportedInterfaces or card.supported_interfaces
        if type(raw) == 'table' then
            for _, iface in ipairs(raw) do
                if type(iface) == 'table' then
                    ifaces[#ifaces + 1] = iface
                end
            end
        end
    end
    local fallback = nil
    for _, iface in ipairs(ifaces) do
        local binding = iface.protocolBinding or iface.protocol_binding
        local url = iface.url
        if type(url) == 'string' and url ~= '' and (binding == nil or binding == BINDING_JSONRPC) then
            local ok, err = M.check_url(url)
            if ok then
                if (iface.protocolVersion or iface.protocol_version) == A2A_PROTOCOL_VERSION then
                    return iface
                end
                if not fallback then
                    fallback = iface
                end
            else
                -- URL policy failure is fatal: the card names an
                -- endpoint diver refuses to touch.
                return nil, err
            end
        end
    end
    if fallback then
        return fallback
    end
    return nil, 'card has no usable JSONRPC endpoint URL'
end

-- A2A v0.3 cards carry a top-level `url`; v1.0 cards replaced it with
-- `supportedInterfaces[]`. Accept either; the URL policy in
-- check_url still applies to whatever comes out.
---@param card table
---@return string? endpoint URL, or nil plus a reason.
---@return string?
function M.card_endpoint(card)
    local iface, err = M.interface(card)
    if not iface then
        return nil, err
    end
    return iface.url
end

-- Builds the params table for a request, echoing the interface tenant
-- when the card declares one. extra may be nil.
---@param card table
---@param extra? table
---@return table? params, or nil plus a reason.
---@return string?
local function request_params(card, extra)
    local iface, err = M.interface(card)
    if not iface then
        return nil, err
    end
    local params = {}
    local tenant = iface.tenant
    if type(tenant) == 'string' and tenant ~= '' then
        params.tenant = tenant
    end
    if type(extra) == 'table' then
        for k, v in pairs(extra) do
            params[k] = v
        end
    end
    return params
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
        -- Service parameter (§3.2.6): names the protocol version this
        -- client speaks. Sent on every request, including card fetches.
        '--header',
        'A2A-Version: ' .. A2A_PROTOCOL_VERSION,
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

---@param argv string[] curl argv to append to.
---@param extensions? table List of extension URIs the caller opts into.
local function maybe_add_extensions_header(argv, extensions)
    if type(extensions) ~= 'table' or #extensions == 0 then
        return
    end
    local uris = {}
    for _, uri in ipairs(extensions) do
        if type(uri) == 'string' and uri ~= '' then
            uris[#uris + 1] = uri
        end
    end
    if #uris > 0 then
        -- Service parameter (§3.2.6): comma-separated extension URIs.
        argv[#argv + 1] = '--header'
        argv[#argv + 1] = 'A2A-Extensions: ' .. table.concat(uris, ',')
    end
end

---@param url string
---@param body table JSON-RPC payload
---@param opts? { timeout_ms?: integer, max_bytes?: integer, extensions?: table }
---@param callback fun(ok: boolean, result: table?, err: string?)
local function post_json(url, body, opts, callback)
    opts = opts or {}
    local timeout_ms = opts.timeout_ms or REQUEST_TIMEOUT_MS
    local max_bytes = opts.max_bytes or RESPONSE_MAX_BYTES
    local argv = curl_base(url)
    maybe_add_extensions_header(argv, opts.extensions)
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
---@param opts { extensions?: table }
---@param on_event fun(event: table)
---@param on_done fun(ok: boolean, err: string?)
---@return vim.SystemObj? handle Kill it to cancel; nil when spawn failed.
local function stream_post(url, body, opts, on_event, on_done)
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
    maybe_add_extensions_header(argv, opts.extensions)
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
---@param extensions? table Extension URIs to declare on the message.
---@return table A2A v1.0 Message with a single text part.
local function text_message(text, extensions)
    message_seq = message_seq + 1
    local msg = {
        -- Session-unique id; the spec suggests UUIDs but only requires
        -- the creator to mint a unique id per message.
        messageId = 'diver-msg-' .. message_seq,
        role = 'ROLE_USER',
        -- v1.0 Parts are a oneof: exactly one of text/raw/url/data,
        -- no kind discriminator.
        parts = { { text = text } },
    }
    if type(extensions) == 'table' and #extensions > 0 then
        local uris = {}
        for _, uri in ipairs(extensions) do
            if type(uri) == 'string' and uri ~= '' then
                uris[#uris + 1] = uri
            end
        end
        if #uris > 0 then
            msg.extensions = uris
        end
    end
    return msg
end

---@param card A2aAgentCard
---@param text string
---@param opts? { timeout_ms?: integer, max_bytes?: integer, extensions?: table }
---@param callback fun(ok: boolean, result: table?, err: string?)
function M.message_send(card, text, opts, callback)
    assert(type(card) == 'table', 'card must be a table')
    assert(type(text) == 'string' and text ~= '', 'text must be nonempty')
    assert(type(callback) == 'function', 'callback must be a function')
    opts = opts or {}
    local url, url_err = M.card_endpoint(card)
    if not url then
        callback(false, nil, url_err)
        return
    end
    local params, perr = request_params(card, { message = text_message(text, opts.extensions) })
    if not params then
        callback(false, nil, perr)
        return
    end
    post_json(url, rpc_body('SendMessage', params), opts, callback)
end

---@param card A2aAgentCard
---@param text string
---@param opts? { extensions?: table }
---@param on_event fun(event: table)
---@param on_done fun(ok: boolean, err: string?)
---@return vim.SystemObj? handle Kill it to cancel; nil when spawn failed.
function M.message_stream(card, text, opts, on_event, on_done)
    assert(type(card) == 'table', 'card must be a table')
    assert(type(text) == 'string' and text ~= '', 'text must be nonempty')
    assert(type(opts) == 'table', 'opts must be a table')
    assert(type(on_event) == 'function', 'on_event must be a function')
    assert(type(on_done) == 'function', 'on_done must be a function')
    local url, url_err = M.card_endpoint(card)
    if not url then
        vim.schedule(function()
            on_done(false, url_err)
        end)
        return nil
    end
    local params, perr = request_params(card, { message = text_message(text, opts.extensions) })
    if not params then
        vim.schedule(function()
            on_done(false, perr)
        end)
        return nil
    end
    return stream_post(url, rpc_body('SendStreamingMessage', params), opts, on_event, on_done)
end

---@param card A2aAgentCard
---@param task_id string Remote task id.
---@param opts? { timeout_ms?: integer, max_bytes?: integer }
---@param callback fun(ok: boolean, result: table?, err: string?)
function M.task_get(card, task_id, opts, callback)
    assert(type(card) == 'table', 'card must be a table')
    assert(type(task_id) == 'string' and task_id ~= '', 'task_id must be nonempty')
    assert(type(callback) == 'function', 'callback must be a function')
    local url, url_err = M.card_endpoint(card)
    if not url then
        callback(false, nil, url_err)
        return
    end
    local params, perr = request_params(card, { id = task_id })
    if not params then
        callback(false, nil, perr)
        return
    end
    post_json(url, rpc_body('GetTask', params), opts or {}, callback)
end

---@param card A2aAgentCard
---@param task_id string Remote task id.
---@param opts? { timeout_ms?: integer, max_bytes?: integer }
---@param callback fun(ok: boolean, result: table?, err: string?)
function M.task_cancel(card, task_id, opts, callback)
    assert(type(card) == 'table', 'card must be a table')
    assert(type(task_id) == 'string' and task_id ~= '', 'task_id must be nonempty')
    assert(type(callback) == 'function', 'callback must be a function')
    local url, url_err = M.card_endpoint(card)
    if not url then
        callback(false, nil, url_err)
        return
    end
    local params, perr = request_params(card, { id = task_id })
    if not params then
        callback(false, nil, perr)
        return
    end
    post_json(url, rpc_body('CancelTask', params), opts or {}, callback)
end

---@param card A2aAgentCard
---@param opts? { context_id?: string, status?: string, page_size?: integer,
---  page_token?: string, timeout_ms?: integer, max_bytes?: integer }
---@param callback fun(ok: boolean, result: table?, err: string?)
function M.task_list(card, opts, callback)
    assert(type(card) == 'table', 'card must be a table')
    assert(type(callback) == 'function', 'callback must be a function')
    opts = opts or {}
    local url, url_err = M.card_endpoint(card)
    if not url then
        callback(false, nil, url_err)
        return
    end
    local extra = {}
    if type(opts.context_id) == 'string' and opts.context_id ~= '' then
        extra.contextId = opts.context_id
    end
    if type(opts.status) == 'string' and opts.status ~= '' then
        extra.status = opts.status
    end
    if type(opts.page_size) == 'number' then
        extra.pageSize = math.floor(opts.page_size)
    end
    if type(opts.page_token) == 'string' and opts.page_token ~= '' then
        extra.pageToken = opts.page_token
    end
    local params, perr = request_params(card, extra)
    if not params then
        callback(false, nil, perr)
        return
    end
    post_json(url, rpc_body('ListTasks', params), opts, callback)
end

return M
