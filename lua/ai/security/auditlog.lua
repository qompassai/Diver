-- /qompassai/Diver/lua/ai/security/auditlog.lua
-- Append-only invocation log for agent tool calls.
-- Copyright (C) 2026 Qompass AI, All rights reserved.
-- ----------------------------------------
--
-- Plain words: every time an agent (or the dashboard) runs a tool,
-- one line gets appended to a log file: who called what, against
-- which target, and when. The file is only ever appended to, never
-- rewritten, so the trail cannot be quietly edited by the code that
-- writes it. Pentest findings need a clean audit trail; this is ours.
---@module 'ai.security.auditlog'

local M = {}

local LOG_NAME = 'tool-calls.jsonl'
local LINE_MAX = 4096 ---@type integer Max bytes per log line

---@param path string
---@return string? dir
local function dirname(path)
    return path:match('^(.*)/[^/]*$')
end

---@return string path
local function log_path()
    return vim.fn.stdpath('data') .. '/diver/' .. LOG_NAME
end

---Append one invocation record. Never throws: logging must not break
---the tool call it records.
---@param record table { tool: string, target: string?, via: string?, decision: string? }
---@return boolean ok
function M.append(record)
    if type(record) ~= 'table' then
        return false
    end
    local entry = {
        ts = os.time(),
        tool = tostring(record.tool or 'unknown'):sub(1, 128),
        target = tostring(record.target or ''):sub(1, 256),
        via = tostring(record.via or ''):sub(1, 64),
        decision = tostring(record.decision or ''):sub(1, 64),
    }
    local ok, encoded = pcall(vim.json.encode, entry)
    if not ok or type(encoded) ~= 'string' then
        return false
    end
    if #encoded > LINE_MAX then
        encoded = encoded:sub(1, LINE_MAX)
    end
    local path = log_path()
    local dir = dirname(path)
    if dir then
        vim.fn.mkdir(dir, 'p')
    end
    local handle = io.open(path, 'a')
    if handle == nil then
        return false
    end
    handle:write(encoded .. '\n')
    handle:close()
    return true
end

---Path of the log file, for review commands.
---@return string
function M.path()
    return log_path()
end

return M
