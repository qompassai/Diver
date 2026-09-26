-- /qompassai/Diver/lua/ai/dataaccess/secrets.lua
-- Qompass AI Data Access Secret Hygiene (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- Keeps secrets out of logs, errors, notifications, and socket
-- replies. Three jobs:
--
-- 1. redact(): scrubs userinfo (user:password@host, with '@'
--    allowed inside the password) and secret-bearing assignments
--    (password/passwd/pwd/secret/token/apikey/api_key, quoted,
--    bare, and JSON forms, any case) out of any string before it is
--    logged, shown, or returned over the socket.
-- 2. clean_conn(): validates a connection table and returns a copy
--    holding only recognized fields. A password field is accepted only
--    for adapters whose own module passes it via the subprocess
--    environment (redis); mysql/psql reject bare passwords and want
--    credential files instead, so this layer rejects them too.
-- 3. label()/key_suffix(): the human-readable session label (never
--    contains a secret) and the session-key suffix (a truncated SHA-256
--    of the password, so two different passwords do not share one
--    session, without the secret itself ever entering the key).
--
-- Plain words: passwords travel in files or the environment, never in
-- anything we write down. If a secret shows up where it should not,
-- we refuse the call and scrub the evidence.

local M = {}

local FIELD_BYTES_MAX = 1024
local LABEL_BYTES_MAX = 512
local PASSWORD_BYTES_MAX = 4096
local KEY_HASH_HEX_MAX = 16

-- Key names that are secret-bearing no matter which adapter is used.
local SECRET_KEYS = {
    password = true,
    passwd = true,
    pwd = true,
    secret = true,
    token = true,
    apikey = true,
    api_key = true,
}

-- Connection fields allowed through to the adapter. Everything else is
-- dropped, never forwarded.
local SAFE_FIELDS = {
    host = true,
    port = true,
    user = true,
    username = true,
    database = true,
    dbname = true,
    db = true,
    socket = true,
    tls = true,
    ssl = true,
    service = true,
    defaults_file = true,
    passfile = true,
}

---@param word string lowercase literal word
---@return string pattern matching the word case-insensitively
local function ci_literal(word)
    return (word:gsub('%a', function(c)
        return '[' .. c:lower() .. c:upper() .. ']'
    end))
end

-- Assignment-style key names that are secret-bearing in any adapter's
-- errors or URIs. Checked case-insensitively.
local SECRET_WORDS = { 'password', 'passwd', 'pwd', 'secret', 'token', 'apikey', 'api_key' }

---@param text string
---@return string scrubbed
local function scrub_userinfo(text)
    -- scheme://userinfo@host -> scheme://***@host. The userinfo runs
    -- to the LAST '@' before the first /, ?, or #: passwords may
    -- contain '@' (proven 2026-09-26: mysql://user:p@ss@host/db
    -- scrubbed to mysql://***@ss@host/db).
    return (
        text:gsub('(://)(%S+)', function(prefix, rest)
            -- Pattern, not plain: the authority ends at the first /,
            -- ?, or #. A '?' or '#' inside the authority would mean
            -- the '@' belongs to the query string, not userinfo.
            local delim = rest:find('[/%?#]')
            local authority = (delim ~= nil and rest:sub(1, delim - 1)) or rest
            local tail = (delim ~= nil and rest:sub(delim)) or ''
            local last_at = authority:match('.*()@')
            if last_at == nil then
                return prefix .. rest
            end
            return prefix .. '***@' .. authority:sub(last_at + 1) .. tail
        end)
    )
end

---@param text string
---@return string scrubbed
local function scrub_assignments(text)
    local scrubbed = text
    for _, word in ipairs(SECRET_WORDS) do
        -- %f[%w_] keeps 'secret' from matching inside 'mysecret':
        -- the key must start at a word boundary. The optional closing
        -- quote covers JSON: {"password": "v"}.
        local key = '%f[%w_]' .. ci_literal(word) .. '"?%s*[:=]%s*'
        -- Quoted forms first: the value may contain spaces or
        -- delimiters. Covers key = "v", key = 'v', and JSON "key": "v".
        scrubbed = scrubbed:gsub('(' .. key .. ')"[^"]*"', '%1"***"')
        scrubbed = scrubbed:gsub('(' .. key .. ")'[^']*'", "%1'***'")
        -- Bare values stop at whitespace or common delimiters.
        scrubbed = scrubbed:gsub('(' .. key .. ')[^%s,;\'"}]+', '%1***')
    end
    return scrubbed
end

---Scrub secrets from a string before it is logged, displayed, or sent
---over the socket. Idempotent: already-scrubbed text is unchanged.
---@param text any
---@return string
function M.redact(text)
    if type(text) ~= 'string' then
        return tostring(text)
    end
    return scrub_assignments(scrub_userinfo(text))
end

---@param key string Lowercased already.
---@return boolean
local function is_secret_key(key)
    return SECRET_KEYS[key] == true
end

---@param value any
---@return boolean
local function is_scalar(value)
    local value_type = type(value)
    return value_type == 'string' or value_type == 'number' or value_type == 'boolean'
end

---Validate a connection table and return a copy holding only
---recognized fields. Secret-bearing keys are rejected unless
---allow_password is true (redis), in which case only the exact
---'password' key is kept; every other secret spelling is still
---rejected. The returned table is the only form ever handed to an
---adapter; labels and logs are built from label(), never from this.
---@param conn any Caller-supplied connection table.
---@param allow_password boolean Whether a 'password' field may be kept.
---@return table? clean Copy with only recognized fields.
---@return string? err
function M.clean_conn(conn, allow_password)
    assert(type(allow_password) == 'boolean', 'allow_password must be a boolean')
    if type(conn) ~= 'table' then
        return nil, 'connection must be a table'
    end
    local clean = {}
    for key, value in pairs(conn) do
        if type(key) ~= 'string' then
            return nil, 'connection keys must be strings'
        end
        local lowered = key:lower()
        if is_secret_key(lowered) then
            local is_password = lowered == 'password'
            if not (allow_password and is_password) then
                return nil, "connection must not carry a '" .. key .. "' field; use a credential file"
            end
            if type(value) ~= 'string' or value == '' then
                return nil, 'password must be a non-empty string'
            end
            if #value > PASSWORD_BYTES_MAX then
                return nil, 'password exceeds size bound'
            end
            clean[key] = value
        elseif SAFE_FIELDS[lowered] == true then
            if not is_scalar(value) then
                return nil, "connection field '" .. key .. "' must be a string, number, or boolean"
            end
            if type(value) == 'string' and #value > FIELD_BYTES_MAX then
                return nil, "connection field '" .. key .. "' exceeds size bound"
            end
            -- Control characters are never legitimate in a connection
            -- field: a smuggled newline would ride into session labels
            -- and break line-oriented consumers.
            if type(value) == 'string' and value:find('[%c]') ~= nil then
                return nil, "connection field '" .. key .. "' must not contain control characters"
            end
            clean[key] = value
        end
        -- Unknown non-secret fields are dropped, never forwarded.
    end
    if next(clean) == nil then
        return nil, 'connection carries no recognized fields'
    end
    return clean, nil
end

---Build the human-readable session label from a cleaned connection
---table. Never includes the password: only non-secret fields are
---read, so a secret cannot leak through this function by construction.
---@param adapter_name string
---@param clean table Output of clean_conn.
---@return string label
function M.label(adapter_name, clean)
    assert(type(adapter_name) == 'string', 'adapter_name must be a string')
    assert(type(clean) == 'table', 'clean must be a table')
    local parts = { adapter_name }
    local host = clean.host or clean.socket
    if host ~= nil then
        parts[#parts + 1] = tostring(host)
    end
    if clean.port ~= nil then
        parts[#parts + 1] = tostring(clean.port)
    end
    local database = clean.database or clean.dbname or clean.db
    if database ~= nil then
        parts[#parts + 1] = tostring(database)
    end
    local label_text = table.concat(parts, ':')
    if #label_text > LABEL_BYTES_MAX then
        label_text = label_text:sub(1, LABEL_BYTES_MAX)
    end
    return label_text
end

---Session-key suffix separating sessions that differ only by
---password. A truncated SHA-256 of the password: the secret itself
---never enters the key, and two different passwords never share one.
---Returns '' when no password is present.
---@param clean table Output of clean_conn.
---@return string suffix
function M.key_suffix(clean)
    assert(type(clean) == 'table', 'clean must be a table')
    local password = clean.password
    if type(password) ~= 'string' or password == '' then
        return ''
    end
    local digest = vim.fn.sha256(password)
    assert(type(digest) == 'string' and #digest >= KEY_HASH_HEX_MAX, 'sha256 failed')
    return ':pw:' .. digest:sub(1, KEY_HASH_HEX_MAX)
end

return M
