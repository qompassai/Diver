-- /qompassai/diver/lua/ai/harness/telemetry.lua
-- Qompass AI Agent Harness: redacted telemetry (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Logs, metrics, and traces with redaction. Secret-bearing keys are
-- scrubbed before storage: credentials stay out of prompts, logs, and
-- persisted transcripts. Prompt/completion content is never captured
-- unless the caller explicitly passes it in fields.

local M = {}

local ENTRIES_MAX = 10000
local REDACT_DEPTH_MAX = 8
local REDACTED = '[REDACTED]'

---Key fragments that mark a value as secret. Matched case-insensitively
---against the full key name.
M.REDACT_KEYS = {
    'token',
    'secret',
    'password',
    'passwd',
    'api_key',
    'apikey',
    'credential',
    'authorization',
    'private_key',
}

---@param key string
---@return boolean
local function is_secret_key(key)
    local lower = key:lower()
    for _, fragment in ipairs(M.REDACT_KEYS) do
        if lower:find(fragment, 1, true) ~= nil then
            return true
        end
    end
    return false
end

---Redact secret values in a table. Iterative work-list: no recursion over
---attacker-controlled depth, cycle-safe via a seen set.
---@param value any
---@return any
function M.redact(value)
    if type(value) ~= 'table' then
        return value
    end
    local seen = {}
    local root = {}
    seen[value] = root
    local stack = { { src = value, dst = root, depth = 0 } }
    while #stack > 0 do
        local frame = stack[#stack]
        stack[#stack] = nil
        if frame.depth < REDACT_DEPTH_MAX then
            for k, v in pairs(frame.src) do
                if type(k) == 'string' and is_secret_key(k) then
                    frame.dst[k] = REDACTED
                elseif type(v) == 'table' then
                    if seen[v] ~= nil then
                        frame.dst[k] = '[CYCLE]'
                    else
                        local child = {}
                        seen[v] = child
                        frame.dst[k] = child
                        stack[#stack + 1] = { src = v, dst = child, depth = frame.depth + 1 }
                    end
                else
                    frame.dst[k] = v
                end
            end
        end
    end
    return root
end

---Create a telemetry collector.
---@return table
function M.new()
    return { entries = {}, counters = {} }
end

---@param telemetry table
---@param level 'debug'|'info'|'warn'|'error'
---@param fields table
---@return boolean ok
---@return string? err
function M.log(telemetry, level, fields)
    assert(telemetry ~= nil, 'telemetry required')
    if level ~= 'debug' and level ~= 'info' and level ~= 'warn' and level ~= 'error' then
        return nil, 'unknown log level: ' .. tostring(level)
    end
    if type(fields) ~= 'table' then
        return nil, 'log fields must be a table'
    end
    if #telemetry.entries >= ENTRIES_MAX then
        return nil, 'telemetry log is full'
    end
    telemetry.entries[#telemetry.entries + 1] = {
        level = level,
        fields = M.redact(fields),
    }
    return true
end

---@param telemetry table
---@param metric string
---@param amount? number
function M.incr(telemetry, metric, amount)
    assert(telemetry ~= nil, 'telemetry required')
    assert(type(metric) == 'string' and metric ~= '', 'metric name required')
    amount = amount or 1
    assert(type(amount) == 'number', 'amount must be a number')
    telemetry.counters[metric] = (telemetry.counters[metric] or 0) + amount
end

---@param telemetry table
---@param metric string
---@return number
function M.counter(telemetry, metric)
    assert(telemetry ~= nil, 'telemetry required')
    return telemetry.counters[metric] or 0
end

return M
