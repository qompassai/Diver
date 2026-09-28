-- tests/busted/unit/adapter_spec.lua
-- Spec for ai.harness.adapter: adapter contract validation and negotiation.
-- 5 validation + 5 adversarial = 10 tests.
-- Run from repo root: busted --run=unit tests/busted/unit/adapter_spec.lua

local adapter = require('ai.harness.adapter')
local types = require('ai.harness.types')

local function full_caps(overrides)
    local caps = {}
    for _, key in ipairs(types.CAPABILITY_KEYS) do
        caps[key] = true
    end
    if overrides then
        for k, v in pairs(overrides) do
            caps[k] = v
        end
    end
    return caps
end

local function fake_adapter(name, caps)
    caps = caps or full_caps()
    return {
        name = name,
        probe = function()
            return caps
        end,
        start = function()
            return {}
        end,
        cancel = function()
            return true
        end,
        close = function() end,
    }
end

describe('ai.harness.adapter', function()
    describe('validation', function()
        it('validates a complete adapter table', function()
            assert.is_true(adapter.validate(fake_adapter('x')))
        end)

        it('probes capabilities without side effects', function()
            local caps, err = adapter.probe(fake_adapter('x'))
            assert.is_truthy(caps, tostring(err))
            for _, key in ipairs(types.CAPABILITY_KEYS) do
                assert.is_true(caps[key], key)
            end
        end)

        it('negotiates the first satisfying adapter in sorted name order', function()
            local zeta = fake_adapter('zeta')
            local alpha = fake_adapter('alpha')
            local chosen, err = adapter.negotiate({ zeta = zeta, alpha = alpha }, { streaming = true })
            assert.is_truthy(chosen, tostring(err))
            assert.are.equal(alpha, chosen)
        end)

        it('negotiates the first adapter alphabetically with no needs', function()
            local beta = fake_adapter('beta')
            local alpha = fake_adapter('alpha')
            local chosen = adapter.negotiate({ beta = beta, alpha = alpha }, {})
            assert.are.equal(alpha, chosen)
        end)

        it('skips adapters that fail the needs and picks a later one', function()
            local limited = fake_adapter('aaa', full_caps({ streaming = false }))
            local full = fake_adapter('zzz')
            local chosen, err = adapter.negotiate({ aaa = limited, zzz = full }, { streaming = true })
            assert.is_truthy(chosen, tostring(err))
            assert.are.equal(full, chosen)
        end)
    end)

    describe('adversarial', function()
        it('turns a raising probe into nil plus an error', function()
            local a = fake_adapter('x')
            a.probe = function()
                error('kaput')
            end
            local caps, err = adapter.probe(a)
            assert.is_nil(caps)
            assert.is_truthy(err:find('raised'))
        end)

        it('rejects a probe returning a non-boolean capability', function()
            local a = fake_adapter('x', full_caps({ streaming = 'yes' }))
            local caps, err = adapter.probe(a)
            assert.is_nil(caps)
            assert.is_truthy(err:find('streaming'))
        end)

        it('fails negotiation when no adapter satisfies the needs', function()
            local a = fake_adapter('only', full_caps({ streaming = false }))
            local chosen, err = adapter.negotiate({ only = a }, { streaming = true })
            assert.is_nil(chosen)
            assert.is_truthy(err:find('no adapter satisfies'))
        end)

        it('rejects an adapter missing start', function()
            local a = fake_adapter('x')
            a.start = nil
            local ok, err = adapter.validate(a)
            assert.is_nil(ok)
            assert.is_truthy(err:find('adapter.start'))
        end)

        it('rejects a non-table adapters argument to negotiate', function()
            local chosen, err = adapter.negotiate(nil, {})
            assert.is_nil(chosen)
            assert.is_truthy(err:find('adapters must be a table'))
        end)
    end)
end)
