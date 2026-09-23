-- Incremental SSE framing with explicit byte/event budgets and CR/LF handling.
-- Copyright (C) 2025 Qompass AI, All rights reserved
local M = {}
local FRAME_BYTES_MAX, EVENTS_MAX = 262144, 4096

function M.new(callback)
    return { buffer = '', data = {}, bytes = 0, count = 0, callback = callback, first = true }
end

local function line(state, value)
    if value == '' then
        if #state.data > 0 then
            state.count = state.count + 1
            if state.count > EVENTS_MAX then
                return nil, 'SSE event limit'
            end
            local ok, err = state.callback(table.concat(state.data, '\n'))
            if not ok then
                return nil, err
            end
        end
        state.data, state.bytes = {}, 0
    elseif value:sub(1, 1) ~= ':' then
        local field, data = value:match('^([^:]*): ?(.*)$')
        field = field or value
        if field == 'data' then
            data = data or ''
            state.bytes = state.bytes + #data + 1
            if state.bytes > FRAME_BYTES_MAX or #state.data >= 4096 then
                return nil, 'SSE frame limit'
            end
            state.data[#state.data + 1] = data
        end
    end
    return true
end

function M.feed(state, chunk)
    state.buffer = state.buffer .. chunk
    if state.first then
        if #state.buffer < 3 then
            return true
        end
        if state.buffer:sub(1, 3) == '\239\187\191' then
            state.buffer = state.buffer:sub(4)
        end
        state.first = false
    end
    if #state.buffer > 8 * 1024 * 1024 then
        return nil, 'SSE input limit'
    end
    for _ = 1, 65536 do
        local first, last = state.buffer:find('[\r\n]')
        if not first then
            if #state.buffer > FRAME_BYTES_MAX then
                return nil, 'SSE line limit'
            end
            return true
        end
        if first > FRAME_BYTES_MAX then
            return nil, 'SSE line limit'
        end
        if state.buffer:sub(first, first) == '\r' then
            if first == #state.buffer then
                return true
            end
            if state.buffer:sub(first + 1, first + 1) == '\n' then
                last = first + 1
            end
        end
        local value = state.buffer:sub(1, first - 1)
        state.buffer = state.buffer:sub(last + 1)
        local ok, err = line(state, value)
        if not ok then
            return nil, err
        end
    end
    return nil, 'SSE line count limit'
end

function M.finish(state)
    -- An incomplete final event must not be mistaken for a delivered event.
    if state.buffer == '\r' then
        state.buffer = ''
        return line(state, '')
    end
    if state.buffer ~= '' or #state.data ~= 0 then
        return nil, 'Truncated SSE event; inspect the remote task before retrying'
    end
    return true
end
return M
