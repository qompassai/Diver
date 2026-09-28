-- tests/busted/unit/telemetry_spec.lua
-- Busted unit specs for ai.harness.telemetry (Tiger Style).
-- 5 validation + 5 adversarial. Deterministic, no network.

local telemetry = require('ai.harness.telemetry')

describe('telemetry', function()
    it('logs all four levels with fields', function()
        local t = telemetry.new()
        for _, level in ipairs({ 'debug', 'info', 'warn', 'error' }) do
            assert(telemetry.log(t, level, { msg = 'hello' }))
        end
        assert(#t.entries == 4)
        assert(t.entries[1].level == 'debug')
        assert(t.entries[4].level == 'error')
        assert(t.entries[2].fields.msg == 'hello')
    end)

    it('redacts nested secrets but keeps plain fields', function()
        local t = telemetry.new()
        assert(telemetry.log(t, 'info', {
            api_key = 'sk-live-123',
            nested = { password = 'hunter2', safe = 'yes' },
            plain = 'visible',
        }))
        local fields = t.entries[1].fields
        assert(fields.api_key == '[REDACTED]')
        assert(fields.nested.password == '[REDACTED]')
        assert(fields.nested.safe == 'yes')
        assert(fields.plain == 'visible')
    end)

    it('incr and counter track metrics', function()
        local t = telemetry.new()
        telemetry.incr(t, 'runs')
        assert(telemetry.counter(t, 'runs') == 1)
        telemetry.incr(t, 'runs', 5)
        assert(telemetry.counter(t, 'runs') == 6)
        assert(telemetry.counter(t, 'missing') == 0)
    end)

    it('log returns true and never mutates the caller table', function()
        local t = telemetry.new()
        local fields = { token = 'abc' }
        local ok, err = telemetry.log(t, 'info', fields)
        assert(ok == true, err)
        assert(t.entries[1].fields.token == '[REDACTED]')
        assert(fields.token == 'abc')
    end)

    it('redact passes non-tables through untouched', function()
        assert(telemetry.redact('str') == 'str')
        assert(telemetry.redact(42) == 42)
        assert(telemetry.redact(nil) == nil)
    end)
end)

describe('telemetry adversarial', function()
    it('rejects an unknown log level', function()
        local t = telemetry.new()
        local ok, err = telemetry.log(t, 'verbose', {})
        assert(ok == nil)
        assert(err:find('unknown log level', 1, true) ~= nil)
    end)

    it('rejects non-table fields', function()
        local t = telemetry.new()
        local ok, err = telemetry.log(t, 'info', 'nope')
        assert(ok == nil)
        assert(err:find('log fields must be a table', 1, true) ~= nil)
    end)

    it('survives a cycle in the logged table', function()
        local t = telemetry.new()
        local cyc = { name = 'loop' }
        cyc.self = cyc
        local ok, err = telemetry.log(t, 'info', { cyc = cyc })
        assert(ok == true, err)
        assert(t.entries[1].fields.cyc.self == '[CYCLE]')
    end)

    it('never leaks a secret nested beyond the redact bound', function()
        local t = telemetry.new()
        local deep = { api_key = 'TOPSECRET' }
        for _ = 1, 20 do
            deep = { child = deep }
        end
        local ok, err = telemetry.log(t, 'info', deep)
        assert(ok == true, err)
        local leaked = false
        local function scan(v, depth)
            if depth > 40 or leaked then
                return
            end
            if v == 'TOPSECRET' then
                leaked = true
                return
            end
            if type(v) == 'table' then
                for _, child in pairs(v) do
                    scan(child, depth + 1)
                end
            end
        end
        scan(t.entries[1].fields, 0)
        assert(leaked == false, 'secret leaked past the redact bound')
    end)

    it('redacts secret keys case-insensitively', function()
        local t = telemetry.new()
        assert(telemetry.log(t, 'warn', {
            API_KEY = 'x1',
            Authorization = 'x2',
            DbPassword = 'x3',
            apikey = 'x4',
        }))
        local fields = t.entries[1].fields
        assert(fields.API_KEY == '[REDACTED]')
        assert(fields.Authorization == '[REDACTED]')
        assert(fields.DbPassword == '[REDACTED]')
        assert(fields.apikey == '[REDACTED]')
    end)
end)
