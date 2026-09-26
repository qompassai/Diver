-- /qompassai/Diver/lua/websocket/frame.lua
-- Shared WebSocket (RFC 6455) framing for the native websocket modules.
-- Copyright (C) 2026 Qompass AI, All rights reserved.
-- ----------------------------------------
--
-- Plain words: both the client and the server speak WebSocket by
-- wrapping messages in small binary envelopes called frames. This
-- module builds those envelopes, takes them apart again, and
-- computes the handshake keys. It is pure Lua with no vim
-- dependency except vim.base64, so the framing stays testable.
---@module 'websocket.frame'

local bit = require('bit')

local band = bit.band
local bor = bit.bor
local bxor = bit.bxor
local bnot = bit.bnot
local lshift = bit.lshift
local rshift = bit.rshift
local rol = bit.rol

local M = {}

local MASK32 = 0xFFFFFFFF
local WS_GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'

M.OPCODE_TEXT = 0x1
M.OPCODE_BINARY = 0x2
M.OPCODE_CLOSE = 0x8
M.OPCODE_PING = 0x9
M.OPCODE_PONG = 0xA

---Largest inbound buffer the decoder will hold (1 MiB). Bounds memory
---against a peer that sends endless partial frames.
M.MAX_BUFFER = 1024 * 1024

---Compute the SHA-1 digest of a string (FIPS 180-4).
---Pure Lua on top of LuaJIT's bit library; exact for inputs under 2^29 bytes.
---@param message string
---@return string digest 20 raw bytes
function M.sha1(message)
    local h0, h1, h2, h3, h4 = 0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0

    local ml = #message
    local total_bits = ml * 8
    local len_bytes = string.char(
        0,
        0,
        0,
        0,
        math.floor(total_bits / 16777216) % 256,
        math.floor(total_bits / 65536) % 256,
        math.floor(total_bits / 256) % 256,
        total_bits % 256
    )
    local padded = message .. '\128'
    padded = padded .. string.rep('\0', (56 - (#padded % 64)) % 64) .. len_bytes

    for chunk_start = 1, #padded, 64 do
        local w = {}
        for i = 0, 15 do
            local p = chunk_start + i * 4
            local b0, b1, b2, b3 = padded:byte(p, p + 3)
            w[i] = bor(lshift(b0, 24), lshift(b1, 16), lshift(b2, 8), b3)
        end
        for i = 16, 79 do
            w[i] = rol(bxor(w[i - 3], w[i - 8], w[i - 14], w[i - 16]), 1)
        end
        local a, b, c, d, e = h0, h1, h2, h3, h4
        for i = 0, 79 do
            local f, k
            if i < 20 then
                f = bor(band(b, c), band(bnot(b), d))
                k = 0x5A827999
            elseif i < 40 then
                f = bxor(b, c, d)
                k = 0x6ED9EBA1
            elseif i < 60 then
                f = bor(band(b, c), band(b, d), band(c, d))
                k = 0x8F1BBCDC
            else
                f = bxor(b, c, d)
                k = 0xCA62C1D6
            end
            local temp = band(rol(a, 5) + f + e + k + w[i], MASK32)
            e = d
            d = c
            c = rol(b, 30)
            b = a
            a = temp
        end
        h0 = band(h0 + a, MASK32)
        h1 = band(h1 + b, MASK32)
        h2 = band(h2 + c, MASK32)
        h3 = band(h3 + d, MASK32)
        h4 = band(h4 + e, MASK32)
    end

    local function word(n)
        return string.char(rshift(n, 24) % 256, rshift(n, 16) % 256, rshift(n, 8) % 256, n % 256)
    end
    return word(h0) .. word(h1) .. word(h2) .. word(h3) .. word(h4)
end

---Compute the Sec-WebSocket-Accept value for a client's key.
---@param key string client Sec-WebSocket-Key (base64)
---@return string accept base64 accept key
function M.accept_key(key)
    return vim.base64.encode(M.sha1(key .. WS_GUID))
end

---Build one frame header plus payload. Clients must mask; servers must not.
---@param payload string
---@param opcode integer 0x1 text, 0x2 binary, 0x8 close, 0x9 ping, 0xA pong
---@param masked boolean true for client-to-server frames
---@return string frame bytes
function M.encode(payload, opcode, masked)
    assert(type(payload) == 'string', 'payload must be a string')
    local len = #payload
    local b0 = 0x80 + opcode
    local mask_bit = masked and 0x80 or 0
    local header
    if len < 126 then
        header = string.char(b0, mask_bit + len)
    elseif len < 65536 then
        header = string.char(b0, mask_bit + 126, math.floor(len / 256), len % 256)
    else
        header = string.char(
            b0,
            mask_bit + 127,
            0,
            0,
            0,
            0,
            math.floor(len / 16777216) % 256,
            math.floor(len / 65536) % 256,
            math.floor(len / 256) % 256,
            len % 256
        )
    end
    if not masked then
        return header .. payload
    end
    local m0, m1, m2, m3 = math.random(0, 255), math.random(0, 255), math.random(0, 255), math.random(0, 255)
    local parts = {}
    for i = 1, len do
        local slot = (i - 1) % 4
        local mb = slot == 0 and m0 or (slot == 1 and m1 or (slot == 2 and m2 or m3))
        parts[i] = string.char(bxor(payload:byte(i), mb))
    end
    return header .. string.char(m0, m1, m2, m3) .. table.concat(parts)
end

---Encode a text message as one frame.
---@param text string
---@param masked boolean
---@return string
function M.encode_text(text, masked)
    return M.encode(text, M.OPCODE_TEXT, masked)
end

---Parse an HTTP header block into a table keyed by lowercase header
---name. The request/status line is skipped; values keep their
---original case (base64 values are case-sensitive).
---@param header string raw header block
---@return table<string, string> headers
function M.parse_headers(header)
    local out = {}
    local first = true
    for line in header:gmatch('[^\r\n]+') do
        if first then
            first = false
        else
            local name, value = line:match('^([^:]+):%s*(.-)%s*$')
            if name ~= nil then
                out[name:lower()] = value
            end
        end
    end
    return out
end

local Decoder = {}
Decoder.__index = Decoder
M.Decoder = Decoder

---Create an incremental frame decoder.
---@return table decoder
function Decoder.new()
    return setmetatable({ buf = '', fragments = nil, frag_opcode = nil }, Decoder)
end

---Parse one frame header from the buffer.
---Returns nil when the buffer holds an incomplete header, or a table
---{fin, opcode, masked, length, header_len, mask}.
---@param buf string
---@return table? header
local function parse_header(buf)
    if #buf < 2 then
        return nil
    end
    local b0, b1 = buf:byte(1, 2)
    local fin = b0 >= 0x80
    local opcode = b0 % 16
    local masked = b1 >= 0x80
    local length = b1 % 128
    local pos = 3
    if length == 126 then
        if #buf < 4 then
            return nil
        end
        local e0, e1 = buf:byte(3, 4)
        length = e0 * 256 + e1
        pos = 5
    elseif length == 127 then
        if #buf < 10 then
            return nil
        end
        length = 0
        for i = 3, 10 do
            length = length * 256 + buf:byte(i)
        end
        pos = 11
    end
    local mask = nil
    if masked then
        if #buf < pos + 3 then
            return nil
        end
        mask = { buf:byte(pos, pos + 3) }
        pos = pos + 4
    end
    if #buf < pos - 1 + length then
        return nil
    end
    return { fin = fin, opcode = opcode, masked = masked, length = length, header_len = pos - 1, mask = mask }
end

---Unmask a payload with a 4-byte mask table.
---@param payload string
---@param mask integer[]
---@return string
local function unmask(payload, mask)
    local parts = {}
    for i = 1, #payload do
        parts[i] = string.char(bxor(payload:byte(i), mask[(i - 1) % 4 + 1]))
    end
    return table.concat(parts)
end

---Try to parse and consume one frame. Returns nil when the buffer is
---incomplete, or an event {opcode=..., payload=...}.
---@return table? event
function Decoder:try_parse_one()
    local h = parse_header(self.buf)
    if h == nil then
        return nil
    end
    local payload = self.buf:sub(h.header_len + 1, h.header_len + h.length)
    self.buf = self.buf:sub(h.header_len + h.length + 1)
    if h.masked then
        payload = unmask(payload, h.mask)
    end
    if h.opcode >= 0x8 then
        return { opcode = h.opcode, payload = payload }
    end
    if h.opcode == 0x0 then
        assert(self.fragments ~= nil, 'continuation without fragmented message')
        table.insert(self.fragments, payload)
    else
        assert(self.fragments == nil, 'new data frame before fragmented message finished')
        self.fragments = { payload }
        self.frag_opcode = h.opcode
    end
    if not h.fin then
        return nil
    end
    local message = table.concat(self.fragments)
    local opcode = self.frag_opcode
    self.fragments = nil
    self.frag_opcode = nil
    return { opcode = opcode, payload = message }
end

---Feed received bytes. Returns (events, nil) or (nil, err). Events are
---{opcode=..., payload=...} tables in arrival order.
---@param chunk string
---@return table? events
---@return string? err
function Decoder:feed(chunk)
    self.buf = self.buf .. chunk
    if #self.buf > M.MAX_BUFFER then
        return nil, 'inbound buffer exceeded bound'
    end
    local events = {}
    while true do
        local event = self:try_parse_one()
        if event == nil then
            break
        end
        events[#events + 1] = event
    end
    return events, nil
end

return M
