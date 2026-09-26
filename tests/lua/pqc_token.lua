--- PQC + capability-token self-test: keygen, signatures, KEM, tokens,
--- and the bridge auth gate, across classic / hybrid / quantum strengths.
---
--- Plain-language version: proves the crypto actually works — keys generate,
--- signatures verify, tampered data fails, key-exchange round-trips, tokens
--- mint/verify/expire/revoke, and the bridge rejects unauthenticated calls.
--- Runs headless via `nvim -l`; not loaded at startup.
---@module 'tests.pqc_token'

-- #################################################################
-- /qompassai/diver/tests/lua/pqc_token.lua
-- Qompass AI Diver Lua PQC/Token Test
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI

-- Isolate the keystore before anything touches stdpath('data').
vim.env.XDG_DATA_HOME = vim.fn.tempname() .. '-xdg'

local passed = 0
local failures = {}
local function check(ok, name)
    if ok then
        passed = passed + 1
    else
        failures[#failures + 1] = name
        print('FAIL: ' .. name)
    end
end

local pqc = require('ai.security.pqc')

-- 1. Backend ------------------------------------------------------
check(pqc.backend() == 'liboqs+openssl', 'backend is liboqs+openssl, got ' .. pqc.backend())
check(pqc.supports('classic'), 'classic supported')
check(pqc.supports('hybrid'), 'hybrid supported')
check(pqc.supports('quantum'), 'quantum supported')
check(not pqc.supports('bogus'), 'bogus strength rejected')
local nok, nerr = pqc.sig_keygen('bogus')
check(nok == nil and nerr ~= nil, 'sig_keygen rejects bogus strength')

-- 2. Signatures, all strengths ------------------------------------
for _, strength in ipairs({ 'classic', 'hybrid', 'quantum' }) do
    local key, err = pqc.sig_keygen(strength)
    check(key ~= nil, strength .. ' sig keygen works' .. (err and (': ' .. err) or ''))
    if key ~= nil then
        local msg = 'the quick brown fox'
        local sig, serr = pqc.sig_sign(key, msg)
        check(sig ~= nil, strength .. ' sign works' .. (serr and (': ' .. serr) or ''))
        if sig ~= nil then
            check(pqc.sig_verify(key, msg, sig), strength .. ' verify accepts good sig')
            check(not pqc.sig_verify(key, msg .. '!', sig), strength .. ' verify rejects tampered msg')
            -- Flip one byte in the signature.
            local pos = strength == 'hybrid' and 3400 or 10
            local bad = sig:sub(1, pos - 1) .. string.char((sig:byte(pos) + 1) % 256) .. sig:sub(pos + 1)
            check(not pqc.sig_verify(key, msg, bad), strength .. ' verify rejects tampered sig')
            check(not pqc.sig_verify(key, msg, sig:sub(1, #sig - 1)), strength .. ' verify rejects truncated sig')
        end
    end
end

-- 3. KEM round-trips, all strengths -------------------------------
for _, strength in ipairs({ 'classic', 'hybrid', 'quantum' }) do
    local key, err = pqc.kem_keygen(strength)
    check(key ~= nil, strength .. ' KEM keygen works' .. (err and (': ' .. err) or ''))
    if key ~= nil then
        local enc, eerr = pqc.kem_encaps(key)
        check(enc ~= nil, strength .. ' encaps works' .. (eerr and (': ' .. eerr) or ''))
        if enc ~= nil then
            local ss, derr = pqc.kem_decaps(key, enc.ct, enc.eph_pub)
            check(ss ~= nil, strength .. ' decaps works' .. (derr and (': ' .. derr) or ''))
            if ss ~= nil then
                check(ss == enc.ss, strength .. ' shared secrets match')
                check(#ss >= 32, strength .. ' shared secret is >= 32 bytes')
            end
        end
    end
end

-- 4. Tokens --------------------------------------------------------
local token = require('ai.security.token')

local t, terr = token.mint('bridge', 3600)
check(t ~= nil, 'mint works' .. (terr and (': ' .. terr) or ''))

local keys = token.list_keys()
check(#keys >= 1, 'auto-generated default key exists')
check(token.active_name() ~= nil, 'an active key is set')
if t ~= nil then
    check(t:match('^v1%.') ~= nil, 'token has v1 prefix')
    local ok, claims = token.verify(t)
    check(ok, 'verify accepts fresh token')
    if ok then
        check(claims.scope == 'bridge', 'scope claim round-trips')
        check(type(claims.jti) == 'string' and #claims.jti == 32, 'jti is 16 bytes hex')
        check(claims.exp > claims.iat, 'exp is after iat')
    end
    -- Tamper with the payload half.
    local ver, p64, s64 = t:match('^([^.]+)%.([^.]+)%.([^.]+)$')
    local badt = ver .. '.' .. p64:sub(1, -2) .. (p64:sub(-1) == 'A' and 'B' or 'A') .. '.' .. s64
    local ok2, err2 = token.verify(badt)
    check(not ok2, 'verify rejects tampered payload (' .. tostring(err2) .. ')')
    -- Revoke and re-verify.
    local rok = token.revoke(t)
    check(rok, 'revoke works')
    local ok3, err3 = token.verify(t)
    check(not ok3 and tostring(err3) == 'token revoked', 'verify rejects revoked token')
end

local okm = token.verify('garbage')
check(not okm, 'verify rejects garbage')
local okv = token.verify('v9.e30.e30')
check(not okv, 'verify rejects wrong version')

-- Expiry: 1-second token, then wait it out.
local short = assert(token.mint('bridge', 1))
vim.wait(2100)
local oks, errs = token.verify(short)
check(not oks and tostring(errs) == 'token expired', 'verify rejects expired token')

-- 5. Keystore management -------------------------------------------
local gk, gerr = token.generate('quantum', 'test-quantum')
check(gk ~= nil, 'generate quantum key' .. (gerr and (': ' .. gerr) or ''))
if gk ~= nil then
    check(token.set_active('test-quantum'), 'set_active works')
    check(token.active_name() == 'test-quantum', 'active key switched')
    local t2 = assert(token.mint('bridge', 60))
    local okq = token.verify(t2)
    check(okq, 'token verifies under quantum key')
    check(not token.set_active('no-such-key'), 'set_active rejects unknown key')

    -- 5b. Scope enforcement and revocation semantics -------------------
    local twrong = assert(token.mint('other-scope', 60))
    local okscope, errscope = token.verify(twrong, 'bridge')
    check(not okscope and errscope == 'wrong scope', 'wrong scope rejected')
    local oks2 = token.verify(twrong)
    check(oks2, 'no expected scope still verifies')
    local tlong = assert(token.mint('bridge', 1000))
    local okrl, crowns = token.verify(tlong)
    assert(okrl)
    token.revoke(tlong)
    local rev_raw = table.concat(vim.fn.readfile(vim.fn.stdpath('data') .. '/recon-keys/revoked.json'), '\n')
    local rev = vim.json.decode(rev_raw)
    check(rev[crowns.jti] == crowns.exp, 'revocation entry honors token expiry')
    -- active-name traversal is neutralized
    local dir = vim.fn.stdpath('data') .. '/recon-keys'
    vim.fn.writefile({ '../evil' }, dir .. '/active')
    check(token.active_name() == nil, 'traversal in active file rejected')
    vim.fn.writefile({ 'test-quantum' }, dir .. '/active')
end

-- 6. Bridge auth gate ----------------------------------------------
local bridge = require('ai.webmcp.bridge')
local wc = require('websocket.client')
local bt = assert(token.mint('bridge', 300))

-- 6a. Token-required bridge: unauth rejected, auth accepted.
bridge.start({ port = 17897, require_token = true })
local done = false
local rej, authed_ok, tools_ok = false, false, false
local c1 = nil
c1 = wc.WebsocketClient.new({
    connect_addr = 'ws://127.0.0.1:17897',
    on_message = function(_, raw)
        local msg = vim.json.decode(raw)
        if msg.id == 1 then
            rej = not msg.ok
        elseif msg.id == 2 then
            authed_ok = msg.ok == true
        elseif msg.id == 3 then
            tools_ok = msg.ok == true
            done = true
        end
    end,
    on_connect = function()
        c1:try_send_data(vim.json.encode({ id = 1, method = 'bridge.tools', params = {} }))
        c1:try_send_data(vim.json.encode({ id = 2, method = 'bridge.auth', params = { token = bt } }))
        c1:try_send_data(vim.json.encode({ id = 3, method = 'bridge.tools', params = {} }))
    end,
})
c1:try_connect()
vim.wait(5000, function()
    return done
end)
check(done, 'token-gated bridge round-trip finished')
check(rej, 'token-gated bridge rejects unauthenticated call')
check(authed_ok, 'bridge.auth accepts a real token')
check(tools_ok, 'authenticated client can call bridge.tools')
bridge.stop()

-- 6b. Opt-out: require_token=false keeps the old open behavior.
bridge.start({ port = 17896, require_token = false })
local done2 = false
local open_ok = false
local c2 = nil
c2 = wc.WebsocketClient.new({
    connect_addr = 'ws://127.0.0.1:17896',
    on_message = function(_, raw)
        local msg = vim.json.decode(raw)
        if msg.id == 1 then
            open_ok = msg.ok == true
            done2 = true
        end
    end,
    on_connect = function()
        c2:try_send_data(vim.json.encode({ id = 1, method = 'bridge.tools', params = {} }))
    end,
})
c2:try_connect()
vim.wait(5000, function()
    return done2
end)
check(done2, 'opt-out bridge round-trip finished')
check(open_ok, 'require_token=false allows unauthenticated calls')
bridge.stop()
check(not bridge.status().running, 'bridge stopped')

print(('pqc_token tests: %d passed, %d failed'):format(passed, #failures))
if #failures > 0 then
    print('failures: ' .. table.concat(failures, '; '))
    os.exit(1)
end
