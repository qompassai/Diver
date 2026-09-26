-- /qompassai/Diver/lua/ai/dataaccess/confirm.lua
-- Qompass AI Data Access Write Confirmation (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- Reads run free; writes need the operator's explicit say-so. A write
-- is any statement whose first keyword is not in the read set below.
--
-- Two confirmation paths share one token store:
--
--   Lua API (:DataQuery): confirm_write() prompts the operator through
--   ai.security.confirm_tool_call and, on approval, hands back a
--   single-use token the query then consumes.
--
--   Socket API: a write query without a token is refused with
--   'confirmation required' plus a fresh token. The coordinator (or
--   the operator) calls the socket 'confirm' op, which raises the same
--   ai.security prompt; on approval the token is marked approved and
--   the coordinator retries the query consuming it.
--
-- Tokens are single-use, expire after five minutes, and at most 32 may
-- be pending. Headless Neovim has no UI, so ai.security default-denies
-- there -- writes simply cannot be approved without an operator.
--
-- Plain words: reading is free, changing data needs a grown-up to say
-- yes. The yes comes as a one-time ticket that expires quickly, so a
-- stolen or forgotten ticket is useless.

local M = {}

local TOKEN_TTL_SECONDS = 300
local TOKEN_COUNT_MAX = 32
local TOKEN_BYTES = 16

-- SQL first keywords that read without changing data. Anything else --
-- INSERT, UPDATE, DELETE, DDL, PRAGMAs that write, ATTACH, and friends
-- -- is a write and needs confirmation.
local SQL_READ_KEYWORDS = {
    SELECT = true,
    WITH = true,
    EXPLAIN = true,
    PRAGMA = true,
    SHOW = true,
    DESCRIBE = true,
    DESC = true,
    VALUES = true,
    TABLE = true,
}

-- Redis commands that read without changing data.
local REDIS_READ_COMMANDS = {
    GET = true,
    HGET = true,
    HGETALL = true,
    HMGET = true,
    HKEYS = true,
    HVALS = true,
    HLEN = true,
    LRANGE = true,
    LLEN = true,
    LINDEX = true,
    SMEMBERS = true,
    SCARD = true,
    SISMEMBER = true,
    ZRANGE = true,
    ZCARD = true,
    ZSCORE = true,
    ZRANK = true,
    TYPE = true,
    TTL = true,
    PTTL = true,
    EXISTS = true,
    HEXISTS = true,
    STRLEN = true,
    GETRANGE = true,
    MGET = true,
    KEYS = true,
    SCAN = true,
    HSCAN = true,
    SSCAN = true,
    ZSCAN = true,
    INFO = true,
    DBSIZE = true,
    PING = true,
    ECHO = true,
}

---@class ConfirmToken
---@field token string Hex token.
---@field approved boolean Operator approved through the prompt.
---@field denied boolean Operator denied through the prompt.
---@field created_at integer os.time() at issuance.
---@field label string Secret-free session label, for the prompt.
---@field preview string Bounded preview of the write text.

local pending = {} ---@type table<string, ConfirmToken>
local token_counter = 0 ---@type integer

-- Test hook: replaces ai.security.confirm_tool_call in headless tests.
---@type fun(server: string, tool: string, args: table, cb: fun(ok: boolean, reason: string))?
M._confirmer = nil

---@param text string
---@return string keyword Uppercase first word, '' when none.
local function first_keyword(text)
    local word = text:match('^%s*%(*%s*([A-Za-z]+)')
    if word == nil then
        return ''
    end
    return word:upper()
end

-- Data-modifying words that make a WITH...CTE a write.
local MODIFYING_WORDS = { 'INSERT', 'UPDATE', 'DELETE', 'REPLACE', 'MERGE' }

-- PRAGMA introspection forms that provably only read: a bare setting
-- name, or a table-valued pragma with a single identifier argument (a
-- table/index name). Everything else -- notably any '=' assignment --
-- may change the database and needs confirmation.
local PRAGMA_READ_ARGS = {
    table_info = true,
    table_xinfo = true,
    index_list = true,
    index_info = true,
    index_xinfo = true,
    foreign_key_list = true,
}

---Strip SQL comments and quoted regions (replaced by one space so
---words cannot join across a removed region). One bounded pass:
---'--' to end of line, '/*' ... '*/', '...' with '' escape, "..."
---with "" escape.
---@param text string
---@return string stripped
local function strip_sql_noise(text)
    local out = {}
    local i = 1
    local n = #text
    while i <= n do
        local c = text:sub(i, i)
        local two = text:sub(i, i + 1)
        if two == '--' then
            local eol = text:find('\n', i + 2, true)
            i = (eol ~= nil and eol + 1) or (n + 1)
        elseif two == '/*' then
            local close = text:find('*/', i + 2, true)
            i = (close ~= nil and close + 2) or (n + 1)
        elseif c == "'" or c == '"' then
            local j = i + 1
            while j <= n do
                if text:sub(j, j) == c then
                    if text:sub(j + 1, j + 1) == c then
                        j = j + 2
                    else
                        break
                    end
                else
                    j = j + 1
                end
            end
            out[#out + 1] = ' '
            i = j + 1
        else
            out[#out + 1] = c
            i = i + 1
        end
    end
    return table.concat(out)
end

---Whole-word search on uppercased stripped text. Frontier patterns
---stop 'DELETE' matching inside 'deleted_at'.
---@param upper string uppercased stripped text
---@param word string uppercase word
---@return boolean found
local function has_word(upper, word)
    return upper:find('%f[%w]' .. word .. '%f[^%w]') ~= nil
end

---Decide whether a PRAGMA body can change the database. Fail-closed:
---unknown shapes are writes.
---@param stripped string noise-stripped full PRAGMA text
---@return boolean is_write
local function pragma_writes(stripped)
    local body = stripped:match('^[Pp][Rr][Aa][Gg][Mm][Aa]%s*(.-)%s*;?%s*$')
    if body == nil or body == '' then
        return true
    end
    -- Every write-pragma assigns with '='; no read-pragma uses '='.
    if body:find('=', 1, true) ~= nil then
        return true
    end
    -- name(arg): read only for known introspection pragmas with a
    -- single bare identifier argument (schema-qualified names allowed).
    local name, arg = body:match('^([%w_%.]+)%s*%(%s*([%w_]+)%s*%)$')
    if name ~= nil then
        local short = name:match('%.([%w_]+)$') or name
        if arg ~= nil and PRAGMA_READ_ARGS[short:lower()] then
            return false
        end
        return true
    end
    -- Bare 'PRAGMA name;' only reads the setting.
    if body:match('^[%w_%.]+$') ~= nil then
        return false
    end
    return true
end

---Decide whether adapter text changes data. Unknown or empty text is
---a write: failing closed is safer than guessing "read".
---
---The first keyword is only the start: a read-looking keyword can
---hide a write (writable CTEs, EXPLAIN ANALYZE, write-PRAGMAs, or a
---second statement after ';'), so read-keywords get a second pass
---over the text with comments and quoted regions stripped.
---@param adapter_name string
---@param text string SQL or command text.
---@return boolean is_write
function M.is_write(adapter_name, text)
    assert(type(adapter_name) == 'string', 'adapter_name must be a string')
    if type(text) ~= 'string' or text:match('^%s*$') ~= nil then
        return true
    end
    local keyword = first_keyword(text)
    if adapter_name == 'redis' then
        -- One Redis command is one line: embedded CR/LF is pipelining
        -- or protocol injection, never a legitimate read.
        if text:find('[\r\n]') ~= nil then
            return true
        end
        return REDIS_READ_COMMANDS[keyword] ~= true
    end
    if SQL_READ_KEYWORDS[keyword] ~= true then
        return true
    end
    local stripped = strip_sql_noise(text)
    -- A second statement hiding behind the first keyword.
    local semi = stripped:find(';', 1, true)
    if semi ~= nil and stripped:sub(semi + 1):find('%S') ~= nil then
        return true
    end
    local upper = stripped:upper()
    if keyword == 'WITH' then
        -- Writable CTEs: WITH d AS (DELETE ...) SELECT ... modifies
        -- data in PostgreSQL even though it starts with WITH.
        for _, word in ipairs(MODIFYING_WORDS) do
            if has_word(upper, word) then
                return true
            end
        end
        -- SELECT ... INTO inside the CTE body or the final select
        -- creates a table (PostgreSQL): still a write.
        return has_word(upper, 'INTO')
    end
    if keyword == 'SELECT' then
        -- SELECT ... INTO new_table creates a table (PostgreSQL).
        return has_word(upper, 'INTO')
    end
    if keyword == 'EXPLAIN' then
        -- EXPLAIN ANALYZE executes the statement (PostgreSQL).
        return has_word(upper, 'ANALYZE')
    end
    if keyword == 'PRAGMA' then
        return pragma_writes(stripped)
    end
    return false
end

---@return string token Hex token, unique per call.
local function mint_token()
    token_counter = token_counter + 1
    local file = io.open('/dev/urandom', 'rb')
    local bytes = nil
    if file ~= nil then
        bytes = file:read(TOKEN_BYTES)
        file:close()
    end
    if type(bytes) ~= 'string' or #bytes ~= TOKEN_BYTES then
        bytes = tostring(os.time()) .. ':' .. tostring(token_counter)
    end
    local hex = {}
    for index = 1, #bytes do
        hex[index] = ('%02x'):format(bytes:byte(index))
    end
    return table.concat(hex)
end

local function prune_expired()
    local now = os.time()
    for token, entry in pairs(pending) do
        if now - entry.created_at > TOKEN_TTL_SECONDS then
            pending[token] = nil
        end
    end
end

---@return integer count
local function pending_count()
    local count = 0
    for _ in pairs(pending) do
        count = count + 1
    end
    return count
end

---Issue a single-use confirmation token for a write. The caller still
---needs the operator's approval before consuming it.
---@param label string Secret-free session label, for the prompt.
---@param text_preview string Bounded preview of the write text.
---@return string? token
---@return string? err
function M.issue(label, text_preview)
    assert(type(label) == 'string', 'label must be a string')
    assert(type(text_preview) == 'string', 'text_preview must be a string')
    prune_expired()
    if pending_count() >= TOKEN_COUNT_MAX then
        return nil, 'too many pending confirmations'
    end
    local token = mint_token()
    pending[token] = {
        token = token,
        approved = false,
        denied = false,
        created_at = os.time(),
        label = label,
        preview = text_preview,
    }
    return token, nil
end

---@param token string
---@return ConfirmToken? entry
local function live_entry(token)
    local entry = pending[token]
    if entry == nil then
        return nil
    end
    if os.time() - entry.created_at > TOKEN_TTL_SECONDS then
        pending[token] = nil
        return nil
    end
    return entry
end

---Prompt the operator through ai.security's confirmation flow. On
---approval the token is marked approved (still single-use: consuming
---it forgets it); on denial it is marked denied. The callback always
---runs, with ok=false when no UI is attached or security is missing.
---@param token string Token from issue().
---@param label string Secret-free session label.
---@param text_preview string Bounded preview of the write text.
---@param callback fun(ok: boolean, reason: string)
function M.prompt(token, label, text_preview, callback)
    assert(type(token) == 'string', 'token must be a string')
    assert(type(label) == 'string', 'label must be a string')
    assert(type(text_preview) == 'string', 'text_preview must be a string')
    assert(type(callback) == 'function', 'callback must be a function')
    local entry = live_entry(token)
    if entry == nil then
        callback(false, 'unknown or expired confirmation token')
        return
    end
    local args = {
        session = label,
        statement_preview = text_preview,
    }
    local function on_choice(allowed, reason)
        local live = live_entry(token)
        if live == nil then
            callback(false, 'confirmation token expired during prompt')
            return
        end
        if allowed then
            live.approved = true
            callback(true, reason)
        else
            live.denied = true
            callback(false, reason)
        end
    end
    if M._confirmer ~= nil then
        -- Same fail-closed contract as the real confirmer below: a
        -- raising hook denies instead of wedging the caller.
        local hook_ok, hook_err = pcall(M._confirmer, 'dataaccess', 'query_write', args, on_choice)
        if not hook_ok then
            entry.denied = true
            callback(false, 'confirmation raised: ' .. tostring(hook_err))
        end
        return
    end
    local ok, security = pcall(require, 'ai.security')
    if not ok or type(security) ~= 'table' or type(security.confirm_tool_call) ~= 'function' then
        entry.denied = true
        callback(false, 'security subsystem unavailable: write denied (fail closed)')
        return
    end
    -- The confirmer must never be able to wedge the callback contract:
    -- a synchronous raise becomes a denial, not a hung execute().
    local call_ok, call_err = pcall(security.confirm_tool_call, 'dataaccess', 'query_write', args, on_choice)
    if not call_ok then
        entry.denied = true
        callback(false, 'confirmation raised: ' .. tostring(call_err))
    end
end

---Consume a token: single-use, forgotten on any outcome. Returns
---'approved' only for a live token the operator approved.
---@param token string
---@return 'approved'|'denied'|'missing'|'expired' state
function M.consume(token)
    if type(token) ~= 'string' or token == '' then
        return 'missing'
    end
    local entry = pending[token]
    if entry == nil then
        return 'missing'
    end
    pending[token] = nil
    if os.time() - entry.created_at > TOKEN_TTL_SECONDS then
        return 'expired'
    end
    if entry.approved then
        return 'approved'
    end
    return 'denied'
end

---Look up a live token's label and preview without consuming it.
---Used by the socket 'confirm' op to raise the operator prompt.
---@param token string
---@return string? label
---@return string? preview
function M.describe(token)
    if type(token) ~= 'string' or token == '' then
        return nil, nil
    end
    local entry = live_entry(token)
    if entry == nil then
        return nil, nil
    end
    return entry.label, entry.preview
end

---Forget all pending tokens. Used in tests; operators never call it.
function M.reset()
    for token in pairs(pending) do
        pending[token] = nil
    end
end

return M
