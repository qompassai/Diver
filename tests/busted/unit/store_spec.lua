-- tests/busted/unit/store_spec.lua
-- Busted unit specs for ai.harness.store (Tiger Style).
-- 6 validation + 6 adversarial. Deterministic, no network.

local store = require('ai.harness.store')

local function sample_run(id, state)
        return {
                id = id,
                state = state or 'running',
                nested = {
                        x = 1,
                },
                budget = {
                        limits = {},
                        used = {},
                },
        }
end

describe('store runs', function()
        it('saves and gets a run roundtrip', function()
                local st = store.new()
                local run = sample_run('r1', 'running')
                assert(store.save_run(st, run))
                local got = store.get_run(st, 'r1')
                assert(got ~= nil)
                assert(got.id == 'r1')
                assert(got.state == 'running')
                assert(got.nested.x == 1)
        end)

        it('lists run ids in sorted order', function()
                local st = store.new()
                assert(store.save_run(st, sample_run('r-b')))
                assert(store.save_run(st, sample_run('r-a')))
                assert(store.save_run(st, sample_run('r-c')))
                local ids = store.list_runs(st)
                assert(#ids == 3)
                assert(ids[1] == 'r-a' and ids[2] == 'r-b' and ids[3] == 'r-c')
        end)

        it('checkpoints roundtrip with label and timestamp', function()
                local st = store.new()
                assert(store.save_run(st, sample_run('r1', 'waiting_input')))
                assert(store.checkpoint(st, 'r1', 'pre-tool'))
                local cp = store.get_checkpoint(st, 'r1', 'pre-tool')
                assert(cp ~= nil)
                assert(cp.label == 'pre-tool')
                assert(type(cp.at_ns) == 'number')
                assert(cp.state.id == 'r1')
                assert(cp.state.state == 'waiting_input')
        end)

        it('mark_interrupted marks only non-terminal runs', function()
                local st = store.new()
                assert(store.save_run(st, sample_run('r1', 'running')))
                assert(store.save_run(st, sample_run('r2', 'completed')))
                assert(store.save_run(st, sample_run('r3', 'waiting_approval')))
                local marked = store.mark_interrupted(st)
                assert(marked == 2)
                assert(store.get_run(st, 'r1').state == 'interrupted')
                assert(store.get_run(st, 'r2').state == 'completed')
                assert(store.get_run(st, 'r3').state == 'interrupted')
        end)

        it('artifacts dedup by content hash', function()
                local st = store.new()
                local h1 = assert(store.put_artifact(st, 'hello bytes'))
                local h2 = assert(store.put_artifact(st, 'hello bytes'))
                assert(h1 == h2)
                assert(st.artifact_count == 1)
                assert(store.get_artifact(st, h1) == 'hello bytes')
                local h3 = assert(store.put_artifact(st, 'different bytes'))
                assert(h3 ~= h1)
                assert(st.artifact_count == 2)
        end)

        it('get_run returns a copy isolated from later reads', function()
                local st = store.new()
                assert(store.save_run(st, sample_run('r1')))
                local got = store.get_run(st, 'r1')
                got.nested.x = 999
                got.state = 'completed'
                local again = store.get_run(st, 'r1')
                assert(again.nested.x == 1)
                assert(again.state == 'running')
        end)
end)

describe('store adversarial', function()
        it('rejects oversized artifacts', function()
                local st = store.new()
                local hash, err = store.put_artifact(st, string.rep('x', 10000001))
                assert(hash == nil)
                assert(err:find('exceeds size bound', 1, true) ~= nil)
        end)

        it('rejects saving a run without an id', function()
                local st = store.new()
                local ok, err = store.save_run(st, { state = 'running' })
                assert(ok == nil)
                assert(err:find('must be a table with an id', 1, true) ~= nil)
                local ok2, err2 = store.save_run(st, 'not-a-table')
                assert(ok2 == nil)
                assert(err2 ~= nil)
        end)

        it('rejects checkpointing an unknown run', function()
                local st = store.new()
                local ok, err = store.checkpoint(st, 'nope', 'label')
                assert(ok == nil)
                assert(err:find('unknown run', 1, true) ~= nil)
        end)

        it('get on missing keys returns nil', function()
                local st = store.new()
                assert(store.get_run(st, 'nope') == nil)
                assert(store.get_checkpoint(st, 'nope', 'label') == nil)
                assert(store.get_artifact(st, 'sha256:deadbeef') == nil)
        end)

        it('stored copy is isolated from caller mutation after save', function()
                local st = store.new()
                local run = sample_run('r1')
                assert(store.save_run(st, run))
                run.nested.x = 42
                run.state = 'failed'
                local got = store.get_run(st, 'r1')
                assert(got.nested.x == 1)
                assert(got.state == 'running')
        end)

        it('rejects an empty checkpoint label', function()
                local st = store.new()
                assert(store.save_run(st, sample_run('r1')))
                local ok, err = store.checkpoint(st, 'r1', '')
                assert(ok == nil)
                assert(err:find('non-empty string', 1, true) ~= nil)
        end)
end)
