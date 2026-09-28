-- tests/busted/unit/events_spec.lua
-- Spec for ai.harness.events: append-only typed event stream and sink.
-- 6 validation + 6 adversarial = 12 tests.
-- Run from repo root: busted --run=unit tests/busted/unit/events_spec.lua

local events = require('ai.harness.events')
local types = require('ai.harness.types')

describe('ai.harness.events', function()
    local sink

    before_each(function()
        sink = events.new_sink()
    end)

    describe('validation', function()
        it('assigns strictly increasing sequence numbers from 1', function()
            local e1 = sink:append('run-1', 'run.created', {})
            local e2 = sink:append('run-1', 'run.started', {})
            local e3 = sink:append('run-2', 'run.created', {})
            assert.are.equal(1, e1.seq)
            assert.are.equal(2, e2.seq)
            assert.are.equal(3, e3.seq)
        end)

        it('builds envelopes with schema version, run id, timestamp, source', function()
            local event = sink:append('run-9', 'model.requested', { tokens = 5 })
            assert.are.equal(types.SCHEMA_VERSION, event.schema_version)
            assert.are.equal('run-9', event.run_id)
            assert.is_true(type(event.ts_ns) == 'number')
            assert.are.equal('harness', event.source)
            assert.are.equal('model.requested', event.kind)
            assert.are.equal(5, event.payload.tokens)
            assert.is_false(event.redacted)
        end)

        it('honors envelope opts: source, parent_id, redacted', function()
            local event = sink:append('run-1', 'tool.started', {}, {
                source = 'acp',
                parent_id = 'parent-1',
                redacted = true,
            })
            assert.are.equal('acp', event.source)
            assert.are.equal('parent-1', event.parent_id)
            assert.is_true(event.redacted)
        end)

        it('returns every event when no run filter is given', function()
            sink:append('run-1', 'run.created', {})
            sink:append('run-2', 'run.created', {})
            assert.are.equal(2, #sink:events())
        end)

        it('filters events by run_id', function()
            sink:append('run-1', 'run.created', {})
            sink:append('run-2', 'run.created', {})
            sink:append('run-1', 'run.started', {})
            local got = sink:events('run-1')
            assert.are.equal(2, #got)
            for _, event in ipairs(got) do
                assert.are.equal('run-1', event.run_id)
            end
        end)

        it('counts appended events', function()
            assert.are.equal(0, sink:count())
            sink:append('run-1', 'run.created', {})
            sink:append('run-1', 'run.started', {})
            assert.are.equal(2, sink:count())
        end)
    end)

    describe('adversarial', function()
        it('rejects unknown event kinds', function()
            local event, err = events.make_envelope('run-1', 'nope.bogus', {})
            assert.is_nil(event)
            assert.is_truthy(err:find('unknown event kind'))
            local event2, err2 = sink:append('run-1', 'nope.bogus', {})
            assert.is_nil(event2)
            assert.is_truthy(err2)
        end)

        it('rejects empty or missing run_id', function()
            local event, err = events.make_envelope('', 'run.created', {})
            assert.is_nil(event)
            assert.is_truthy(err:find('run_id'))
            local event2, err2 = sink:append('', 'run.created', {})
            assert.is_nil(event2)
            assert.is_truthy(err2)
        end)

        it('rejects a non-table payload', function()
            local event, err = events.make_envelope('run-1', 'run.created', 'payload')
            assert.is_nil(event)
            assert.is_truthy(err:find('payload'))
        end)

        it('rejects non-table opts', function()
            local event, err = events.make_envelope('run-1', 'run.created', {}, 'opts')
            assert.is_nil(event)
            assert.is_truthy(err:find('opts'))
        end)

        it('stores nothing when envelope validation fails', function()
            local event, err = sink:append('run-1', 'bogus.kind', {})
            assert.is_nil(event)
            assert.is_truthy(err)
            assert.are.equal(0, sink:count())
            assert.are.equal(0, #sink:events())
        end)

        it('stays usable after a failed append', function()
            local bad = sink:append('run-1', 'bogus.kind', {})
            assert.is_nil(bad)
            local good = sink:append('run-1', 'run.created', {})
            assert.is_truthy(good)
            assert.are.equal(1, sink:count())
        end)
    end)
end)
