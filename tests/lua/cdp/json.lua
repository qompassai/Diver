-- tests/lua/cdp/json.lua
-- Minimal strict JSON decoder (plus a small encoder) for the plain-Lua
-- CDP test harness. Test-only; product code uses vim.json.
---@module 'tests.cdp.json'

local M = {}

local Parser = {}
Parser.__index = Parser

---@param text string
---@return table
function Parser.new(text)
    return setmetatable({ s = text, pos = 1 }, Parser)
end

function Parser:fail(msg)
    error('at byte ' .. tostring(self.pos) .. ': ' .. msg, 0)
end

function Parser:skip_ws()
    while self.pos <= #self.s do
        local c = self.s:sub(self.pos, self.pos)
        if c ~= ' ' and c ~= '\t' and c ~= '\n' and c ~= '\r' then
            break
        end
        self.pos = self.pos + 1
    end
end

function Parser:peek()
    return self.s:sub(self.pos, self.pos)
end

local ESCAPES = {
    ['"'] = '"',
    ['\\'] = '\\',
    ['/'] = '/',
    b = '\b',
    f = '\f',
    n = '\n',
    r = '\r',
    t = '\t',
}

function Parser:parse_string()
    if self:peek() ~= '"' then
        self:fail('expected string')
    end
    self.pos = self.pos + 1
    local parts = {}
    while true do
        if self.pos > #self.s then
            self:fail('unterminated string')
        end
        local c = self:peek()
        if c == '"' then
            self.pos = self.pos + 1
            return table.concat(parts)
        end
        if c == '\\' then
            self.pos = self.pos + 1
            local e = self:peek()
            if e == 'u' then
                local hex = self.s:sub(self.pos + 1, self.pos + 4)
                local code = tonumber(hex, 16)
                if code == nil then
                    self:fail('bad \\u escape')
                end
                parts[#parts + 1] = string.char(code)
                self.pos = self.pos + 5
            else
                local rep = ESCAPES[e]
                if rep == nil then
                    self:fail('bad escape \\' .. e)
                end
                parts[#parts + 1] = rep
                self.pos = self.pos + 1
            end
        else
            parts[#parts + 1] = c
            self.pos = self.pos + 1
        end
    end
end

function Parser:parse_number()
    local start = self.pos
    local num = self.s:match('^-?%d+%.?%d*[eE]?[+-]?%d*', self.pos)
    if num == nil or num == '' or num == '-' then
        self:fail('bad number')
    end
    self.pos = start + #num
    local value = tonumber(num)
    if value == nil then
        self:fail('bad number')
    end
    return value
end

function Parser:parse_literal()
    for _, lit in ipairs({ 'true', 'false', 'null' }) do
        if self.s:sub(self.pos, self.pos + #lit - 1) == lit then
            self.pos = self.pos + #lit
            if lit == 'true' then
                return true
            elseif lit == 'false' then
                return false
            end
            return nil
        end
    end
    self:fail('bad literal')
end

function Parser:parse_array()
    self.pos = self.pos + 1 -- [
    local out = {}
    self:skip_ws()
    if self:peek() == ']' then
        self.pos = self.pos + 1
        return out
    end
    while true do
        out[#out + 1] = self:parse_value()
        self:skip_ws()
        local c = self:peek()
        if c == ',' then
            self.pos = self.pos + 1
        elseif c == ']' then
            self.pos = self.pos + 1
            return out
        else
            self:fail('expected , or ] in array')
        end
    end
end

function Parser:parse_object()
    self.pos = self.pos + 1 -- {
    local out = {}
    self:skip_ws()
    if self:peek() == '}' then
        self.pos = self.pos + 1
        return out
    end
    while true do
        self:skip_ws()
        local key = self:parse_string()
        self:skip_ws()
        if self:peek() ~= ':' then
            self:fail('expected : in object')
        end
        self.pos = self.pos + 1
        out[key] = self:parse_value()
        self:skip_ws()
        local c = self:peek()
        if c == ',' then
            self.pos = self.pos + 1
        elseif c == '}' then
            self.pos = self.pos + 1
            return out
        else
            self:fail('expected , or } in object')
        end
    end
end

function Parser:parse_value()
    self:skip_ws()
    local c = self:peek()
    if c == '"' then
        return self:parse_string()
    elseif c == '{' then
        return self:parse_object()
    elseif c == '[' then
        return self:parse_array()
    elseif c == '-' or c:match('%d') then
        return self:parse_number()
    elseif c == '' then
        self:fail('unexpected end of input')
    else
        return self:parse_literal()
    end
end

---Decode JSON. Returns value or nil plus an error string; never raises.
---@param text string
---@return any
---@return string|nil err
function M.decode(text)
    if type(text) ~= 'string' then
        return nil, 'input must be a string'
    end
    local parser = Parser.new(text)
    local ok, value = pcall(Parser.parse_value, parser)
    if not ok then
        return nil, tostring(value)
    end
    parser:skip_ws()
    if parser.pos <= #text then
        return nil, 'trailing characters at byte ' .. tostring(parser.pos)
    end
    return value
end

local function encode_string(s)
    return '"'
        .. s:gsub('[%z\1-\31\\"]', function(c)
            local known = { ['\n'] = 'n', ['\r'] = 'r', ['\t'] = 't', ['\\'] = '\\', ['"'] = '"' }
            if known[c] then
                return '\\' .. known[c]
            end
            return string.format('\\u%04x', string.byte(c))
        end)
        .. '"'
end

---Encode a value. Tables encode as arrays when all keys are 1..n.
---@param value any
---@return string
function M.encode(value)
    local kind = type(value)
    if kind == 'string' then
        return encode_string(value)
    elseif kind == 'number' or kind == 'boolean' then
        return tostring(value)
    elseif value == nil then
        return 'null'
    elseif kind == 'table' then
        local is_array = true
        local n = 0
        for k, _ in pairs(value) do
            n = n + 1
            if type(k) ~= 'number' or k ~= n then
                is_array = false
            end
        end
        -- Sort object keys for deterministic output.
        local keys = {}
        for k, _ in pairs(value) do
            keys[#keys + 1] = k
        end
        table.sort(keys, function(a, b)
            return tostring(a) < tostring(b)
        end)
        local parts = {}
        if is_array then
            for i = 1, n do
                parts[#parts + 1] = M.encode(value[i])
            end
            return '[' .. table.concat(parts, ',') .. ']'
        end
        for _, k in ipairs(keys) do
            parts[#parts + 1] = encode_string(tostring(k)) .. ':' .. M.encode(value[k])
        end
        return '{' .. table.concat(parts, ',') .. '}'
    end
    error('cannot encode ' .. kind, 0)
end

return M
