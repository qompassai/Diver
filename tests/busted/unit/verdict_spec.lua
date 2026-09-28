-- tests/busted/unit/verdict_spec.lua
-- Busted unit specs for ai.harness.verdict (Tiger Style).
-- 6 validation + 6 adversarial. Deterministic, no network.

local verdict = require('ai.harness.verdict')

local function sample_run()
    return { id = 'r1', state = 'running' }
end

describe('verdict', function()
    it('command check passes on exit 0 via injected runner', function()
        local seen = nil
        local deps = {
            run_command = function(argv)
                seen = argv
                return { exit = 0, output = 'ok' }
            end,
        }
        local v, err = verdict.evaluate(sample_run(), { { kind = 'command', argv = { 'true' } } }, deps)
        assert(v ~= nil, err)
        assert(v.pass == true)
        assert(#v.checks == 1)
        assert(v.checks[1].kind == 'command')
        assert(v.checks[1].detail == 'exit=0')
        assert(seen[1] == 'true')
    end)

    it('command check fails on non-zero exit', function()
        local deps = {
            run_command = function()
                return { exit = 1, output = '' }
            end,
        }
        local v, err = verdict.evaluate(sample_run(), { { kind = 'command', argv = { 'false' } } }, deps)
        assert(v ~= nil, err)
        assert(v.pass == false)
        assert(v.checks[1].detail == 'exit=1')
    end)

    it('diagnostics check honors max_errors', function()
        local deps = {
            get_diagnostics = function()
                return { errors = 2 }
            end,
        }
        local v = assert(verdict.evaluate(sample_run(), { { kind = 'diagnostics', max_errors = 3 } }, deps))
        assert(v.pass == true)
        local v2 = assert(verdict.evaluate(sample_run(), { { kind = 'diagnostics', max_errors = 1 } }, deps))
        assert(v2.pass == false)
        assert(v2.checks[1].detail == 'errors=2 max=1')
    end)

    it('schema check validates types and required fields', function()
        local schema = { types = { name = 'string' }, required = { 'name' } }
        local v = assert(verdict.evaluate(sample_run(), {
            { kind = 'schema', value = { name = 'x' }, schema = schema },
        }))
        assert(v.pass == true)
        assert(v.checks[1].detail == 'valid')
        local v2 = assert(verdict.evaluate(sample_run(), {
            { kind = 'schema', value = { name = 5 }, schema = schema },
        }))
        assert(v2.pass == false)
        assert(v2.checks[1].detail:find('name', 1, true) ~= nil)
    end)

    it('custom check uses the caller predicate', function()
        local yes = {
            {
                kind = 'custom',
                check = function(r)
                    return r.id == 'r1'
                end,
            },
        }
        local v = assert(verdict.evaluate(sample_run(), yes))
        assert(v.pass == true)
        local no = {
            {
                kind = 'custom',
                check = function()
                    return false
                end,
            },
        }
        local v2 = assert(verdict.evaluate(sample_run(), no))
        assert(v2.pass == false)
    end)

    it('all-pass verdict aggregates every check', function()
        local deps = {
            run_command = function()
                return { exit = 0, output = '' }
            end,
            get_diagnostics = function()
                return { errors = 0 }
            end,
        }
        local acceptance = {
            { kind = 'command', argv = { 'true' } },
            { kind = 'diagnostics', max_errors = 0 },
            {
                kind = 'custom',
                check = function()
                    return true
                end,
            },
        }
        local v, err = verdict.evaluate(sample_run(), acceptance, deps)
        assert(v ~= nil, err)
        assert(v.pass == true)
        assert(#v.checks == 3)
    end)
end)

describe('verdict adversarial', function()
    it('rejects an unknown acceptance kind', function()
        local v, err = verdict.evaluate(sample_run(), { { kind = 'bogus' } })
        assert(v == nil)
        assert(err:find('unknown acceptance kind', 1, true) ~= nil)
    end)

    it('rejects an empty acceptance list', function()
        local v, err = verdict.evaluate(sample_run(), {})
        assert(v == nil)
        assert(err:find('non-empty array', 1, true) ~= nil)
    end)

    it('command check fails honestly when no runner is available', function()
        -- Default runner: the busted vim stub has no vim.system.
        local v, err = verdict.evaluate(sample_run(), { { kind = 'command', argv = { 'true' } } })
        assert(v ~= nil, err)
        assert(v.pass == false)
        assert(v.checks[1].detail:find('unavailable', 1, true) ~= nil)
        -- Injected runner reporting unavailable:
        local deps = {
            run_command = function()
                return { exit = nil, error = 'nope' }
            end,
        }
        local v2 = assert(verdict.evaluate(sample_run(), { { kind = 'command', argv = { 'x' } } }, deps))
        assert(v2.pass == false)
        assert(v2.checks[1].detail == 'nope')
    end)

    it('custom check that raises becomes a failed check', function()
        local acceptance = {
            {
                kind = 'custom',
                check = function()
                    error('boom')
                end,
            },
        }
        local v, err = verdict.evaluate(sample_run(), acceptance)
        assert(v ~= nil, err)
        assert(v.pass == false)
        assert(v.checks[1].detail:find('check raised', 1, true) ~= nil)
    end)

    it('diagnostics check without max_errors is rejected', function()
        local v, err = verdict.evaluate(sample_run(), { { kind = 'diagnostics' } })
        assert(v == nil)
        assert(err:find('max_errors', 1, true) ~= nil)
    end)

    it('acceptance list past the bound is rejected', function()
        local acceptance = {}
        for i = 1, 33 do
            acceptance[i] = {
                kind = 'custom',
                check = function()
                    return true
                end,
            }
        end
        local v, err = verdict.evaluate(sample_run(), acceptance)
        assert(v == nil)
        assert(err:find('exceeds bound', 1, true) ~= nil)
    end)
end)
