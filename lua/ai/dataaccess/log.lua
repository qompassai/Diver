-- /qompassai/Diver/lua/ai/dataaccess/log.lua
-- Qompass AI Data Access Audit Log (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- Append-only JSONL audit log for the data-access layer: every
-- refused query, every refused result set, every approved write, and
-- every session close lands here as one deterministic JSON line
-- (fixed key order: ts, kind, detail), so an operator can reconstruct
-- exactly what the layer did and when.
--
-- Plain words: this is the layer's diary. Each entry is one line of
-- JSON with a timestamp, a kind ("what happened"), and details. Lines
-- are written with their keys in a fixed order so two identical events
-- always produce byte-identical lines.
--
-- Safety rules, all enforced here rather than trusted from callers:
-- nothing in this file ever throws -- append() returns false instead;
-- no line may exceed LINE_BYTES_MAX (unencodable or oversized details
-- become a small {"truncated":true} marker); the log never grows past
-- LOG_BYTES_MAX (it rotates to a single .1 backup). Secret hygiene is
-- the caller's job: details must already be redacted before append().

local M = {}

local LOG_SUBDIR = 'ai-dataaccess'
local LOG_FILENAME = 'events.jsonl'
local BACKUP_SUFFIX = '.1'
local LOG_DIR_MODE = '0700'
local LOG_BYTES_MAX = 1048576 -- 1 MiB: rotate past this size.
local LINE_BYTES_MAX = 8192 -- Hard cap on one encoded line.
local TAIL_MIN = 1
local TAIL_MAX = 200
local TAIL_WINDOW_BYTES = TAIL_MAX * LINE_BYTES_MAX
local KIND_LENGTH_MAX = 64
local JSON_DEPTH_MAX = 8
local JSON_KEYS_MAX = 512

local log_path = nil ---@type string?
local setup_done = false

---@param kind any
---@return boolean
local function valid_kind(kind)
    return type(kind) == 'string' and #kind >= 1 and #kind <= KIND_LENGTH_MAX and kind:find('%z') == nil
end

---@param value string|number|boolean
---@return string? text
local function encode_scalar(value)
    local ok, text = pcall(vim.json.encode, value)
    if ok and type(text) == 'string' then
        return text
    end
    return nil
end

---@param keys any[]
---@return boolean
local function keys_form_array(keys)
    if #keys == 0 then
        return false
    end
    local max_index = 0
    for _, key in ipairs(keys) do
        if type(key) ~= 'number' or key < 1 or key ~= math.floor(key) then
            return false
        end
        if key > max_index then
            max_index = key
        end
    end
    return max_index == #keys
end

local encode_value ---@type fun(value: any, depth: integer): string?

---@param value table
---@param count integer
---@param depth integer
---@return string? text
local function encode_array(value, count, depth)
    local parts = {}
    for index = 1, count do
        local encoded = encode_value(value[index], depth + 1)
        if encoded == nil then
            return nil
        end
        parts[index] = encoded
    end
    return '[' .. table.concat(parts, ',') .. ']'
end

---@param value table
---@param keys any[]
---@param depth integer
---@return string? text
local function encode_object(value, keys, depth)
    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)
    local parts = {}
    local seen = {}
    for _, key in ipairs(keys) do
        local encoded_key = encode_scalar(tostring(key))
        local encoded_value = encode_value(value[key], depth + 1)
        if encoded_key == nil or encoded_value == nil or seen[encoded_key] then
            return nil
        end
        seen[encoded_key] = true
        parts[#parts + 1] = encoded_key .. ':' .. encoded_value
    end
    return '{' .. table.concat(parts, ',') .. '}'
end

---Deterministic JSON encoder: sorted object keys, bounded depth and
---key count; functions, userdata, and threads are unencodable.
---@param value any
---@param depth integer
---@return string? text Nil when the value has no bounded JSON form.
encode_value = function(value, depth)
    if depth > JSON_DEPTH_MAX then
        return nil
    end
    local value_type = type(value)
    if value_type == 'string' or value_type == 'number' or value_type == 'boolean' then
        return encode_scalar(value)
    end
    if value_type ~= 'table' then
        return nil
    end
    local keys = {}
    local key_count = 0
    for key in pairs(value) do
        key_count = key_count + 1
        if key_count > JSON_KEYS_MAX then
            return nil
        end
        keys[key_count] = key
    end
    if keys_form_array(keys) then
        return encode_array(value, key_count, depth)
    end
    return encode_object(value, keys, depth)
end

---@param kind string
---@param encoded_detail string
---@return string? line
local function encode_event(kind, encoded_detail)
    local encoded_kind = encode_scalar(kind)
    if encoded_kind == nil then
        return nil
    end
    return ('{"ts":%d,"kind":%s,"detail":%s}'):format(os.time(), encoded_kind, encoded_detail)
end

---@param kind string
---@param reason string
---@return string? line
local function encode_marker(kind, reason)
    local encoded_reason = encode_scalar(reason) or '"unknown"'
    return encode_event(kind, '{"truncated":true,"reason":' .. encoded_reason .. '}')
end

---@param path string
---@return boolean ok
local function maybe_rotate(path)
    local stat = vim.uv.fs_stat(path)
    if stat == nil or stat.size == nil then
        return true
    end
    if stat.size < LOG_BYTES_MAX then
        return true
    end
    os.remove(path .. BACKUP_SUFFIX)
    return os.rename(path, path .. BACKUP_SUFFIX) ~= nil
end

---@param path string
---@param line string
---@return boolean ok
local function write_line(path, line)
    local file = io.open(path, 'a')
    if file == nil then
        return false
    end
    local write_ok = file:write(line, '\n')
    local close_ok = file:close()
    return write_ok == true and close_ok == true
end

---Ensure a directory exists with owner-only permissions, tightening
---pre-existing directories: vim.fn.mkdir() applies the mode only when
---it creates the directory, so a loose pre-existing log dir would
---otherwise keep its permissions while the log claims 0700.
---@param dir string
---@return boolean ok
local function ensure_private_dir(dir)
    local mkdir_ok, made = pcall(vim.fn.mkdir, dir, 'p', LOG_DIR_MODE)
    if not mkdir_ok or made ~= 1 then
        return false
    end
    local stat = vim.uv.fs_stat(dir)
    if stat == nil or stat.type ~= 'directory' then
        return false
    end
    -- stat.mode is st_mode: mask to permission bits, tighten when any
    -- group/other bit is set. 448 is 0o700.
    local perms = (stat.mode or 511) % 512
    if perms % 64 ~= 0 then
        -- pcall only guards Lua errors: fs_chmod returns nil+err on
        -- failure without throwing, so both results must be checked.
        local pcall_ok, chmod_ok = pcall(vim.uv.fs_chmod, dir, 448)
        if not pcall_ok or not chmod_ok then
            return false
        end
    end
    return true
end

---Ensure the log directory exists with mode 0700. Idempotent.
---@return boolean ok
function M.setup()
    if setup_done then
        return true
    end
    local dir = vim.fn.stdpath('data') .. '/' .. LOG_SUBDIR
    if not ensure_private_dir(dir) then
        return false
    end
    log_path = dir .. '/' .. LOG_FILENAME
    setup_done = true
    return true
end

---Append one event. Never throws; bad input returns false, unencodable
---or oversized details become a marker line, and a failed rotation
---refuses the write so the log cannot grow without bound.
---@param kind string Event kind, 1..64 bytes, no NUL.
---@param detail table Event detail; keys sorted when encoded.
---@return boolean ok
function M.append(kind, detail)
    if not valid_kind(kind) then
        return false
    end
    if type(detail) ~= 'table' then
        return false
    end
    if not setup_done and not M.setup() then
        return false
    end
    assert(log_path ~= nil, 'setup succeeded but log_path is nil')
    local path = log_path
    local encoded_detail = encode_value(detail, 0)
    local line
    if encoded_detail == nil then
        line = encode_marker(kind, 'unencodable detail')
    else
        line = encode_event(kind, encoded_detail)
    end
    if line == nil or #line > LINE_BYTES_MAX then
        line = encode_marker(kind, 'line exceeded LINE_BYTES_MAX')
    end
    if line == nil or #line > LINE_BYTES_MAX then
        return false
    end
    if not maybe_rotate(path) then
        return false
    end
    return write_line(path, line)
end

---@param n any
---@return integer count Clamped to TAIL_MIN..TAIL_MAX.
local function clamp_tail(n)
    if type(n) ~= 'number' or n ~= n then
        return TAIL_MIN
    end
    local count = math.floor(n)
    if count < TAIL_MIN then
        return TAIL_MIN
    end
    if count > TAIL_MAX then
        return TAIL_MAX
    end
    return count
end

---Return the last n lines of the log, oldest first. n is clamped to
---1..200; lines are raw JSON text, not decoded.
---@param n integer Desired line count.
---@return string[] lines
function M.tail(n)
    local count = clamp_tail(n)
    local path = M.path()
    local file = io.open(path, 'r')
    if file == nil then
        return {}
    end
    local size = file:seek('end')
    if size == nil then
        file:close()
        return {}
    end
    local start = 0
    if size > TAIL_WINDOW_BYTES then
        start = size - TAIL_WINDOW_BYTES
    end
    if file:seek('set', start) == nil then
        file:close()
        return {}
    end
    local chunk = file:read('*a')
    file:close()
    if chunk == nil or chunk == '' then
        return {}
    end
    if start > 0 then
        local first_newline = chunk:find('\n', 1, true)
        if first_newline ~= nil then
            chunk = chunk:sub(first_newline + 1)
        end
    end
    local lines = {}
    local line_start = 1
    while true do
        local newline = chunk:find('\n', line_start, true)
        if newline == nil then
            local rest = chunk:sub(line_start)
            if rest ~= '' then
                lines[#lines + 1] = rest
            end
            break
        end
        lines[#lines + 1] = chunk:sub(line_start, newline - 1)
        line_start = newline + 1
    end
    local total = #lines
    if total <= count then
        return lines
    end
    local kept = {}
    for index = total - count + 1, total do
        kept[#kept + 1] = lines[index]
    end
    return kept
end

---Return the log file path, attempting setup best-effort first.
---@return string path
function M.path()
    M.setup()
    if log_path ~= nil then
        return log_path
    end
    return vim.fn.stdpath('data') .. '/' .. LOG_SUBDIR .. '/' .. LOG_FILENAME
end

return M
