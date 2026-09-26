-- /qompassai/Diver/lua/ai/rose/utils.lua
-- Small shared helpers for the legacy provider classes (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Ports only what ai.rose.provider needs from rose.nvim's utils
-- (filter_payload_parameters, parse_raw_response); only the provider
-- classes use this file. Adds key_from_command, which runs a
-- key-retrieval argv command through vim.system instead of the
-- original io.popen shell string.

local M = {}

local KEY_COMMAND_ARGS_MAX = 32
local KEY_BYTES_MAX = 16384

-- Keep only the provider's documented parameters in the outgoing payload.
-- Nested parameter tables copy the payload's own same-named keys, matching
-- the historical rose.nvim behavior exactly.
---@param valid_parameters table<string, boolean|table>
---@param payload table
---@return table filtered
function M.filter_payload_parameters(valid_parameters, payload)
    assert(type(valid_parameters) == 'table', 'valid_parameters must be a table')
    assert(type(payload) == 'table', 'payload must be a table')
    local new_payload = {}
    for key, value in pairs(valid_parameters) do
        if type(value) == 'table' then
            if new_payload[key] == nil then
                new_payload[key] = {}
            end
            for nested_key, _ in pairs(value) do
                new_payload[key][nested_key] = payload[nested_key]
            end
        else
            new_payload[key] = payload[key]
        end
    end
    return new_payload
end

-- Join raw subprocess output lines into one response string.
---@param response string|string[]|nil
---@return string|nil joined
function M.parse_raw_response(response)
    if response == nil then
        return nil
    end
    if type(response) == 'table' then
        return table.concat(response, ' ')
    end
    return response
end

-- Run a key-retrieval command (the api_key table form) as an explicit argv
-- array via vim.system. Never builds a shell string from the command.
---@param argv string[] key-retrieval argv array
---@return string? key  -- whitespace-stripped key, nil on failure
---@return string? err
function M.key_from_command(argv)
    if type(argv) ~= 'table' or #argv == 0 or #argv > KEY_COMMAND_ARGS_MAX then
        return nil, 'key command must be a non-empty argv array'
    end
    for _, arg in ipairs(argv) do
        if type(arg) ~= 'string' or arg == '' or arg:find('\0', 1, true) then
            return nil, 'key command argv must be non-empty strings without NUL'
        end
    end
    local ok, result = pcall(vim.system, argv, { text = true })
    if not ok then
        return nil, 'key command failed to start: ' .. tostring(result)
    end
    local completed = result:wait()
    if completed.code ~= 0 then
        return nil, 'key command exited ' .. tostring(completed.code)
    end
    local key = (completed.stdout or ''):gsub('%s+', '')
    if key == '' then
        return nil, 'key command returned an empty key'
    end
    if #key > KEY_BYTES_MAX then
        return nil, 'key command returned an overlong key'
    end
    return key, nil
end

return M
