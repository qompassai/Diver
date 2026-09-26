--- Speculative decoding self-test — proves the inference helpers behave.
---
--- Plain-language version: this is a test script, not a feature. It exercises
--- lua/ai/inference/speculative.lua (llama.cpp detect/draft_config,
--- agent-level draft_verify, throughput scheduler) and the speculative
--- section of lua/ai/rose/config.lua, then reports pass or fail. Network
--- probes hit stub loopback listeners only; no real servers are used.
--- It runs headless via `nvim -l`; it is not loaded at startup.
---@module 'tests.ai_inference_speculative'
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

-- new_stats ----------------------------------------------------------------
local stats = spec.new_stats()
check(
    stats.drafts == 0
        and stats.draft_chars == 0
        and stats.accepted_direct == 0
        and stats.verify_calls == 0
        and stats.verified_chars == 0,
    'new_stats returns a zeroed accumulator'
)

-- draft_config --------------------------------------------------------------
local cfg, cfg_err = spec.draft_config({ draft_model_path = '/models/draft.gguf' })
check(cfg_err == nil and cfg ~= nil, 'draft_config accepts a minimal valid opts')
check(cfg.n_draft == 5, 'draft_config defaults n_draft to 5')
check(cfg.server_url == 'http://127.0.0.1:8080', 'draft_config defaults to loopback :8080')
check(cfg.draft_model_path == '/models/draft.gguf', 'draft_config keeps the draft model path')
check(
    cfg.server_argv[1] == '--host' and cfg.server_argv[5] == '--draft-model' and cfg.server_argv[7] == '--draft-max',
    'draft_config suggests a --draft-model argv fragment'
)
local cfg2 = spec.draft_config({
    draft_model_path = '/models/d.gguf',
    n_draft = 16,
    endpoint = { host = '127.0.0.1', port = 9999 },
})
check(
    cfg2 ~= nil and cfg2.n_draft == 16 and cfg2.server_url == 'http://127.0.0.1:9999',
    'draft_config honors endpoint and n_draft=16'
)
local cfg3 = spec.draft_config({ draft_model_path = '/models/d.gguf', n_draft = 1 })
check(cfg3 ~= nil and cfg3.n_draft == 1, 'draft_config accepts n_draft=1')
local _, e1 = spec.draft_config({ draft_model_path = '/models/d.gguf', n_draft = 0 })
check_err(e1, 'n_draft', 'draft_config rejects n_draft=0')
local _, e2 = spec.draft_config({ draft_model_path = '/models/d.gguf', n_draft = 17 })
check_err(e2, 'n_draft', 'draft_config rejects n_draft=17')
local _, e3 = spec.draft_config({ draft_model_path = '/models/d.gguf', n_draft = 2.5 })
check_err(e3, 'n_draft', 'draft_config rejects fractional n_draft')
local _, e4 = spec.draft_config({})
check_err(e4, 'draft_model_path', 'draft_config rejects a missing draft model path')
local _, e5 = spec.draft_config({ draft_model_path = '' })
check_err(e5, 'draft_model_path', 'draft_config rejects an empty draft model path')
local _, e6 = spec.draft_config({ draft_model_path = '/models/d\0.gguf' })
check_err(e6, 'draft_model_path', 'draft_config rejects a NUL byte in the path')
local _, e7 = spec.draft_config({ draft_model_path = '/models/d.gguf', host = 'example.com' })
check_err(e7, 'allow_remote', 'draft_config refuses a remote host without allow_remote')
local cfg4, cfg4_err =
    spec.draft_config({ draft_model_path = '/models/d.gguf', host = 'example.com', allow_remote = true })
check(
    cfg4_err == nil and cfg4.server_url == 'http://example.com:8080',
    'draft_config allows a remote host with allow_remote'
)
local _, e8 = spec.draft_config({ draft_model_path = '/models/d.gguf', port = 70000 })
check_err(e8, 'port', 'draft_config rejects port 70000')
local _, e9 = spec.draft_config('nope')
check_err(e9, 'opts must be a table', 'draft_config rejects non-table opts')
local _, e10 = spec.draft_config({ draft_model_path = '/models/d.gguf', endpoint = 'nope' })
check_err(e10, 'endpoint must be a table', 'draft_config rejects a non-table endpoint')

-- detect --------------------------------------------------------------------
local function listen_stub()
    local server = assert(vim.uv.new_tcp())
    assert(server:bind('127.0.0.1', 0))
    server:listen(4, function() end)
    local name = server:getsockname()
    return server, name.port
end
local function detect_sync(opts)
    local done, err, endpoint = false, nil, nil
    spec.detect(opts, function(detect_err, detect_endpoint)
        err, endpoint, done = detect_err, detect_endpoint, true
    end)
    local finished = vim.wait(5000, function()
        return done
    end, 10)
    check(finished, 'detect callback fires')
    return err, endpoint
end
local stub_server, stub_port = listen_stub()
local detect_err, endpoint = detect_sync({ host = '127.0.0.1', port = stub_port })
check(detect_err == nil, 'detect finds the stub loopback server (err: ' .. tostring(detect_err) .. ')')
check(
    endpoint ~= nil and endpoint.host == '127.0.0.1' and endpoint.port == stub_port,
    'detect returns the probed endpoint'
)
stub_server:close()
local closed_err = detect_sync({ port = stub_port })
check_err(closed_err, 'no server', 'detect reports a closed port')
local remote_err = detect_sync({ host = 'example.com', port = 8080, timeout_ms = 100 })
check_err(remote_err, 'allow_remote', 'detect refuses a remote host without allow_remote')
local remote_unroutable_err = detect_sync({ host = '10.255.255.1', port = 8080, timeout_ms = 500, allow_remote = true })
check(type(remote_unroutable_err) == 'string' and remote_unroutable_err ~= '', 'detect errors on an unroutable host')
local bad_port_err = detect_sync({ port = 0 })
check_err(bad_port_err, 'port', 'detect rejects port 0')
local bad_timeout_err = detect_sync({ timeout_ms = -1 })
check_err(bad_timeout_err, 'timeout_ms', 'detect rejects a negative timeout')
local bad_host_err = detect_sync({ host = '' })
check_err(bad_host_err, 'host', 'detect rejects an empty host')
local cb_ok = pcall(spec.detect, {}, 'not-a-function')
check(not cb_ok, 'detect asserts on a non-function callback')

-- draft_verify ----------------------------------------------------------------
local function make_fns(draft_result, draft_fail, verify_result, verify_fail)
    local calls = { verify = 0 }
    local draft_fn = function(_prompt)
        if draft_fail then
            return nil, draft_fail
        end
        return draft_result, nil
    end
    local verify_fn = function(_prompt, _draft)
        calls.verify = calls.verify + 1
        if verify_fail then
            return nil, verify_fail
        end
        return verify_result, nil
    end
    return draft_fn, verify_fn, calls
end
local function dv_opts(overrides)
    local base = {
        prompt = 'write a haiku',
        confidence_fn = function()
            return 0.95
        end,
        stats = spec.new_stats(),
    }
    if overrides then
        for key, value in pairs(overrides) do
            base[key] = value
        end
    end
    return base
end
-- accept path: confident draft skips verify
local d1, v1, c1 = make_fns('draft text', nil, 'verified text', nil)
local opts1 = dv_opts()
local r1, r1_err, r1_used = spec.draft_verify(d1, v1, opts1)
check(r1_err == nil and r1 == 'draft text' and r1_used == false, 'confident draft is accepted directly')
check(c1.verify == 0, 'verify_fn is not called on the accept path')
check(
    opts1.stats.drafts == 1 and opts1.stats.accepted_direct == 1 and opts1.stats.verify_calls == 0,
    'accept-path stats are exact'
)
check(opts1.stats.draft_chars == #'draft text', 'draft_chars counts the accepted draft')
-- verify path: low confidence calls the capable model
local d2, v2, c2 = make_fns('rough draft', nil, 'polished text', nil)
local opts2 = dv_opts({
    confidence_fn = function()
        return 0.2
    end,
})
local r2, r2_err, r2_used = spec.draft_verify(d2, v2, opts2)
check(r2_err == nil and r2 == 'polished text' and r2_used == true, 'low-confidence draft goes to verify')
check(c2.verify == 1, 'verify_fn is called exactly once on the verify path')
check(opts2.stats.verify_calls == 1 and opts2.stats.verified_chars == #'polished text', 'verify-path stats are exact')
-- threshold boundaries 0 and 1
local d3, v3, c3 = make_fns('d', nil, 'v', nil)
local r3 = (function()
    local res, res_err = spec.draft_verify(
        d3,
        v3,
        dv_opts({
            accept_threshold = 0,
            confidence_fn = function()
                return 0.0
            end,
        })
    )
    return res, res_err
end)()
check(r3 == 'd' and c3.verify == 0, 'threshold 0 accepts even zero confidence')
local d4, v4, c4 = make_fns('d', nil, 'v', nil)
local _, r4_err, r4_used = spec.draft_verify(
    d4,
    v4,
    dv_opts({
        accept_threshold = 1,
        confidence_fn = function()
            return 0.999
        end,
    })
)
check(r4_err == nil and r4_used == true and c4.verify == 1, 'threshold 1 verifies anything below perfect confidence')
local d5, v5, c5 = make_fns('d', nil, 'v', nil)
local r5, r5_err, r5_used = spec.draft_verify(
    d5,
    v5,
    dv_opts({
        accept_threshold = 1,
        confidence_fn = function()
            return 1.0
        end,
    })
)
check(r5_err == nil and r5 == 'd' and r5_used == false and c5.verify == 0, 'threshold 1 accepts perfect confidence')
-- confidence misuse
local dc, vc = make_fns('d', nil, 'v', nil)
local _, ce1 = spec.draft_verify(
    dc,
    vc,
    dv_opts({
        confidence_fn = function()
            return 1.5
        end,
    })
)
check_err(ce1, '0..1', 'confidence above 1 is rejected')
local _, ce2 = spec.draft_verify(
    dc,
    vc,
    dv_opts({
        confidence_fn = function()
            return 'high'
        end,
    })
)
check_err(ce2, '0..1', 'non-numeric confidence is rejected')
local _, ce3 = spec.draft_verify(
    dc,
    vc,
    dv_opts({
        confidence_fn = function()
            return 0 / 0
        end,
    })
)
check_err(ce3, '0..1', 'NaN confidence is rejected')
local _, ce4 = spec.draft_verify(
    dc,
    vc,
    dv_opts({
        confidence_fn = function()
            error('boom')
        end,
    })
)
check_err(ce4, 'raised', 'a raising confidence_fn becomes an error')
-- draft failures
local df1, vf1, cf1 = make_fns(nil, 'draft exploded', 'v', nil)
local _, de1, de1_used = spec.draft_verify(df1, vf1, dv_opts())
check_err(de1, 'draft failed', 'draft_fn errors propagate')
check(de1_used == false and cf1.verify == 0, 'a failed draft never reaches verify')
local df2 = function()
    error('draft raised')
end
local _, de2 = spec.draft_verify(df2, vf1, dv_opts())
check_err(de2, 'raised', 'a raising draft_fn becomes an error')
local df3, vf3 = make_fns(42, nil, 'v', nil)
local _, de3 = spec.draft_verify(df3, vf3, dv_opts())
check_err(de3, 'must return a string', 'a non-string draft is rejected')
-- verify failures
local df4, vf4, cf4 = make_fns('d', nil, nil, 'verify exploded')
local _, ve1, ve1_used = spec.draft_verify(
    df4,
    vf4,
    dv_opts({
        confidence_fn = function()
            return 0.1
        end,
    })
)
check_err(ve1, 'verify failed', 'verify_fn errors propagate')
check(ve1_used == true and cf4.verify == 1, 'verify was attempted before failing')
local vf5 = function()
    error('verify raised')
end
local _, ve2 = spec.draft_verify(
    df4,
    vf5,
    dv_opts({
        confidence_fn = function()
            return 0.1
        end,
    })
)
check_err(ve2, 'raised', 'a raising verify_fn becomes an error')
local df6, vf6 = make_fns('d', nil, 42, nil)
local _, ve3 = spec.draft_verify(
    df6,
    vf6,
    dv_opts({
        confidence_fn = function()
            return 0.1
        end,
    })
)
check_err(ve3, 'must return a string', 'a non-string verify result is rejected')
-- option misuse
local mok1 = pcall(spec.draft_verify, 'not-a-fn', vf6, dv_opts())
check(not mok1, 'draft_verify asserts on a non-function draft_fn')
local mok2 = pcall(spec.draft_verify, df6, nil, dv_opts())
check(not mok2, 'draft_verify asserts on a missing verify_fn')
local mok3 = pcall(spec.draft_verify, df6, vf6, nil)
check(not mok3, 'draft_verify asserts on missing opts')
local _, oe1 = spec.draft_verify(df6, vf6, dv_opts({ prompt = '' }))
check_err(oe1, 'prompt', 'an empty prompt is rejected')
local _, oe2 = spec.draft_verify(df6, vf6, dv_opts({ accept_threshold = 2 }))
check_err(oe2, 'accept_threshold', 'an out-of-range threshold is rejected')
local _, oe3 = spec.draft_verify(df6, vf6, dv_opts({ max_draft_chars = 0 }))
check_err(oe3, 'max_draft_chars', 'a non-positive draft cap is rejected')
local _, oe4 = spec.draft_verify(df6, vf6, dv_opts({ stats = 'nope' }))
check_err(oe4, 'stats', 'a non-table stats accumulator is rejected')
-- truncation and stats accumulation
local dt, vt = make_fns('0123456789', nil, 'v', nil)
local topts = dv_opts({ max_draft_chars = 5 })
local rt, rt_err = spec.draft_verify(dt, vt, topts)
check(rt_err == nil and rt == '01234', 'drafts longer than max_draft_chars are truncated')
check(topts.stats.draft_chars == 5, 'stats count truncated characters, not the original')
local at, av = make_fns('x', nil, 'y', nil)
local aopts = dv_opts()
spec.draft_verify(at, av, aopts)
spec.draft_verify(at, av, aopts)
check(aopts.stats.drafts == 2 and aopts.stats.draft_chars == 2, 'stats accumulate across calls')
local nt, nv = make_fns('x', nil, 'y', nil)
local nres, nres_err = spec.draft_verify(nt, nv, {
    prompt = 'p',
    confidence_fn = function()
        return 1.0
    end,
})
check(nres_err == nil and nres == 'x', 'draft_verify works without a caller stats table')

-- schedule_for_load -----------------------------------------------------------
local profile = {
    { max_load = 0.25, draft_len = 8, verify_batch = 8 },
    { max_load = 0.75, draft_len = 4, verify_batch = 4 },
    { max_load = 1.0, draft_len = 2, verify_batch = 2 },
}
local s1 = spec.schedule_for_load(profile, 0.1)
check(s1 ~= nil and s1.draft_len == 8 and s1.verify_batch == 8, 'low load picks the first covering row')
local s2 = spec.schedule_for_load(profile, 0.25)
check(s2 ~= nil and s2.draft_len == 8, 'load exactly on a boundary takes that row')
local s3 = spec.schedule_for_load(profile, 0.26)
check(s3 ~= nil and s3.draft_len == 4, 'load just above a boundary takes the next row')
local s4 = spec.schedule_for_load(profile, 1.0)
check(s4 ~= nil and s4.draft_len == 2, 'max load takes the last row')
local short = { { max_load = 0.5, draft_len = 6, verify_batch = 3 } }
local s5 = spec.schedule_for_load(short, 0.99)
check(s5 ~= nil and s5.draft_len == 6, 'load above every row falls back to the last row')
s5.draft_len = 99
local s6 = spec.schedule_for_load(short, 0.99)
check(s6 ~= nil and s6.draft_len == 6, 'the returned choice is a copy')
local _, pe1 = spec.schedule_for_load({}, 0.1)
check_err(pe1, 'nonempty', 'an empty profile is rejected')
local _, pe2 = spec.schedule_for_load(
    { { max_load = 0.9, draft_len = 2, verify_batch = 2 }, { max_load = 0.5, draft_len = 4, verify_batch = 4 } },
    0.1
)
check_err(pe2, 'sorted', 'an unsorted profile is rejected')
local _, pe3 = spec.schedule_for_load(profile, -0.1)
check_err(pe3, 'load', 'a negative load is rejected')
local _, pe4 = spec.schedule_for_load(profile, 1.1)
check_err(pe4, 'load', 'a load above 1 is rejected')
local _, pe5 = spec.schedule_for_load(profile, 'high')
check_err(pe5, 'load', 'a non-numeric load is rejected')
local _, pe6 = spec.schedule_for_load({ { max_load = 0.5, draft_len = 0, verify_batch = 2 } }, 0.1)
check_err(pe6, 'draft_len', 'draft_len 0 is rejected')
local _, pe7 = spec.schedule_for_load({ { max_load = 0.5, draft_len = 17, verify_batch = 2 } }, 0.1)
check_err(pe7, 'draft_len', 'draft_len above the cap is rejected')
local _, pe8 = spec.schedule_for_load({ { max_load = 0.5, draft_len = 4, verify_batch = 0 } }, 0.1)
check_err(pe8, 'verify_batch', 'verify_batch 0 is rejected')
local _, pe9 = spec.schedule_for_load({ { max_load = 2, draft_len = 4, verify_batch = 2 } }, 0.1)
check_err(pe9, 'max_load', 'max_load above 1 is rejected')
local _, pe10 = spec.schedule_for_load('nope', 0.1)
check_err(pe10, 'profile', 'a non-table profile is rejected')

-- rose config wiring ----------------------------------------------------------
local rose_config = require('ai.rose.config')
local resolved = rose_config.resolve({})
check(resolved.speculative ~= nil, 'resolve exposes a speculative section')
check(resolved.speculative.enabled == false, 'speculative defaults to off')
check(
    resolved.speculative.port == 8080 and resolved.speculative.n_draft == 5,
    'speculative defaults carry host/port/n_draft'
)
local enabled = rose_config.resolve({ speculative = { enabled = true, draft_model = '/models/d.gguf' } })
check(
    enabled.speculative.enabled == true and enabled.speculative.draft_model == '/models/d.gguf',
    'speculative can be enabled with a draft model'
)
local wok1 = pcall(rose_config.resolve, { speculative = { enabled = true } })
check(not wok1, 'enabling speculative without a draft model raises')
local wok2 =
    pcall(rose_config.resolve, { speculative = { enabled = true, draft_model = '/models/d.gguf', port = 99999 } })
check(not wok2, 'an out-of-range speculative port raises')
local wok3 = pcall(rose_config.resolve, { speculative = { enabled = 'yes' } })
check(not wok3, 'a non-boolean speculative.enabled raises')

print(('PASS: %d checks'):format(count))
