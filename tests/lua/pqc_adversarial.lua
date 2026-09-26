-- pqc_adversarial.lua — try to break the token/PQC/bridge code.
-- Run: nvim --headless --clean --cmd "set rtp+=." -l tests/lua/pqc_adversarial.lua
-- XDG_DATA_HOME is isolated so the real keystore is never touched.

vim.env.XDG_DATA_HOME = vim.fn.tempname() .. '-adv-xdg'

local failures = {}
local count = 0

local function check(cond, name)
    count = count + 1
    if not cond then
        failures[#failures + 1] = name
        print('FAIL: ' .. name)
    end
end

local pqc = require('ai.security.pqc')
local token = require('ai.security.token')

-- 1. Wrong-key tokens -------------------------------------------------
local key_a = assert(pqc.sig_keygen('classic'))
token.generate('classic', 'adv-a')
token.set_active('adv-a')
local ta = assert(token.mint('bridge', 600))
-- Forge: same payload shape, signed by a different key. Swap the active key
-- to B and mint there, then restore A: B's token must fail under A.
token.generate('classic', 'adv-b')
token.set_active('adv-b')
local tb = assert(token.mint('bridge', 600))
token.set_active('adv-a')
local okb, errb = token.verify(tb)
check(not okb and errb == 'bad signature', 'token from another key rejected')

-- Splice B's signature onto A's payload: must fail.
local pa = ta:match('^[^.]+%.([^.]+)%.[^.]+$')
local sb = tb:match('^[^.]+%.[^.]+%.([^.]+)$')
local spliced = 'v1.' .. pa .. '.' .. sb
local oks, errs = token.verify(spliced)
check(not oks and errs == 'bad signature', 'spliced signature rejected')

-- 2. Malformed tokens -------------------------------------------------
for _, bad in ipairs({
    '',
    'v1',
    'v1..',
    'v1.a.b.c',
    'v2.' .. pa .. '.' .. sb,
    'v1.' .. pa .. '.',
    'v1.' .. ('A'):rep(100000) .. '.' .. sb, -- huge payload segment
    'v1.*.b',
}) do
    local okm = token.verify(bad)
    check(not okm, 'malformed rejected: ' .. bad:sub(1, 20))
end
check(not token.verify(123), 'number token rejected')
check(not token.verify(nil), 'nil token rejected')
check(not token.verify({}), 'table token rejected')

-- Claims type confusion: exp as string.
local function b64u(s)
    return vim.base64.encode(s):gsub('+', '-'):gsub('/', '_'):gsub('=+$', '')
end
local evil_payload = b64u(vim.json.encode({ v = 1, jti = 'x', scope = 'bridge', iat = 1, exp = 'never' }))
local esig = b64u(assert(pqc.sig_sign(key_a, 'v1.' .. evil_payload)))
local oke = token.verify('v1.' .. evil_payload .. '.' .. esig)
check(not oke, 'string exp rejected')

-- 3. Revocation edge cases --------------------------------------------
local tr = assert(token.mint('bridge', 600))
local okr = token.verify(tr)
check(okr, 'pre-revoke token valid')
check(token.revoke(tr), 'revoke by token works')
local okr2, errr2 = token.verify(tr)
check(not okr2 and errr2 == 'token revoked', 'revoked token rejected')
local okr3, errr3 = token.verify(tr, 'bridge')
check(not okr3 and errr3 == 'token revoked', 'revoked token rejected with scope')
local okg, errg = token.revoke('definitely-not-a-token-or-jti!')
check(not okg and errg ~= nil, 'revoke garbage rejected')
local okj = token.revoke(('ab'):rep(16))
check(okj, 'revoke raw hex jti accepted')

-- 4. PQC misuse --------------------------------------------------------
for _, strength in ipairs({ 'classic', 'hybrid', 'quantum' }) do
    local k = assert(pqc.sig_keygen(strength))
    local other = assert(pqc.sig_keygen(strength))
    local msg = 'adversarial message'
    local sig = assert(pqc.sig_sign(k, msg))
    check(pqc.sig_verify(k, msg, sig), strength .. ' self-verify')
    check(not pqc.sig_verify(other, msg, sig), strength .. ' wrong-key verify fails')
    check(not pqc.sig_verify(k, msg .. 'x', sig), strength .. ' tampered msg fails')
    check(not pqc.sig_verify(k, msg, sig:sub(1, #sig - 1)), strength .. ' truncated sig fails')
    check(not pqc.sig_verify(k, msg, ''), strength .. ' empty sig fails')
    -- Corrupt key material must error/false, never crash.
    local badk = { strength = strength, public = 'AAAA', secret = 'AAAA' }
    local okc = pcall(pqc.sig_verify, badk, msg, sig)
    check(okc, strength .. ' corrupt key does not crash')
end

-- KEM misuse: wrong-length ct, tampered ct, nil material.
for _, strength in ipairs({ 'classic', 'hybrid', 'quantum' }) do
    local k = assert(pqc.kem_keygen(strength))
    local out = assert(pqc.kem_encaps(k))
    local eph = out.eph_pub
    local ss = pqc.kem_decaps(k, out.ct, eph)
    check(ss == out.ss, strength .. ' KEM roundtrip')
    local s2, e2 = pqc.kem_decaps(k, 'short', eph)
    check(s2 == nil and e2 ~= nil, strength .. ' short ct errors cleanly')
    local bad = { strength = strength }
    local s3, e3 = pqc.kem_encaps(bad)
    check(s3 == nil and e3 ~= nil, strength .. ' nil public key errors cleanly')
    if strength ~= 'classic' then
        -- Tampered ct: ML-KEM implicit rejection -> different ss, never equal.
        local tct = out.ct:sub(1, 1) == 'A' and 'B' .. out.ct:sub(2) or 'A' .. out.ct:sub(2)
        local s4 = pqc.kem_decaps(k, tct, eph)
        check(s4 ~= out.ss, strength .. ' tampered ct gives different ss')
    end
end

-- 5. Bridge adversarial ------------------------------------------------
local bridge = require('ai.webmcp.bridge')
bridge.start({ port = 17896, require_token = true })
local wc = require('websocket.client')
local adv_token = assert(token.mint('bridge', 600))
local replies = {}
local c = nil
c = wc.WebsocketClient.new({
    connect_addr = 'ws://127.0.0.1:17896',
    on_message = function(_, raw)
        local okd, msg = pcall(vim.json.decode, raw)
        if okd and type(msg) == 'table' then
            if msg.id ~= nil then
                replies[msg.id] = msg
            else
                -- Replies to id-less input (garbage, oversize): no id to echo.
                replies.noid = replies.noid or {}
                replies.noid[#replies.noid + 1] = msg
            end
        end
    end,
    on_connect = function()
        c:try_send_data('this is not json') -- id-less garbage
        c:try_send_data(vim.json.encode({ id = 1, method = 'nope.nothing', params = {} }))
        c:try_send_data(vim.json.encode({ id = 2, method = 'bridge.tools', params = {} }))
        c:try_send_data(vim.json.encode({ id = 3, method = 'bridge.auth', params = { token = 'bogus' } }))
        c:try_send_data(vim.json.encode({ id = 4, method = 'bridge.auth', params = { token = adv_token } }))
        c:try_send_data(vim.json.encode({ id = 5, method = 'bridge.tools', params = {} }))
        c:try_send_data(vim.json.encode({ id = 6, method = 'bridge.ping', params = {} }))
        c:try_send_data(string.rep('x', 65536 + 1)) -- over the size bound
    end,
})
c:try_connect()
vim.wait(8000, function()
    return replies[6] ~= nil
end)
-- id-less replies (garbage input, oversize message) land in replies.noid
local saw_large = false
local saw_garbage = false
for _, m in ipairs(replies.noid or {}) do
    if not m.ok and tostring(m.error):find('too large') then
        saw_large = true
    end
    if not m.ok and tostring(m.error):find('invalid JSON') then
        saw_garbage = true
    end
end
check(saw_garbage, 'non-JSON input rejected')
check(replies[1] ~= nil and not replies[1].ok, 'unknown method rejected')
check(replies[2] ~= nil and not replies[2].ok, 'tools without auth rejected')
check(replies[3] ~= nil and not replies[3].ok, 'bogus token rejected')
check(replies[4] ~= nil and replies[4].ok, 'real token accepted')
check(replies[5] ~= nil and replies[5].ok, 'tools after auth works')
check(replies[6] ~= nil and replies[6].ok, 'ping works')
check(saw_large, 'oversize message rejected')

-- Disconnect clears auth: reconnect must re-authenticate.
local c2replies = {}
local c2 = nil
c2 = wc.WebsocketClient.new({
    connect_addr = 'ws://127.0.0.1:17896',
    on_message = function(_, raw)
        local okd, msg = pcall(vim.json.decode, raw)
        if okd and type(msg) == 'table' and msg.id ~= nil then
            c2replies[msg.id] = msg
        end
    end,
    on_connect = function()
        c2:try_send_data(vim.json.encode({ id = 11, method = 'bridge.tools', params = {} }))
    end,
})
c:try_disconnect()
c2:try_connect()
vim.wait(8000, function()
    return c2replies[11] ~= nil
end)
check(c2replies[11] ~= nil and not c2replies[11].ok, 'fresh connection is not authed')
bridge.stop()

-- 6. Exact limits -------------------------------------------------------
local tt_max = token.mint('bridge', 2592000)
check(tt_max ~= nil, 'ttl=2592000 accepted')
local tt_over = pcall(token.mint, 'bridge', 2592001)
check(not tt_over, 'ttl=2592001 rejected')

print(('adversarial tests: %d passed, %d failed'):format(count - #failures, #failures))
if #failures > 0 then
    print('failures: ' .. table.concat(failures, '; '))
end
vim.cmd('cquit' .. (#failures > 0 and '!' or ''))
