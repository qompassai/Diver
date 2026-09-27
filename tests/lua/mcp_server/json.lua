-- Minimal JSON codec for the MCP server test harness.
-- Loaded only when `vim` is absent (plain Lua 5.4); under Neovim the real
-- vim.json is used instead. Correctness over speed: this is test support.
local json = {}

local function encode_string(s)
    return '"'
        .. s:gsub('[%c\\"]', function(c)
            if c == '"' then
                return '\\"'
            elseif c == '\\' then
                return '\\\\'
            elseif c == '\n' then
                return '\\n'
            elseif c == '\r' then
                return '\\r'
            elseif c == '\t' then
                return '\\t'
            elseif c == '\b' then
                return '\\b'
            elseif c == '\f' then
                return '\\f'
            else
                return string.format('\\u%04x', c:byte())
            end
        end)
        .. '"'
end

local function is_array(t)
    local n = #t
    local count = 0
    for k in pairs(t) do
        if type(k) ~= 'number' or k < 1 or k > n or k % 1 ~= 0 then
            return false
        end
        count = count + 1
    end
    return count == n
end

local function encode_value(v, out)
    local tv = type(v)
    if tv == 'string' then
        out[#out + 1] = encode_string(v)
    elseif tv == 'number' then
        assert(v == v and v ~= math.huge and v ~= -math.huge, 'cannot encode non-finite number')
        out[#out + 1] = tostring(v)
    elseif tv == 'boolean' then
        out[#out + 1] = v and 'true' or 'false'
    elseif tv == 'table' then
        if is_array(v) then
            local parts = {}
            for i = 1, #v do
                encode_value(v[i], parts)
            end
            out[#out + 1] = '[' .. table.concat(parts, ',') .. ']'
        else
            local keys = {}
            for k in pairs(v) do
                keys[#keys + 1] = k
            end
            -- Deterministic output: sorted keys, never pairs() order.
            table.sort(keys, function(a, b)
                return tostring(a) < tostring(b)
            end)
            local parts = {}
            for _, k in ipairs(keys) do
                assert(type(k) == 'string', 'object keys must be strings')
                local sub = {}
                encode_value(v[k], sub)
                parts[#parts + 1] = encode_string(k) .. ':' .. table.concat(sub)
            end
            out[#out + 1] = '{' .. table.concat(parts, ',') .. '}'
        end
    else
        error('cannot encode ' .. tv)
    end
end

function json.encode(v)
    local out = {}
    encode_value(v, out)
    return table.concat(out)
end

local function decode_error(pos, message)
    error('json decode error at byte ' .. pos .. ': ' .. message)
end

function json.decode(s)
    assert(type(s) == 'string', 'json.decode needs a string')
    local pos = 1
    local parse_value -- forward declaration for recursion

    local function skip_ws()
        while pos <= #s and s:sub(pos, pos):match('%s') do
            pos = pos + 1
        end
    end

    local function parse_string()
        pos = pos + 1 -- opening quote
        local parts = {}
        while true do
            if pos > #s then
                decode_error(pos, 'unterminated string')
            end
            local c = s:sub(pos, pos)
            if c == '"' then
                pos = pos + 1
                return table.concat(parts)
            elseif c == '\\' then
                local e = s:sub(pos + 1, pos + 1)
                if e == '"' or e == '\\' or e == '/' then
                    parts[#parts + 1] = e
                    pos = pos + 2
                elseif e == 'n' then
                    parts[#parts + 1] = '\n'
                    pos = pos + 2
                elseif e == 'r' then
                    parts[#parts + 1] = '\r'
                    pos = pos + 2
                elseif e == 't' then
                    parts[#parts + 1] = '\t'
                    pos = pos + 2
                elseif e == 'b' then
                    parts[#parts + 1] = '\b'
                    pos = pos + 2
                elseif e == 'f' then
                    parts[#parts + 1] = '\f'
                    pos = pos + 2
                elseif e == 'u' then
                    local code = tonumber(s:sub(pos + 2, pos + 5), 16)
                    if code == nil then
                        decode_error(pos, 'bad unicode escape')
                    end
                    pos = pos + 6 -- past \uXXXX
                    if code >= 0xD800 and code <= 0xDBFF and s:sub(pos + 1, pos + 2) == '\\u' then
                        local low = tonumber(s:sub(pos + 3, pos + 6), 16)
                        if low ~= nil and low >= 0xDC00 and low <= 0xDFFF then
                            code = 0x10000 + (code - 0xD800) * 0x400 + (low - 0xDC00)
                            pos = pos + 6
                        end
                    end
                    parts[#parts + 1] = utf8.char(code)
                else
                    decode_error(pos, 'bad escape')
                end
            else
                parts[#parts + 1] = c
                pos = pos + 1
            end
        end
    end

    local function parse_number()
        local start = pos
        if s:sub(pos, pos) == '-' then
            pos = pos + 1
        end
        while pos <= #s and s:sub(pos, pos):match('%d') do
            pos = pos + 1
        end
        if s:sub(pos, pos) == '.' then
            pos = pos + 1
            while pos <= #s and s:sub(pos, pos):match('%d') do
                pos = pos + 1
            end
        end
        if s:sub(pos, pos):match('[eE]') then
            pos = pos + 1
            if s:sub(pos, pos):match('[+-]') then
                pos = pos + 1
            end
            while pos <= #s and s:sub(pos, pos):match('%d') do
                pos = pos + 1
            end
        end
        local num = tonumber(s:sub(start, pos - 1))
        if num == nil then
            decode_error(start, 'bad number')
        end
        return num
    end

    local function parse_array()
        pos = pos + 1 -- opening bracket
        local out = {}
        skip_ws()
        if s:sub(pos, pos) == ']' then
            pos = pos + 1
            return out
        end
        while true do
            out[#out + 1] = parse_value()
            skip_ws()
            local c = s:sub(pos, pos)
            if c == ',' then
                pos = pos + 1
            elseif c == ']' then
                pos = pos + 1
                return out
            else
                decode_error(pos, 'expected , or ] in array')
            end
        end
    end

    local function parse_object()
        pos = pos + 1 -- opening brace
        local out = {}
        skip_ws()
        if s:sub(pos, pos) == '}' then
            pos = pos + 1
            return out
        end
        while true do
            skip_ws()
            if s:sub(pos, pos) ~= '"' then
                decode_error(pos, 'expected string key in object')
            end
            local key = parse_string()
            skip_ws()
            if s:sub(pos, pos) ~= ':' then
                decode_error(pos, 'expected : in object')
            end
            pos = pos + 1
            out[key] = parse_value()
            skip_ws()
            local c = s:sub(pos, pos)
            if c == ',' then
                pos = pos + 1
            elseif c == '}' then
                pos = pos + 1
                return out
            else
                decode_error(pos, 'expected , or } in object')
            end
        end
    end

    parse_value = function()
        skip_ws()
        local c = s:sub(pos, pos)
        if c == '"' then
            return parse_string()
        elseif c == '{' then
            return parse_object()
        elseif c == '[' then
            return parse_array()
        elseif c == 't' and s:sub(pos, pos + 3) == 'true' then
            pos = pos + 4
            return true
        elseif c == 'f' and s:sub(pos, pos + 4) == 'false' then
            pos = pos + 5
            return false
        elseif c == 'n' and s:sub(pos, pos + 3) == 'null' then
            pos = pos + 4
            return nil
        elseif c == '-' or c:match('%d') then
            return parse_number()
        else
            decode_error(pos, 'unexpected character')
        end
    end

    local value = parse_value()
    skip_ws()
    if pos <= #s then
        decode_error(pos, 'trailing characters')
    end
    return value
end

return json
