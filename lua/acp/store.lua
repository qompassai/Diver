-- /qompassai/Diver/lua/acp/store.lua
-- Qompass AI ACP Transcript Persistence (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local fs = vim.fs
local M = {}
local DB_PATH = fs.joinpath(vim.fn.stdpath('data'), 'acp', 'transcripts.db')
local MESSAGE_BYTES_MAX = 1 * 1024 * 1024
local QUERY_TIMEOUT_MS = 5000

local SCHEMA = [[
CREATE TABLE IF NOT EXISTS messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_key TEXT NOT NULL,
    agent_name TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'tool')),
    content TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);
CREATE INDEX IF NOT EXISTS idx_messages_session ON messages(session_key);
]]

local initialized = false

local function ensure_dir()
    local dir = assert(fs.dirname(DB_PATH), 'DB_PATH has no parent directory')
    vim.fn.mkdir(dir, 'p', '700')
end

---@param sql string
---@return boolean ok
---@return string? output_or_error
local function run(sql)
    if vim.fn.executable('sqlite3') ~= 1 then
        return false, 'sqlite3 is not on $PATH'
    end
    ensure_dir()
    local ok, result = pcall(vim.system, { 'sqlite3', DB_PATH }, {
        stdin = sql,
        timeout = QUERY_TIMEOUT_MS,
    })
    if not ok then
        return false, tostring(result)
    end
    local completed = result:wait(QUERY_TIMEOUT_MS + 500)
    if completed.code ~= 0 then
        return false, tostring(completed.stderr)
    end
    return true, completed.stdout
end

local function ensure_schema()
    if initialized then
        return
    end
    local ok, err = run(SCHEMA)
    assert(ok, err)
    initialized = true
end

---@param value string
---@return string
local function sql_quote(value)
    assert(type(value) == 'string', 'sql_quote requires a string')
    return "'" .. value:gsub("'", "''") .. "'"
end

---@param session_key string
---@param agent_name string
---@param role 'user'|'assistant'|'tool'
---@param content string
function M.append(session_key, agent_name, role, content)
    assert(role == 'user' or role == 'assistant' or role == 'tool', 'Invalid message role')
    assert(#content <= MESSAGE_BYTES_MAX, 'ACP message exceeds store size bound')
    ensure_schema()

    local sql = string.format(
        'INSERT INTO messages (session_key, agent_name, role, content) VALUES (%s, %s, %s, %s);',
        sql_quote(session_key),
        sql_quote(agent_name),
        sql_quote(role),
        sql_quote(content)
    )
    local ok, err = run(sql)
    if not ok then
        vim.notify('ACP transcript write failed: ' .. tostring(err), vim.log.levels.WARN)
    end
end

---@param session_key string
---@return { role: string, content: string, created_at: string }[]
function M.history(session_key)
    ensure_schema()
    local sql = string.format(
        "SELECT role || '\x1f' || content || '\x1f' || created_at FROM messages "
            .. 'WHERE session_key = %s ORDER BY id ASC;',
        sql_quote(session_key)
    )
    local ok, output = run(sql)
    if not ok or type(output) ~= 'string' then
        return {}
    end

    local rows = {}
    for line in output:gmatch('[^\n]+') do
        local role, content, created_at = line:match('^([^\x1f]*)\x1f([^\x1f]*)\x1f([^\x1f]*)$')
        if role and content and created_at then
            rows[#rows + 1] = { role = role, content = content, created_at = created_at }
        end
    end
    return rows
end

return M
