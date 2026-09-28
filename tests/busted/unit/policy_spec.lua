-- tests/busted/unit/policy_spec.lua
-- Spec for ai.harness.policy: the single authorization decision point.
-- 8 validation + 8 adversarial = 16 tests.
-- Run from repo root: busted --run=unit tests/busted/unit/policy_spec.lua

local policy = require('ai.harness.policy')

local function req(overrides)
    local r = {
        risk = 'observe',
        tool = 'fs.read',
        paths = { '/workspace/notes.txt' },
        workspace = '/workspace',
    }
    if overrides then
        for k, v in pairs(overrides) do
            r[k] = v
        end
    end
    return r
end

describe('ai.harness.policy', function()
    describe('validation', function()
        it('allows a request matched by a risk-class rule', function()
            local p = assert(policy.new({
                rules = { { risk = 'observe', decision = 'allow' } },
            }))
            local d = policy.decide(p, req())
            assert.are.equal('allow', d.decision)
            assert.are.equal('observe', d.risk)
        end)

        it('lets the first matching rule win', function()
            local p = assert(policy.new({
                rules = {
                    { risk = 'network', decision = 'deny' },
                    { risk = 'network', decision = 'allow' },
                },
            }))
            local d = policy.decide(p, req({ risk = 'network' }))
            assert.are.equal('deny', d.decision)
        end)

        it('denies by default when no rule matches', function()
            local p = assert(policy.new({}))
            local d = policy.decide(p, req())
            assert.are.equal('deny', d.decision)
            assert.are.equal('no rule matched', d.reason)
        end)

        it('allows by default when configured to do so', function()
            local p = assert(policy.new({ default = 'allow' }))
            local d = policy.decide(p, req())
            assert.are.equal('allow', d.decision)
        end)

        it('accepts paths inside the workspace root', function()
            assert.is_true(policy.path_in_workspace('/workspace/a/b.txt', '/workspace'))
            assert.is_true(policy.path_in_workspace('/workspace', '/workspace'))
            assert.is_true(policy.path_in_workspace('/workspace/', '/workspace'))
        end)

        it('scopes a rule to matching tools', function()
            local p = assert(policy.new({
                rules = { { risk = 'observe', tools = { 'fs.read' }, decision = 'allow' } },
            }))
            assert.are.equal('allow', policy.decide(p, req()).decision)
            assert.are.equal('deny', policy.decide(p, req({ tool = 'fs.write' })).decision)
        end)

        it('scopes a rule to matching endpoints', function()
            local p = assert(policy.new({
                rules = {
                    { risk = 'network', endpoints = { 'https://api.example.com' }, decision = 'approval' },
                },
            }))
            local hit = req({ risk = 'network', endpoints = { 'https://api.example.com' } })
            assert.are.equal('approval', policy.decide(p, hit).decision)
            local miss = req({ risk = 'network', endpoints = { 'https://evil.example' } })
            assert.are.equal('deny', policy.decide(p, miss).decision)
        end)

        it('scopes a rule to matching paths', function()
            local p = assert(policy.new({
                rules = { { risk = 'local_reversible', paths = { '/workspace/src' }, decision = 'allow' } },
            }))
            local d = policy.decide(
                p,
                req({
                    risk = 'local_reversible',
                    paths = { '/workspace/src/main.lua' },
                })
            )
            assert.are.equal('allow', d.decision)
        end)
    end)

    describe('adversarial', function()
        it('denies when no policy is configured', function()
            local d = policy.decide(nil, req())
            assert.are.equal('deny', d.decision)
            assert.are.equal('no policy configured', d.reason)
        end)

        it('denies requests with an unknown risk class', function()
            local p = assert(policy.new({ default = 'allow' }))
            local d = policy.decide(p, req({ risk = 'omnipotent' }))
            assert.are.equal('deny', d.decision)
            assert.are.equal('irreversible', d.risk)
        end)

        it('denies paths that escape the workspace', function()
            local p = assert(policy.new({
                default = 'allow',
                rules = { { risk = 'local_reversible', decision = 'allow' } },
            }))
            local d = policy.decide(
                p,
                req({
                    risk = 'local_reversible',
                    paths = { '/etc/passwd' },
                })
            )
            assert.are.equal('deny', d.decision)
            assert.is_truthy(d.reason:find('escapes workspace'))
        end)

        it('denies non-absolute paths', function()
            assert.is_false(policy.path_in_workspace('relative/path', '/workspace'))
            assert.is_false(policy.path_in_workspace('/workspace/x', 'workspace'))
            local p = assert(policy.new({ default = 'allow' }))
            local d = policy.decide(p, req({ paths = { 'relative/path' } }))
            assert.are.equal('deny', d.decision)
        end)

        it('rejects a rule with a bad decision', function()
            local p, err = policy.new({ rules = { { risk = 'observe', decision = 'maybe' } } })
            assert.is_nil(p)
            assert.is_truthy(err:find('decision'))
        end)

        it('rejects more than 256 rules', function()
            local rules = {}
            for _ = 1, 257 do
                rules[#rules + 1] = { risk = 'observe', decision = 'allow' }
            end
            local p, err = policy.new({ rules = rules })
            assert.is_nil(p)
            assert.is_truthy(err:find('bound'))
        end)

        it('denies a malformed (non-table) request', function()
            local p = assert(policy.new({ default = 'allow' }))
            local d = policy.decide(p, 'garbage')
            assert.are.equal('deny', d.decision)
            assert.are.equal('malformed request', d.reason)
        end)

        it('rejects a policy default that is not deny/allow', function()
            local p, err = policy.new({ default = 'sometimes' })
            assert.is_nil(p)
            assert.is_truthy(err:find('default'))
        end)
    end)
end)
