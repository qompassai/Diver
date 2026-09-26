-- /qompassai/Diver/lua/ai/rose/http.lua
-- Bounded asynchronous HTTP for local model endpoints (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Used for Ollama chat requests. Never invokes a shell and never reads
-- credentials; the curl argv is fixed and the URL is validated before any
-- process starts. Remote hosts require explicit allow_remote consent.

local M = { active = {} }
local uv = vim.uv or vim.loop

---@return table? net  -- vim.net when its request API exists
local function net_api()
    local ok, net = pcall(require, 'vim.net')
    return ok and type(net) == 'table' and type(net.request) == 'function' and net or nil
end

---@return table capabilities
function M.capabilities()
    local net = net_api()
    return {
        native_request = net ~= nil,
        system = type(vim.system) == 'function',
        curl = vim.fn.executable('curl') == 1,
        -- Current nightly vim.net follows redirects and reads curlrc, with no switches
        -- to disable either. auto must use the safe adapter until that changes.
        native_safe_options = false,
    }
end

---@param url string
---@param allow_remote boolean?
---@return string? invalid  -- reason, nil when the URL is acceptable
local function validate_url(url, allow_remote)
    if type(url) ~= 'string' or url:find('[%s%c]') then
        return 'invalid HTTP URL'
    end
    local scheme, authority = url:match('^(https?)://([^/]+)')
    if not scheme or authority:find('@', 1, true) or authority:find('[?#]') then
        return 'HTTP URL must use http(s), without userinfo, query or fragment in its authority'
    end
    local host = authority:match('^%[([^%]]+)%]:?%d*$') or authority:match('^([^:]+):?%d*$')
    if not host then
        return 'invalid HTTP host'
    end
    if not allow_remote and host ~= 'localhost' and host ~= '127.0.0.1' and host ~= '::1' then
        return 'remote Ollama requires ollama.allow_remote=true; no implicit cloud requests'
    end
end

local RESPONSE_BYTES_MAX_DEFAULT = 8 * 1024 * 1024
local TIMEOUT_MS_DEFAULT = 120000
local transports = { auto = true, curl = true, native = true }

---@param opts table request options
---@param timeout_ms integer
---@return string[] argv
local function curl_argv(opts, timeout_ms)
    local argv = {
        'curl',
        '--disable',
        '--silent',
        '--show-error',
        '--fail',
        '--proto',
        '=http,https',
        '--max-redirs',
        '0',
        '--noproxy',
        '*',
        '--max-time',
        tostring(timeout_ms / 1000),
        '--request',
        opts.method or 'POST',
        '--header',
        'Content-Type: application/json',
    }
    if opts.body then
        vim.list_extend(argv, { '--data-binary', '@-' })
    end
    -- --write-out allows refusal of redirects instead of silently treating a 3xx
    -- body as success. --disable first ignores ~/.curlrc.
    vim.list_extend(argv, { '--write-out', '\n%{http_code}', '--url', opts.url })
    return argv
end

-- Interpret a finished curl process: exit code first, then the trailing status line.
---@param res table vim.system result
---@param finish fun(err: string?, body: string?)
local function curl_finish(res, finish)
    if res.code ~= 0 then
        finish('HTTP failed (' .. res.code .. '): ' .. (res.stderr or ''))
        return
    end
    local body, code = (res.stdout or ''):match('^(.*)\n(%d%d%d)$')
    if not code or tonumber(code) < 200 or tonumber(code) >= 300 then
        finish('HTTP status ' .. tostring(code) .. ' (redirects are not followed)')
        return
    end
    finish(nil, body)
end

-- Start the process for the selected transport; returns pcall-style ok, handle_or_error.
---@param opts table
---@param transport string
---@param timeout_ms integer
---@param finish fun(err: string?, body: string?)
---@return boolean ok
---@return any handle_or_nil
---@return string? unavailable
local function request_start(opts, transport, timeout_ms, finish)
    -- Explicit native mode is for endpoints whose redirects and local curl
    -- configuration the user trusts. It uses the real 0.13 method-first API.
    if transport == 'native' then
        local net = net_api()
        if not net then
            return false, nil, 'vim.net.request unavailable; use auto or curl'
        end
        return pcall(net.request, opts.method or 'POST', opts.url, {
            body = opts.body,
            retry = 0,
            headers = { ['Content-Type'] = 'application/json' },
        }, function(err, response)
            if err then
                finish(err)
            elseif type(response) ~= 'table' or type(response.body) ~= 'string' then
                finish('HTTP returned no valid response body')
            else
                finish(nil, response.body)
            end
        end)
    end
    local argv = curl_argv(opts, timeout_ms)
    return pcall(vim.system, argv, { stdin = opts.body, text = true }, function(res)
        curl_finish(res, finish)
    end)
end

---@class AiRoseHttpOptions
---@field url string
---@field body string?
---@field method string?
---@field timeout integer?
---@field max_response integer?
---@field allow_remote boolean?
---@field transport string?

---@param opts AiRoseHttpOptions
---@param callback fun(err: string?, body: string?)
---@return table token  -- token.cancel() aborts the request
function M.request(opts, callback)
    assert(type(opts) == 'table', 'http.request: opts must be a table')
    assert(type(callback) == 'function', 'http.request: callback must be a function')
    local handle, timer, done
    local token = {}
    local response_bytes_max = opts.max_response or RESPONSE_BYTES_MAX_DEFAULT
    local function finish(err, body)
        if done then
            return
        end
        if body and #body > response_bytes_max then
            err, body = 'HTTP response exceeds size limit', nil
        end
        done = true
        M.active[token] = nil
        if timer then
            timer:stop()
            timer:close()
            timer = nil
        end
        vim.schedule(function()
            callback(err, body)
        end)
    end
    local function terminate()
        if handle and handle.close then
            pcall(handle.close, handle)
        elseif handle and handle.kill then
            pcall(handle.kill, handle, 9)
        end
    end
    function token.cancel()
        if done then
            return
        end
        finish('cancelled')
        terminate()
    end
    M.active[token] = true
    local invalid = validate_url(opts.url, opts.allow_remote)
    if invalid then
        finish(invalid)
        return token
    end
    if type(vim.system) ~= 'function' or vim.fn.executable('curl') ~= 1 then
        finish('HTTP unavailable: vim.system (Neovim 0.10+) and curl are required')
        return token
    end
    local transport = opts.transport or 'auto'
    if not transports[transport] then
        finish('unknown HTTP transport: ' .. tostring(transport))
        return token
    end
    local timeout_ms = opts.timeout or TIMEOUT_MS_DEFAULT
    timer = uv.new_timer()
    if not timer then
        finish('could not create HTTP timeout timer')
        return token
    end
    timer:start(timeout_ms, 0, function()
        finish('HTTP timeout after ' .. timeout_ms .. 'ms')
        terminate()
    end)
    local ok, result, unavailable = request_start(opts, transport, timeout_ms, finish)
    if unavailable then
        finish(unavailable)
    elseif ok and result then
        handle = result
        if done then
            terminate()
        end
    else
        finish('HTTP start failed: ' .. tostring(result))
    end
    return token
end

-- Cancel every in-flight request.
--- Cancel every in-flight HTTP request.
function M.stop()
    local tokens = {}
    for token in pairs(M.active) do
        tokens[#tokens + 1] = token
    end
    for _, token in ipairs(tokens) do
        token.cancel()
    end
end

return M
