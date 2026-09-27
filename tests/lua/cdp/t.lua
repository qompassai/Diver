-- tests/lua/cdp/t.lua
-- Tiny assertion helpers for the plain-Lua CDP test harness.
---@module 'tests.cdp.t'

local M = {}

---@param cond boolean
---@param message string
function M.ok(cond, message)
    if not cond then
        error('assertion failed: ' .. tostring(message), 2)
    end
end

---@param a any
---@param b any
---@param message string
function M.eq(a, b, message)
    if a ~= b then
        local detail = ' (got ' .. tostring(a) .. ', want ' .. tostring(b) .. ')'
        error('assertion failed: ' .. tostring(message) .. detail, 2)
    end
end

---@param value any
---@param message string
function M.is_nil(value, message)
    M.ok(value == nil, (message or 'expected nil') .. ' (got ' .. tostring(value) .. ')')
end

---@param value any
---@param message string
function M.not_nil(value, message)
    M.ok(value ~= nil, message or 'expected non-nil')
end

---@param err string|nil
---@param fragment string
---@param message string
function M.err_match(err, fragment, message)
    local matched = type(err) == 'string' and err:find(fragment, 1, true) ~= nil
    local want = ' (got ' .. tostring(err) .. ', want fragment ' .. fragment .. ')'
    M.ok(matched, (message or 'error mismatch') .. want)
end

return M
