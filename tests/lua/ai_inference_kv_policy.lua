--- KV precision policy self-test — proves the policy table and validator behave.
---
--- Plain-language version: this is a test script, not a feature. It exercises
--- lua/ai/inference/kv_policy.lua (the DeepSeek-V4.1-Flash quantization
--- rules as checkable data) and reports pass or fail. It runs headless via
--- `nvim -l`; it is not loaded at startup.
---@module 'tests.ai_inference_kv_policy'
vim.opt.runtimepath:prepend(vim.fn.getcwd())
local count = 0
local function check(value, message)
    assert(value, message)
    count = count + 1
end
local function check_err(err, fragment, message)
    check(type(err) == 'string' and err:find(fragment, 1, true) ~= nil, message .. ' (got: ' .. tostring(err) .. ')')
end

local kv = require('ai.inference.kv_policy')

-- policy() ------------------------------------------------------------------
local policy = kv.policy()
check(type(policy) == 'table', 'policy returns a table')
check(policy.version == 1, 'policy carries a schema version')
check(type(policy.source) == 'string' and policy.source:find('2609.19969', 1, true) ~= nil, 'policy cites the paper')
local expected = { global_kv = 4, local_kv = 8, indexer_q = 4, indexer_k = 4, engram = 8 }
for component, min_bits in pairs(expected) do
    local rule = policy.components[component]
    check(type(rule) == 'table', 'policy has component ' .. component)
    check(rule.min_bits == min_bits, component .. ' requires ' .. min_bits .. ' bits')
    check(type(rule.recommended) == 'string' and rule.recommended ~= '', component .. ' has a recommended label')
    check(type(rule.note) == 'string' and rule.note ~= '', component .. ' has an explanatory note')
end
policy.components.global_kv.min_bits = 1
policy.components.new_component = { min_bits = 1 }
local fresh = kv.policy()
check(fresh.components.global_kv.min_bits == 4, 'policy returns a deep copy: mutation does not leak')
check(fresh.components.new_component == nil, 'policy returns a deep copy: additions do not leak')

-- recommend -------------------------------------------------------------------
local rec_cases = {
    global_kv = 'fp4',
    local_kv = 'fp8',
    swa_kv = 'fp8',
    sliding_window_kv = 'fp8',
    indexer_q = 'fp4',
    indexer_k = 'fp4',
    index_query = 'fp4',
    index_key = 'fp4',
    engram = 'fp8',
}
for component, want in pairs(rec_cases) do
    local got, got_err = kv.recommend(component)
    check(got_err == nil and got == want, 'recommend(' .. component .. ') is ' .. want)
end
local _, unknown_err = kv.recommend('quantum_kv')
check_err(unknown_err, 'unknown component', 'recommend rejects an unknown component')
local _, nonstring_err = kv.recommend(42)
check_err(nonstring_err, 'unknown component', 'recommend rejects a non-string component')
local _, nil_err = kv.recommend(nil)
check_err(nil_err, 'unknown component', 'recommend rejects nil')

-- validate --------------------------------------------------------------------
local function check_clean(violations, message)
    check(type(violations) == 'table' and #violations == 0, message .. ' (got: ' .. vim.inspect(violations) .. ')')
end
local clean, clean_err = kv.validate({})
check(clean_err == nil, 'validate accepts an empty cfg')
check_clean(clean, 'an empty cfg has no violations: absent fields are not judged')
local compliant = { kv_bits = 4, rope_order = 'after', swa_bits = 8, indexer_bits = 4, engram_bits = 8 }
local ok_violations, ok_err = kv.validate(compliant)
check(ok_err == nil, 'validate accepts a compliant cfg')
check_clean(ok_violations, 'a compliant cfg has no violations')
local generous, generous_err = kv.validate({ kv_bits = 16, swa_bits = 16, indexer_bits = 8, engram_bits = 16 })
check(generous_err == nil, 'validate accepts generous precision')
check_clean(generous, 'higher-than-minimum precision has no violations')

local v1 = kv.validate({ kv_bits = 2 })
check(#v1 == 1, 'kv_bits=2 yields exactly one violation')
check(
    v1[1]:find('global_kv', 1, true) ~= nil and v1[1]:find('4', 1, true) ~= nil,
    'the violation names global_kv and the 4-bit minimum'
)
local v2 = kv.validate({ rope_order = 'before' })
check(#v2 == 1, "rope_order='before' yields exactly one violation")
check(
    v2[1]:find('rope_order', 1, true) ~= nil and v2[1]:find('RoPE', 1, true) ~= nil,
    'the violation names rope_order and RoPE'
)
local v3 = kv.validate({ rope_order = 'sideways' })
check(#v3 == 1, 'an invalid rope_order value yields a violation')
local v4 = kv.validate({ swa_bits = 4 })
check(#v4 == 1 and v4[1]:find('local_kv', 1, true) ~= nil, 'swa_bits=4 violates the local_kv rule')
local v5 = kv.validate({ indexer_bits = 2 })
check(#v5 == 2, 'indexer_bits=2 violates both indexer_q and indexer_k')
check(
    v5[1]:find('indexer_q', 1, true) ~= nil and v5[2]:find('indexer_k', 1, true) ~= nil,
    'indexer violations are deterministic: q before k'
)
local v6 = kv.validate({ engram_bits = 4 })
check(#v6 == 1 and v6[1]:find('engram', 1, true) ~= nil, 'engram_bits=4 violates the engram rule')
local v7 = kv.validate({ kv_bits = 2, swa_bits = 4, rope_order = 'before' })
check(#v7 == 3, 'multiple problems yield one violation each')
check(
    v7[1]:find('global_kv', 1, true) ~= nil
        and v7[2]:find('local_kv', 1, true) ~= nil
        and v7[3]:find('rope_order', 1, true) ~= nil,
    'violations follow the deterministic component order, rope last'
)
local v8 = kv.validate({ kv_bits = '4' })
check(
    #v8 == 1 and v8[1]:find('kv_bits', 1, true) ~= nil and v8[1]:find('integer', 1, true) ~= nil,
    'a mistyped bits field is a violation, not a crash'
)
local v9 = kv.validate({ kv_bits = 0 })
check(#v9 == 1, 'kv_bits=0 is rejected')
local v10 = kv.validate({ kv_bits = 2.5 })
check(#v10 == 1, 'fractional bits are rejected')
local _, bad_err = kv.validate('nope')
check_err(bad_err, 'cfg must be a table', 'validate rejects a non-table cfg')
local _, nilcfg_err = kv.validate(nil)
check_err(nilcfg_err, 'cfg must be a table', 'validate rejects nil cfg')

-- rose config wiring ------------------------------------------------------------
local rose_config = require('ai.rose.config')
check(pcall(rose_config.resolve, {}), 'default resolve (speculative off) ignores kv')
local enabled = rose_config.resolve({
    speculative = {
        enabled = true,
        draft_model = '/models/d.gguf',
        kv = { kv_bits = 4, swa_bits = 8, rope_order = 'after' },
    },
})
check(enabled.speculative.kv.kv_bits == 4, 'a compliant kv contract survives resolve')
local kv_bad_ok, kv_bad_err = pcall(rose_config.resolve, {
    speculative = { enabled = true, draft_model = '/models/d.gguf', kv = { rope_order = 'before' } },
})
check(not kv_bad_ok, 'a violating kv contract raises at resolve')
check_err(kv_bad_err, 'KV precision policy', 'the violation message names the policy')
local kv_mistype_ok, kv_mistype_err = pcall(rose_config.resolve, {
    speculative = { enabled = true, draft_model = '/models/d.gguf', kv = 'fp4' },
})
check(not kv_mistype_ok, 'a non-table kv raises at resolve')
check_err(kv_mistype_err, 'speculative.kv must be a table', 'the kv type error is explicit')

print(('PASS: %d checks'):format(count))
