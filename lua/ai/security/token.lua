-- token.lua — Signed capability tokens for the recon bridge.
--
-- What it is: the bridge's authorization. Instead of trusting anything that
-- can open a localhost socket, every client must present a token minted by
-- this module. Tokens are signed with the active PQC/hybrid/classic key, so
-- the bridge verifies them without a lookup: signature + expiry + scope +
-- revocation list.
--
-- Token shape: v1.<base64url(payload)>.<base64url(signature)>
-- payload: { v=1, jti, scope, iat, exp }
--
-- Keystore: stdpath('data')/recon-keys/  (0700 dir, 0600 files)
--   <name>.json  key table from pqc.sig_keygen + { created }
--   active       name of the signing key the bridge trusts
--   revoked.json { jti = exp } — pruned of expired entries on write
--
-- First use auto-generates a classic RSA-4096 key named 'default' so the
-- bridge works out of the box; upgrade with :ReconKeygen hybrid|quantum.

local M = {}

M.DEFAULT_TTL = 86400 -- 24 hours
M.VERSION = 'v1'

---@return string path, creating the keystore dir (0700) when missing
local function keystore_dir()
    local dir = vim.fn.stdpath('data') .. '/recon-keys'
    if vim.fn.isdirectory(dir) ~= 1 then
        vim.fn.mkdir(dir, 'p')
    end
    vim.uv.fs_chmod(dir, 448) -- 0700
    return dir
end

---@param path string
local function write_private(path, text)
    vim.fn.writefile({ text }, path)
    vim.uv.fs_chmod(path, 384) -- 0600
end

---@param s string
---@return string
local function b64u_encode(s)
    return vim.base64.encode(s):gsub('+', '-'):gsub('/', '_'):gsub('=+$', '')
end

---@param s string
---@return string|nil
local function b64u_decode(s)
    if type(s) ~= 'string' or s == '' then
        return nil
    end
    if not s:match('^[A-Za-z0-9%-_]+$') then
        return nil
    end
    local padded = s:gsub('-', '+'):gsub('_', '/')
    local rem = #padded % 4
    if rem == 2 then
        padded = padded .. '=='
    elseif rem == 3 then
        padded = padded .. '='
    elseif rem ~= 0 then
        return nil
    end
    local ok, out = pcall(vim.base64.decode, padded)
    if not ok then
        return nil
    end
    return out
end

---@param bytes string
---@return string hex
local function hex(bytes)
    return (bytes:gsub('.', function(c)
        return ('%02x'):format(c:byte())
    end))
end

---List stored signing keys.
---@return table[] { name, strength, kind, created, active }
function M.list_keys()
    local dir = keystore_dir()
    local active = M.active_name()
    local out = {}
    for name in vim.fs.dir(dir) do
        if name:sub(-5) == '.json' and name ~= 'revoked.json' then
            local keyname = name:sub(1, -6)
            local ok, data = pcall(vim.json.decode, table.concat(vim.fn.readfile(dir .. '/' .. name), '\n'))
            if ok and type(data) == 'table' and type(data.key) == 'table' then
                out[#out + 1] = {
                    name = keyname,
                    strength = data.key.strength,
                    kind = data.key.kind,
                    created = data.created,
                    active = keyname == active,
                }
            end
        end
    end
    table.sort(out, function(a, b)
        return a.name < b.name
    end)
    return out
end

---@return string|nil name of the active signing key
function M.active_name()
    local dir = keystore_dir()
    local p = dir .. '/active'
    if vim.fn.filereadable(p) ~= 1 then
        return nil
    end
    local lines = vim.fn.readfile(p)
    if #lines == 0 or lines[1] == '' then
        return nil
    end
    local name = lines[1]:sub(1, 64)
    -- The active file is hand-editable; never let it become a path.
    if not name:match('^[%w%-]+$') then
        return nil
    end
    return name
end

---@param name string
---@return boolean
function M.set_active(name)
    assert(type(name) == 'string' and name ~= '', 'name required')
    local dir = keystore_dir()
    if vim.fn.filereadable(dir .. '/' .. name .. '.json') ~= 1 then
        return false
    end
    write_private(dir .. '/active', name)
    return true
end

---Generate a signing key at a strength and store it. Also sets it active
---when there is no active key yet.
---@param strength string 'classic' | 'hybrid' | 'quantum'
---@param name string|nil defaults to 'sig-<strength>'
---@return table|nil key, string|nil err
function M.generate(strength, name)
    assert(type(strength) == 'string', 'strength required')
    name = name or ('sig-' .. strength)
    assert(type(name) == 'string' and name:match('^[%w%-]+$'), 'bad key name')
    local pqc = require('ai.security.pqc')
    local key, err = pqc.sig_keygen(strength)
    if key == nil then
        return nil, err
    end
    local dir = keystore_dir()
    write_private(
        dir .. '/' .. name .. '.json',
        vim.json.encode({
            created = os.time(),
            key = key,
        })
    )
    if M.active_name() == nil then
        write_private(dir .. '/active', name)
    end
    return key
end

---Load the active signing key, auto-generating classic RSA-4096 on first use.
---@return table|nil key, string|nil err
function M.active_key()
    local name = M.active_name()
    if name == nil then
        local key, err = M.generate('classic', 'default')
        if key == nil then
            return nil, 'no signing key and auto-generate failed: ' .. tostring(err)
        end
        return key
    end
    local dir = keystore_dir()
    local p = dir .. '/' .. name .. '.json'
    if vim.fn.filereadable(p) ~= 1 then
        return nil, 'active key file missing: ' .. name
    end
    local ok, data = pcall(vim.json.decode, table.concat(vim.fn.readfile(p), '\n'))
    if not ok or type(data) ~= 'table' or type(data.key) ~= 'table' then
        return nil, 'active key file corrupt: ' .. name
    end
    return data.key
end

---Read the revocation list, pruning expired entries.
---@return table revoked { jti = exp }
local function read_revoked()
    local dir = keystore_dir()
    local p = dir .. '/revoked.json'
    local revoked = {}
    if vim.fn.filereadable(p) == 1 then
        local ok, data = pcall(vim.json.decode, table.concat(vim.fn.readfile(p), '\n'))
        if ok and type(data) == 'table' then
            revoked = data
        end
    end
    local now = os.time()
    local dirty = false
    for jti, exp in pairs(revoked) do
        if type(exp) ~= 'number' or exp <= now then
            revoked[jti] = nil
            dirty = true
        end
    end
    if dirty then
        write_private(p, vim.json.encode(revoked))
    end
    return revoked
end

---@param jti string
---@return boolean
function M.is_revoked(jti)
    local revoked = read_revoked()
    return revoked[jti] ~= nil
end

---Revoke a token by its jti (or a full token string).
---@param token_or_jti string
---@return boolean revoked, string|nil err
function M.revoke(token_or_jti)
    assert(type(token_or_jti) == 'string', 'token or jti required')
    local jti = token_or_jti
    local keep_until = os.time() + M.DEFAULT_TTL
    local ok, claims = M.verify(token_or_jti)
    if ok then
        jti = claims.jti
        -- Keep the revocation entry alive as long as the token itself.
        keep_until = claims.exp
    elseif not token_or_jti:match('^[0-9a-f]+$') then
        return false, 'not a token or hex jti'
    end
    local dir = keystore_dir()
    local revoked = read_revoked()
    revoked[jti] = keep_until
    write_private(dir .. '/revoked.json', vim.json.encode(revoked))
    return true
end

---Mint a capability token.
---@param scope string|nil e.g. 'bridge' (default), kept extensible
---@param ttl integer|nil seconds, default 24h, max 30 days
---@return string|nil token, string|nil err
function M.mint(scope, ttl)
    scope = scope or 'bridge'
    ttl = ttl or M.DEFAULT_TTL
    assert(type(scope) == 'string' and scope ~= '', 'scope required')
    assert(type(ttl) == 'number' and ttl > 0 and ttl <= 2592000, 'ttl out of range (1s..30d)')
    local key, err = M.active_key()
    if key == nil then
        return nil, err
    end
    local pqc = require('ai.security.pqc')
    local rand, rerr = pqc.random(16)
    if rand == nil then
        return nil, rerr
    end
    local now = os.time()
    local payload = {
        v = 1,
        jti = hex(rand),
        scope = scope,
        iat = now,
        exp = now + ttl,
    }
    local body = M.VERSION .. '.' .. b64u_encode(vim.json.encode(payload))
    local sig, serr = pqc.sig_sign(key, body)
    if sig == nil then
        return nil, serr
    end
    return body .. '.' .. b64u_encode(sig)
end

---Verify a token: shape, signature, expiry, revocation.
---Signature is checked before revocation so forged tokens cannot probe
---the revocation list.
---@param token string
---@param expected_scope string|nil when set, the token's scope must match
---@return boolean ok, table|string claims|err
function M.verify(token, expected_scope)
    if type(token) ~= 'string' then
        return false, 'token must be a string'
    end
    local ver, p64, s64 = token:match('^([^.]+)%.([^.]+)%.([^.]+)$')
    if ver ~= M.VERSION or p64 == nil or s64 == nil then
        return false, 'malformed token'
    end
    local praw = b64u_decode(p64)
    local sig = b64u_decode(s64)
    if praw == nil or sig == nil then
        return false, 'malformed token encoding'
    end
    local ok, payload = pcall(vim.json.decode, praw)
    if not ok or type(payload) ~= 'table' then
        return false, 'malformed token payload'
    end
    if payload.v ~= 1 or type(payload.jti) ~= 'string' or type(payload.exp) ~= 'number' then
        return false, 'malformed token claims'
    end
    if expected_scope ~= nil and payload.scope ~= expected_scope then
        return false, 'wrong scope'
    end
    local now = os.time()
    if payload.exp <= now then
        return false, 'token expired'
    end
    if type(payload.iat) == 'number' and payload.iat > now + 300 then
        return false, 'token issued in the future'
    end
    local key, err = M.active_key()
    if key == nil then
        return false, err
    end
    local pqc = require('ai.security.pqc')
    if not pqc.sig_verify(key, ver .. '.' .. p64, sig) then
        return false, 'bad signature'
    end
    if M.is_revoked(payload.jti) then
        return false, 'token revoked'
    end
    return true, payload
end

return M
