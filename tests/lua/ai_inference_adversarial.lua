--- Adversarial inference self-test — tries to break the helpers, locks in the fixes.
---
--- Plain-language version: this is a test script, not a feature. It attacks
--- lua/ai/inference/speculative.lua and kv_policy.lua where the happy-path
--- suite (tests/lua/ai_inference_speculative.lua) does not go: hostile
--- confidence/draft/verify functions, UTF-8 truncation, sparse throughput
--- profiles, IPv6 URLs, detect() under rapid/concurrent/timeout load with
--- file-descriptor accounting, and the rose config speculative wiring. Every
--- regression below was a proven break before its fix. It runs headless via
--- `nvim -l`; it is not loaded at startup.
---@module 'tests.ai_inference_adversarial'
vim.opt.runtimepath:prepend(vim.fn.getcwd())
local count = 0
local function check(value, message)
    assert(value, message)
    count = count + 1
end
local function check_err(err, fragment, message)
    check(type(err) == 'string' and err:find(fragment, 1, true) ~= nil, message .. ' (got: ' .. tostring(err) .. ')')
end

local spec = require('ai.inference.speculative')
local kv = require('ai.inference.kv_policy')

-- IPv6 URLs (was: 'http://::1:8080', malformed) --------------------------------
local cfg6, cfg6_err = spec.draft_config({ draft_model_path = '/models/d.gguf', host = '::1' })
check(cfg6_err == nil and cfg6 ~= nil, 'draft_config accepts the ::1 loopback host')
check(cfg6.server_url == 'http://[::1]:8080', 'IPv6 hosts are bracketed in server_url (got: ' .. cfg6.server_url .. ')')
check(cfg6.server_argv[2] == '::1', 'server_argv keeps the bare IPv6 host that llama.cpp --host expects')
local cfg6e = spec.draft_config({ draft_model_path = '/models/d.gguf', endpoint = { host = '::1', port = 9999 } })
check(cfg6e ~= nil and cfg6e.server_url == 'http://[::1]:9999', 'bracketing also applies via endpoint')
local cfg4 = spec.draft_config({ draft_model_path = '/models/d.gguf', host = '127.0.0.1' })
check(cfg4 ~= nil and cfg4.server_url == 'http://127.0.0.1:8080', 'IPv4 URLs are unchanged')
local cfg_local = spec.draft_config({ draft_model_path = '/models/d.gguf', host = 'localhost' })
check(cfg_local ~= nil and cfg_local.server_url == 'http://localhost:8080', 'hostname URLs are unchanged')

-- UTF-8 truncation (was: byte sub() split codepoints, over-truncated) -----------
local function dv_trunc(draft, cap)
    local stats = spec.new_stats()
    local res, res_err = spec.draft_verify(function()
        return draft, nil
    end, function()
        return 'v', nil
    end, {
        prompt = 'p',
        confidence_fn = function()
            return 1.0
        end,
        max_draft_chars = cap,
        stats = stats,
    })
    return res, res_err, stats
end
-- 'é' is bytes C3 A9: cap 1 must keep the whole character, never half of it.
local r1, e1, s1 = dv_trunc('éx', 1)
check(e1 == nil and r1 == 'é', 'truncation keeps a whole multibyte character (got ' .. #r1 .. ' bytes)')
check(s1.draft_chars == 1, 'draft_chars counts characters, not bytes')
-- 3 chars / 6 bytes with a 4-char cap: no truncation at all.
local r2, e2, s2 = dv_trunc('ééé', 4)
check(e2 == nil and r2 == 'ééé', 'multibyte text under the char cap is not truncated')
check(s2.draft_chars == 3, 'short multibyte drafts count characters')
local r3, _, s3 = dv_trunc('héllo wörld', 5)
check(r3 == 'héllo' and s3.draft_chars == 5, 'truncation cuts on a character boundary')
-- 4-byte codepoint: U+1D11E '𝄞' is F0 9D 84 9E.
local r4, _, s4 = dv_trunc('𝄞abc', 1)
check(r4 == '𝄞' and #r4 == 4 and s4.draft_chars == 1, '4-byte codepoints survive truncation')
-- Stray bytes cannot break the walk: each counts as one character.
local r5, e5, s5 = dv_trunc('a\255b', 2)
check(e5 == nil and r5 == 'a\255' and s5.draft_chars == 2, 'stray bytes are handled gracefully')
local r6, e6, s6 = dv_trunc('', 10)
check(e6 == nil and r6 == '' and s6.draft_chars == 0, 'an empty draft stays empty')
-- ASCII behavior is unchanged (builder-suite compatibility).
local r7, _, s7 = dv_trunc('0123456789', 5)
check(r7 == '01234' and s7.draft_chars == 5, 'ASCII truncation is unchanged')
-- verified_chars counts characters too: 'héllo→wörld' is 11 chars, 14 bytes.
local vstats = spec.new_stats()
local _, verr = spec.draft_verify(function()
    return 'd', nil
end, function()
    return 'héllo→wörld', nil
end, {
    prompt = 'p',
    confidence_fn = function()
        return 0.0
    end,
    stats = vstats,
})
check(
    verr == nil and vstats.verified_chars == 11,
    'verified_chars counts characters (got ' .. vstats.verified_chars .. ')'
)

-- Sparse profiles (was: rows after a hole silently dropped) -----------------------
local hole = {
    [1] = { max_load = 0.9, draft_len = 8, verify_batch = 8 },
    [3] = { max_load = 1.0, draft_len = 2, verify_batch = 2 },
}
local _, hole_err = spec.schedule_for_load(hole, 0.95)
check_err(hole_err, 'dense', 'a profile with a hole is rejected instead of mis-scheduling')
local strkey = { { max_load = 0.5, draft_len = 4, verify_batch = 2 }, name = 'x' }
local _, strkey_err = spec.schedule_for_load(strkey, 0.1)
check_err(strkey_err, 'dense', 'a profile with non-array keys is rejected')
local zerokey = { [0] = { max_load = 0.5, draft_len = 4, verify_batch = 2 } }
local _, zerokey_err = spec.schedule_for_load(zerokey, 0.1)
check_err(zerokey_err, 'dense', 'a profile keyed from 0 is rejected')
local dense = {
    { max_load = 0.5, draft_len = 6, verify_batch = 3 },
    { max_load = 1.0, draft_len = 2, verify_batch = 2 },
}
local dense_choice, dense_err = spec.schedule_for_load(dense, 0.9)
check(dense_err == nil and dense_choice.draft_len == 2, 'dense profiles still schedule normally')
local big = {}
for i = 1, 65 do
    big[i] = { max_load = i / 65, draft_len = 4, verify_batch = 2 }
end
local _, big_err = spec.schedule_for_load(big, 0.1)
check_err(big_err, 'at most', 'profiles over the entry cap are still rejected')

-- draft_verify fuzz: hostile callbacks ------------------------------------------------
local function dv_fuzz(confidence_fn)
    return spec.draft_verify(function()
        return 'd', nil
    end, function()
        return 'v', nil
    end, { prompt = 'p', confidence_fn = confidence_fn, stats = spec.new_stats() })
end
local _, fe1 = dv_fuzz(function()
    return math.huge
end)
check_err(fe1, '0..1', '+inf confidence is rejected')
local _, fe2 = dv_fuzz(function()
    return -math.huge
end)
check_err(fe2, '0..1', '-inf confidence is rejected')
local _, fe3 = dv_fuzz(function()
    return nil
end)
check_err(fe3, '0..1', 'nil confidence is rejected')
local _, fe4 = dv_fuzz(function()
    return true
end)
check_err(fe4, '0..1', 'boolean confidence is rejected')
local _, fe5 = spec.draft_verify(function()
    return nil, nil
end, function()
    return 'v', nil
end, {
    prompt = 'p',
    confidence_fn = function()
        return 1.0
    end,
})
check_err(fe5, 'must return a string', 'draft returning nil with no error is rejected')
-- Both raise: the draft error wins and verify never runs.
local verify_ran = false
local _, fe6 = spec.draft_verify(function()
    error('draft boom')
end, function()
    verify_ran = true
    error('verify boom')
end, {
    prompt = 'p',
    confidence_fn = function()
        return 0.0
    end,
})
check_err(fe6, 'draft_fn raised', 'a raising draft_fn reports the draft error')
check(not verify_ran, 'verify never runs when the draft raises')
local _, fe7 = spec.draft_verify(function()
    return 'd', nil
end, function()
    return 'v', nil
end, {
    prompt = 'p',
    confidence_fn = function()
        return 1.0
    end,
    max_draft_chars = -5,
})
check_err(fe7, 'max_draft_chars', 'a negative draft cap is rejected')
local r_huge, e_huge = spec.draft_verify(function()
    return 'd', nil
end, function()
    return 'v', nil
end, {
    prompt = 'p',
    confidence_fn = function()
        return 1.0
    end,
    max_draft_chars = 2 ^ 40,
})
check(e_huge == nil and r_huge == 'd', 'a huge draft cap is accepted')
-- Re-entrancy: draft_verify inside a confidence_fn completes cleanly.
local inner_ok = false
local r_re, e_re = spec.draft_verify(function()
    return 'outer draft', nil
end, function()
    return 'v', nil
end, {
    prompt = 'p',
    confidence_fn = function(draft)
        local ir, ierr = spec.draft_verify(function()
            return 'inner ' .. draft, nil
        end, function()
            return 'iv', nil
        end, {
            prompt = 'p2',
            confidence_fn = function()
                return 1.0
            end,
            stats = spec.new_stats(),
        })
        inner_ok = ir == 'inner outer draft' and ierr == nil
        return 1.0
    end,
    stats = spec.new_stats(),
})
check(e_re == nil and r_re == 'outer draft' and inner_ok, 're-entrant draft_verify works')
-- Exactly-once stats when verify_fn raises: the attempt is counted once.
local raise_stats = spec.new_stats()
local _, re_err = spec.draft_verify(function()
    return 'd', nil
end, function()
    error('verify boom')
end, {
    prompt = 'p',
    confidence_fn = function()
        return 0.0
    end,
    stats = raise_stats,
})
check_err(re_err, 'raised', 'a raising verify_fn becomes an error')
check(raise_stats.verify_calls == 1 and raise_stats.verified_chars == 0, 'failed verify is counted exactly once')

-- detect() under load ------------------------------------------------------------------
local function accept_all(server)
    server:listen(128, function(listen_err)
        if listen_err then
            return
        end
        local client = vim.uv.new_tcp()
        if client ~= nil then
            if server:accept(client) ~= 0 then
                client:close()
            else
                client:close()
            end
        end
    end)
end
local stub = assert(vim.uv.new_tcp())
assert(stub:bind('127.0.0.1', 0))
accept_all(stub)
local stub_port = stub:getsockname().port
local function detect_sync(opts)
    local done, derr, dep, calls = false, nil, nil, 0
    spec.detect(opts, function(a, b)
        calls = calls + 1
        derr, dep, done = a, b, true
    end)
    local finished = vim.wait(5000, function()
        return done
    end, 10)
    check(finished, 'detect callback fires')
    check(calls == 1, 'detect callback fires exactly once')
    return derr, dep
end
local function fd_count()
    local n = 0
    local ok, iter = pcall(vim.fs.dir, '/proc/self/fd')
    if not ok then
        return nil
    end
    for _ in iter do
        n = n + 1
    end
    return n
end
local fds_before = fd_count()
for _ = 1, 30 do
    local derr = detect_sync({ host = '127.0.0.1', port = stub_port, timeout_ms = 1000 })
    check(derr == nil, 'rapid detect succeeds (err: ' .. tostring(derr) .. ')')
end
local fds_after = fd_count()
if fds_before ~= nil and fds_after ~= nil then
    check(fds_after == fds_before, ('no fd leak over 30 detects (before=%d after=%d)'):format(fds_before, fds_after))
else
    check(true, 'fd accounting skipped: /proc/self/fd unavailable')
end
-- Concurrent burst: every callback fires exactly once.
local burst_fired = 0
for _ = 1, 10 do
    spec.detect({ host = '127.0.0.1', port = stub_port, timeout_ms = 1000 }, function()
        burst_fired = burst_fired + 1
    end)
end
local burst_done = vim.wait(5000, function()
    return burst_fired == 10
end, 10)
check(burst_done and burst_fired == 10, 'concurrent burst: all 10 callbacks fire exactly once')
-- Validation failures also fire exactly once, on the main loop.
local verr_closed = detect_sync({ port = stub_port + 1 })
check_err(verr_closed, 'no server', 'detect reports a refused port')
local verr_port = detect_sync({ port = 0 })
check_err(verr_port, 'port', 'detect rejects port 0 with exactly one callback')
stub:close()
-- Slow-loris: accepts connections, never responds. The probe only checks
-- that something listens, so this succeeds by documented contract.
local loris = assert(vim.uv.new_tcp())
assert(loris:bind('127.0.0.1', 0))
accept_all(loris)
local loris_port = loris:getsockname().port
local loris_err, loris_ep = detect_sync({ host = '127.0.0.1', port = loris_port, timeout_ms = 1000 })
check(loris_err == nil and loris_ep ~= nil, 'slow-loris server still proves "something listens"')
loris:close()
-- IPv6 loopback probe, skipped gracefully when unavailable.
local srv6 = vim.uv.new_tcp()
if srv6 ~= nil then
    local bound = pcall(function()
        assert(srv6:bind('::1', 0))
    end)
    if bound then
        accept_all(srv6)
        local p6 = srv6:getsockname().port
        local e_v6, ep_v6 = detect_sync({ host = '::1', port = p6, timeout_ms = 1000 })
        check(e_v6 == nil and ep_v6 ~= nil and ep_v6.host == '::1', 'detect probes ::1')
        srv6:close()
    else
        srv6:close()
        check(true, 'detect ::1 skipped: IPv6 unavailable in this environment')
    end
else
    check(true, 'detect ::1 skipped: cannot allocate TCP handle')
end
-- Watchdog: unroutable host times out with exactly one callback.
local watchdog_calls = 0
spec.detect({ host = '10.255.255.1', port = 8080, timeout_ms = 200, allow_remote = true }, function()
    watchdog_calls = watchdog_calls + 1
end)
local watchdog_done = vim.wait(5000, function()
    return watchdog_calls == 1
end, 10)
check(watchdog_done, 'watchdog fires exactly once on an unroutable host')
vim.wait(300, function()
    return false
end, 10)
check(watchdog_calls == 1, 'no late second callback after the watchdog')

-- kv_policy: hostile inputs, determinism ------------------------------------------------
local mt_viol = kv.validate(setmetatable({}, { __index = { kv_bits = 2 } }))
check(#mt_viol == 1 and mt_viol[1]:find('global_kv', 1, true) ~= nil, 'metatable-provided bits are judged')
local nan_viol = kv.validate({ kv_bits = 0 / 0 })
check(#nan_viol == 1 and nan_viol[1]:find('kv_bits', 1, true) ~= nil, 'NaN bits are a violation, not a crash')
local inf_viol = kv.validate({ kv_bits = math.huge })
check(#inf_viol == 1, 'infinite bits are rejected as non-integer')
local neg_viol = kv.validate({ kv_bits = -3 })
check(#neg_viol == 1, 'negative bits are a violation')
local rope_num = kv.validate({ rope_order = 42 })
check(#rope_num == 1 and rope_num[1]:find('rope_order', 1, true) ~= nil, 'a numeric rope_order is a violation')
local extra_ok, extra_err = kv.validate({ kv_bits = 4, unknown_field = { nested = true }, rope_order = 'after' })
check(extra_err == nil and #extra_ok == 0, 'extra unknown fields are ignored')
local nested_viol = kv.validate({ kv_bits = {} })
check(#nested_viol == 1 and nested_viol[1]:find('kv_bits', 1, true) ~= nil, 'a table-valued bits field is a violation')
-- Deterministic order without relying on pairs(): 20 runs, identical output.
local first_ser = nil
local stable = true
for _ = 1, 20 do
    local vv = kv.validate({ kv_bits = 2, swa_bits = 4, indexer_bits = 2, engram_bits = 4, rope_order = 'before' })
    local ser = table.concat(vv, '|')
    if first_ser == nil then
        first_ser = ser
    elseif ser ~= first_ser then
        stable = false
    end
end
check(stable and first_ser ~= nil, 'violation order is deterministic across runs')
check(
    #kv.validate({ kv_bits = 2, swa_bits = 4, indexer_bits = 2, engram_bits = 4, rope_order = 'before' }) == 6,
    'all six violations reported: global, local, indexer_q, indexer_k, engram, rope'
)

-- rose config speculative wiring ---------------------------------------------------------
local rose_config = require('ai.rose.config')
local off = rose_config.resolve({})
check(off.speculative.enabled == false, 'speculative defaults to off')
check(off.speculative.allow_remote == false, 'speculative defaults to loopback-only')
check(
    off.speculative.host == '127.0.0.1' and off.speculative.port == 8080 and off.speculative.n_draft == 5,
    'default-off speculative section keeps its shape and changes no inference behavior'
)
local wok1 = pcall(rose_config.resolve, { speculative = { enabled = true } })
check(not wok1, 'enabling speculative without a draft model raises')
local wok2 =
    pcall(rose_config.resolve, { speculative = { enabled = true, draft_model = '/m/d.gguf', allow_remote = 'yes' } })
check(not wok2, 'a non-boolean speculative.allow_remote raises instead of silently staying off')
-- Explicit remote consent flows through to the module, which then honors it.
local remote = rose_config.resolve({
    speculative = { enabled = true, draft_model = '/m/d.gguf', host = 'example.com', allow_remote = true },
})
check(remote.speculative.allow_remote == true, 'allow_remote=true survives resolve')
local rcfg, rcfg_err = spec.draft_config({
    draft_model_path = remote.speculative.draft_model,
    host = remote.speculative.host,
    port = remote.speculative.port,
    allow_remote = remote.speculative.allow_remote,
})
check(rcfg_err == nil and rcfg.server_url == 'http://example.com:8080', 'config consent reaches draft_config')
-- Without consent the config passes (declared) but the module enforces loopback.
local noremote = rose_config.resolve({
    speculative = { enabled = true, draft_model = '/m/d.gguf', host = 'example.com' },
})
check(noremote.speculative.allow_remote == false, 'remote host without consent keeps allow_remote=false')
local _, nrcfg_err = spec.draft_config({
    draft_model_path = noremote.speculative.draft_model,
    host = noremote.speculative.host,
    allow_remote = noremote.speculative.allow_remote,
})
check_err(nrcfg_err, 'allow_remote', 'the module refuses the unconsented remote host')

print(('PASS: %d checks'):format(count))
