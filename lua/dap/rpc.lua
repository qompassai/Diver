-- #################################################################
-- /qompassai/lua/dap/rpc.lua
-- Qompass AI Diver Debug Adapter Protocol (DAP) RPC Module
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
local utils = require('dap.utils')
local M = {}

--- Maximum accepted `Content-Length` for a single DAP message.
---
--- Debug-adapter messages are JSON-RPC payloads; even large `variables`
--- responses are kilobytes. A message claiming more than this is treated as
--- a framing attack or a corrupt stream: the parser aborts and the session
--- is expected to tear itself down via `on_error`.
--- (16 MiB; deliberately generous so no legitimate adapter trips it.)
local CONTENT_LENGTH_MAX = 16 * 1024 * 1024
---@param header string
---@return integer?
local function get_content_length(header)
    for line in header:gmatch('(.-)\r\n') do
        local key, value = line:match('^%s*(%S+)%s*:%s*(%d+)%s*$')
        if key and key:lower() == 'content-length' then
            local length = tonumber(value, 10)
            if length then
                return math.floor(length)
            end
        end
    end
    return nil
end
local parse_chunk_loop
local has_strbuffer, strbuffer = pcall(require, 'string.buffer')
if has_strbuffer then
    ---@async coroutine body: yields chunks via coroutine.yield, driven by resume_parse
    parse_chunk_loop = function()
        local buf = strbuffer.new()
        while true do
            local msg = buf:tostring()
            local header_end = msg:find('\r\n\r\n', 1, true)
            if header_end then
                local header = buf:get(header_end + 1)
                buf:skip(2)
                local content_length = get_content_length(header)
                if not content_length then
                    error('Content-Length not found in headers: ' .. header)
                end
                if content_length > CONTENT_LENGTH_MAX then
                    error(
                        string.format(
                            'Content-Length %d exceeds maximum %d; aborting message stream',
                            content_length,
                            CONTENT_LENGTH_MAX
                        )
                    )
                end
                while #buf < content_length do
                    local chunk = coroutine.yield()
                    buf:put(chunk)
                end
                local body = buf:get(content_length)
                coroutine.yield(body)
            else
                local chunk = coroutine.yield()
                buf:put(chunk)
            end
        end
    end
else
    ---@async coroutine body: yields chunks via coroutine.yield, driven by resume_parse
    parse_chunk_loop = function()
        local buffer = ''
        while true do
            local header_end, body_start = buffer:find('\r\n\r\n', 1, true)
            if header_end then
                local header = buffer:sub(1, header_end + 1)
                local content_length = get_content_length(header)
                if not content_length then
                    error('Content-Length not found in headers: ' .. header)
                end
                if content_length > CONTENT_LENGTH_MAX then
                    error(
                        string.format(
                            'Content-Length %d exceeds maximum %d; aborting message stream',
                            content_length,
                            CONTENT_LENGTH_MAX
                        )
                    )
                end
                local body_chunks = { buffer:sub(body_start + 1) }
                local body_length = #body_chunks[1]
                while body_length < content_length do
                    local chunk = coroutine.yield()
                        or error('Expected more data for the body. The server may have died.')
                    table.insert(body_chunks, chunk)
                    body_length = body_length + #chunk
                end
                local last_chunk = body_chunks[#body_chunks]
                body_chunks[#body_chunks] = last_chunk:sub(1, content_length - body_length - 1)
                local rest = ''
                if body_length > content_length then
                    rest = last_chunk:sub(content_length - body_length)
                end
                local body = table.concat(body_chunks)
                buffer = rest
                    .. (
                        coroutine.yield(body)
                        or error('Expected more data for the body. The server may have died.')
                    )
            else
                buffer = buffer
                    .. (
                        coroutine.yield()
                        or error('Expected more data for the header. The server may have died.')
                    )
            end
        end
    end
end
--- Parses a chunk of data into separate DAP message chunks
---
--- A DAP message looks like the following:
--- ```
---   Content-Length: 1234\r\n
---   \r\n
---   <1234 bytes of body>
--- ```
---
--- Note that the headers of a DAP message are separated by `\r\n`. This
--- means the chunk may end with `\r\n\r\n` or `\r\n` alone, depending on
--- where it got split up.
---
---@param chunk string
---@param resume_parse fun(chunk?: string): string? resumes the parser; nil once it died
---@param handle_body fun(body: string)
local function handle_chunk(chunk, resume_parse, handle_body)
    while true do
        local body = resume_parse(chunk)
        if body then
            handle_body(body)
            chunk = ''
        else
            break
        end
    end
end

--- Creates a read loop for a debug adapter's stdout/stderr stream.
---
--- The parser runs in a coroutine created with `coroutine.create` (not
--- `coroutine.wrap`) so framing errors -- a missing or absurd
--- `Content-Length`, truncated headers -- surface as resume failures
--- instead of propagating out of the libuv read callback. `on_error` fires
--- once when the stream fails, whether from a framing error or a libuv read
--- error; the parser is dead afterwards and further chunks are ignored.
--- Callers are expected to tear the session down in `on_error`.
---
---@param handle_body fun(body: string) called with each complete message body
---@param on_no_chunk? fun() called when the stream ends (EOF)
---@param on_error? fun(err: string) called once when the stream fails
---@return fun(err?: string, chunk?: string) read callback for `uv.read_start`
function M.create_read_loop(handle_body, on_no_chunk, on_error)
    local parse_chunk = coroutine.create(parse_chunk_loop)
    local parse_failed = false
    local error_fired = false

    ---@param msg string
    local function fire_on_error(msg)
        if error_fired then
            return
        end
        error_fired = true
        if on_error then
            on_error(msg)
        else
            utils.notify(msg, vim.log.levels.ERROR)
        end
    end

    ---@param chunk? string
    ---@return string? body
    local function resume_parse(chunk)
        if parse_failed then
            return nil
        end
        local ok, body = coroutine.resume(parse_chunk, chunk)
        if not ok then
            parse_failed = true
            fire_on_error('DAP message framing error: ' .. tostring(body))
            return nil
        end
        return body
    end

    coroutine.resume(parse_chunk)
    ---@param err? string
    ---@param chunk? string
    return function(err, chunk)
        if err then
            -- A libuv read failure (reset pipe, adapter crash) is fatal to
            -- the stream: report it through the same one-shot on_error path
            -- as framing failures so the session tears down exactly once.
            parse_failed = true
            fire_on_error('DAP stream read error: ' .. tostring(err))
            return
        end
        if not chunk then
            if on_no_chunk then
                on_no_chunk()
            end
            return
        end
        handle_chunk(chunk, resume_parse, handle_body)
    end
end

---@param msg string
---@return string
function M.msg_with_content_length(msg)
    return table.concat({
        'Content-Length: ',
        tostring(#msg),
        '\r\n\r\n',
        msg,
    })
end
return M
