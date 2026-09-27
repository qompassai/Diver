-- Purpose: shared harness for the BiDi unit tests. Runs under plain
-- Lua 5.4 (no Neovim) with a minimal vim stub, or under `nvim -l`.
-- Provides a small JSON codec (test fixtures only, not shipped), a
-- pass/fail runner that tracks adversarial vs validation splits, and a
-- live-gate helper that skips tests needing a real vim.uv.

local H = {}

local src = debug.getinfo(1, 'S').source:sub(2)
local dir = src:match('^(.*)/[^/]+$')
local root = dir .. '/../../..'
package.path = root .. '/lua/?.lua;' .. root .. '/lua/?/init.lua;' .. package.path

-- ai/websocket/frame.lua needs LuaJIT's `bit` at require time. Under
-- plain Lua 5.4 we shim it with native operators (test-only; the real
-- target is Neovim's LuaJIT, which has bit).
if package.preload['bit'] == nil then
    local ok, _ = pcall(require, 'bit')
    if not ok then
        package.preload['bit'] = function()
            return {
                band = function(a, b)
                    return a & b
                end,
                bor = function(a, b)
                    return a | b
                end,
                bxor = function(a, b)
                    return a ~ b
                end,
                bnot = function(a)
                    return ~a
                end,
                lshift = function(a, n)
                    return a << n
                end,
                rshift = function(a, n)
                    return a >> n
                end,
                rol = function(a, n)
                    n = n % 32
                    return ((a << n) | (a >> (32 - n))) & 0xFFFFFFFF
                end,
            }
        end
    end
end

-- ---------------------------------------------------------------- JSON

local function is_array(t)
    if type(t) ~= 'table' then
        return false
    end
    local n = 0
    for k in pairs(t) do
        if type(k) ~= 'number' then
            return false
        end
        n = n + 1
    end
    return n == #t
end

local function encode_value(v, out)
    local tv = type(v)
    if tv == 'string' then
        out[#out + 1] = string.format('%q', v)
    elseif tv == 'number' then
        assert(v == v and v ~= math.huge and v ~= -math.huge, 'non-finite number')
        out[#out + 1] = tostring(v)
    elseif tv == 'boolean' then
        out[#out + 1] = v and 'true' or 'false'
    elseif tv == 'table' then
        if is_array(v) then
            out[#out + 1] = '['
            for i = 1, #v do
                if i > 1 then
                    out[#out + 1] = ','
                end
                encode_value(v[i], out)
            end
            out[#out + 1] = ']'
        else
            out[#out + 1] = '{'
            local keys = {}
            for k in pairs(v) do
                keys[#keys + 1] = k
            end
            table.sort(keys)
            for i = 1, #keys do
                if i > 1 then
                    out[#out + 1] = ','
                end
                encode_value(keys[i], out)
                out[#out + 1] = ':'
                encode_value(v[keys[i]], out)
            end
            out[#out + 1] = '}'
        end
    else
        error('cannot encode ' .. tv)
    end
end

function H.json_encode(v)
    local out = {}
    encode_value(v, out)
    return table.concat(out)
end

function H.json_decode(text)
    assert(type(text) == 'string', 'json_decode needs a string')
    local pos = 1
    local function skip_ws()
        while pos <= #text and text:sub(pos, pos):match('%s') do
            pos = pos + 1
        end
    end
    local parse_value -- forward
    local function parse_string()
        assert(text:sub(pos, pos) == '"', 'expected string')
        pos = pos + 1
        local out = {}
        while true do
            local c = text:sub(pos, pos)
            if c == '"' then
                pos = pos + 1
                return table.concat(out)
            end
            assert(c ~= '', 'unterminated string')
            if c == '\\' then
                local e = text:sub(pos + 1, pos + 1)
                local map = {
                    ['"'] = '"',
                    ['\\'] = '\\',
                    ['/'] = '/',
                    b = '\b',
                    f = '\f',
                    n = '\n',
                    r = '\r',
                    t = '\t',
                }
                if e == 'u' then
                    local hex = text:sub(pos + 2, pos + 5)
                    local code = tonumber(hex, 16)
                    assert(code, 'bad \\u escape')
                    out[#out + 1] = code < 128 and string.char(code) or '?'
                    pos = pos + 6
                else
                    assert(map[e], 'bad escape')
                    out[#out + 1] = map[e]
                    pos = pos + 2
                end
            else
                out[#out + 1] = c
                pos = pos + 1
            end
        end
    end
    local function parse_number()
        local s = text:match('^-?%d+%.?%d*[eE]?[+-]?%d*', pos)
        assert(s and s ~= '', 'bad number')
        pos = pos + #s
        return tonumber(s)
    end
    local function parse_array()
        pos = pos + 1
        local arr = {}
        skip_ws()
        if text:sub(pos, pos) == ']' then
            pos = pos + 1
            return arr
        end
        while true do
            arr[#arr + 1] = parse_value()
            skip_ws()
            local c = text:sub(pos, pos)
            if c == ']' then
                pos = pos + 1
                return arr
            end
            assert(c == ',', 'expected , or ]')
            pos = pos + 1
        end
    end
    local function parse_object()
        pos = pos + 1
        local obj = {}
        skip_ws()
        if text:sub(pos, pos) == '}' then
            pos = pos + 1
            return obj
        end
        while true do
            skip_ws()
            local k = parse_string()
            skip_ws()
            assert(text:sub(pos, pos) == ':', 'expected :')
            pos = pos + 1
            obj[k] = parse_value()
            skip_ws()
            local c = text:sub(pos, pos)
            if c == '}' then
                pos = pos + 1
                return obj
            end
            assert(c == ',', 'expected , or }')
            pos = pos + 1
        end
    end
    parse_value = function()
        skip_ws()
        local c = text:sub(pos, pos)
        if c == '"' then
            return parse_string()
        end
        if c == '{' then
            return parse_object()
        end
        if c == '[' then
            return parse_array()
        end
        if text:sub(pos, pos + 3) == 'true' then
            pos = pos + 4
            return true
        end
        if text:sub(pos, pos + 4) == 'false' then
            pos = pos + 5
            return false
        end
        if text:sub(pos, pos + 3) == 'null' then
            pos = pos + 4
            return nil
        end
        return parse_number()
    end
    local v = parse_value()
    skip_ws()
    assert(pos > #text, 'trailing garbage in JSON')
    return v
end

-- ---------------------------------------------------------------- runner

---@class HarnessCase
---@field name string
---@field adversarial boolean
---@field fn fun()

local cases = {}

---Register a test case.
---@param name string
---@param adversarial boolean
---@param fn fun()
function H.test(name, adversarial, fn)
    cases[#cases + 1] = { name = name, adversarial = adversarial, fn = fn }
end

---Assert helpers.
function H.eq(a, b, msg)
    if a ~= b then
        error((msg or 'not equal') .. ': ' .. tostring(a) .. ' ~= ' .. tostring(b), 2)
    end
end

function H.is_true(v, msg)
    if v ~= true then
        error((msg or 'expected true') .. ', got ' .. tostring(v), 2)
    end
end

function H.is_nil(v, msg)
    if v ~= nil then
        error((msg or 'expected nil') .. ', got ' .. tostring(v), 2)
    end
end

function H.not_nil(v, msg)
    if v == nil then
        error(msg or 'expected non-nil', 2)
    end
end

function H.matches(s, pattern, msg)
    if type(s) ~= 'string' or not s:find(pattern, 1, true) then
        error((msg or 'pattern not found') .. ' in ' .. tostring(s), 2)
    end
end

---True when running inside real Neovim with a working event loop.
function H.live()
    return _G.vim ~= nil and type(_G.vim) == 'table' and _G.vim.uv ~= nil
end

---Run all registered cases; returns exit code.
---@param suite string
---@return integer
function H.run(suite)
    local pass_adv, fail_adv = 0, 0
    local pass_val, fail_val = 0, 0
    local skipped = 0
    for _, case in ipairs(cases) do
        local ok, err = pcall(case.fn)
        if err == 'SKIP' then
            skipped = skipped + 1
            print(('SKIP  [%s] %s'):format(case.adversarial and 'ADV' or 'VAL', case.name))
        elseif ok then
            if case.adversarial then
                pass_adv = pass_adv + 1
            else
                pass_val = pass_val + 1
            end
        else
            if case.adversarial then
                fail_adv = fail_adv + 1
            else
                fail_val = fail_val + 1
            end
            local tag = case.adversarial and 'ADV' or 'VAL'
            print(('FAIL  [%s] %s\n      %s'):format(tag, case.name, err))
        end
    end
    print(('--- %s: validation %d/%d, adversarial %d/%d, skipped %d'):format(
        suite,
        pass_val,
        pass_val + fail_val,
        pass_adv,
        pass_adv + fail_adv,
        skipped
    ))
    if fail_adv + fail_val > 0 then
        return 1
    end
    return 0
end

return H
