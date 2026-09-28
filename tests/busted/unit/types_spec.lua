-- tests/busted/unit/types_spec.lua
-- Spec for ai.harness.types: canonical contracts (run states, transitions,
-- validators, id/timestamp helpers, run-spec validation).
-- 8 validation + 8 adversarial = 16 tests.
-- Run from repo root: busted --run=unit tests/busted/unit/types_spec.lua

local types = require('ai.harness.types')

describe('ai.harness.types', function()
    describe('validation', function()
        it('accepts every edge listed in the TRANSITIONS table', function()
            local edges = 0
            for from, tos in pairs(types.TRANSITIONS) do
                for _, to in ipairs(tos) do
                    edges = edges + 1
                    assert.is_true(types.can_transition(from, to), from .. ' -> ' .. to)
                end
            end
            assert.is_true(edges > 0)
        end)

        it('marks the five terminal states and nothing else', function()
            for _, state in ipairs({ 'completed', 'failed', 'cancelled', 'timed_out', 'interrupted' }) do
                assert.is_true(types.is_terminal(state), state)
            end
            for _, state in ipairs({ 'created', 'queued', 'running', 'waiting_input', 'waiting_approval', 'retry_wait' }) do
                assert.is_false(types.is_terminal(state), state)
            end
        end)

        it('accepts valid states, event kinds, risks, and budget kinds', function()
            assert.is_true(types.is_valid_state('running'))
            assert.is_true(types.is_valid_event_kind('run.created'))
            assert.is_true(types.is_valid_event_kind('tool.approval_requested'))
            assert.is_true(types.is_valid_risk('irreversible'))
            assert.is_true(types.is_valid_budget_kind('token'))
            assert.is_true(types.is_valid_budget_kind('cost'))
        end)

        it('generates unique ids with the expected shape', function()
            local seen = {}
            for _ = 1, 100 do
                local id = types.new_id('run')
                assert.is_truthy(id:match('^run%-%d+%-%d+%-%d%d%d%d%d%d$'), id)
                assert.is_nil(seen[id])
                seen[id] = true
            end
        end)

        it('returns a non-decreasing nanosecond clock', function()
            local prev = types.now_ns()
            assert.is_true(type(prev) == 'number')
            for _ = 1, 10 do
                local now = types.now_ns()
                assert.is_true(now >= prev)
                prev = now
            end
        end)

        it('accepts a minimal valid run spec', function()
            local ok, err = types.validate_run_spec({
                workflow = 'code_review',
                goal = 'review the diff',
                workspace = '/workspace',
            })
            assert.is_true(ok, tostring(err))
        end)

        it('accepts a run spec with every optional field', function()
            local ok, err = types.validate_run_spec({
                workflow = 'code_review',
                goal = 'review the diff',
                workspace = '/workspace',
                adapter = 'acp',
                timeout_ms = 60000,
                budget = { turn = 10 },
                extensions = { acp = {} },
                acceptance = { checks = 'pass' },
            })
            assert.is_true(ok, tostring(err))
        end)

        it('only transitions into known states', function()
            for _, to in ipairs(types.TRANSITIONS.running) do
                assert.is_true(types.is_valid_state(to), to)
            end
        end)
    end)

    describe('adversarial', function()
        it('rejects a non-table spec', function()
            local ok, err = types.validate_run_spec('nope')
            assert.is_nil(ok)
            assert.is_truthy(err)
        end)

        it('rejects a spec missing workflow', function()
            local ok, err = types.validate_run_spec({ goal = 'g', workspace = '/w' })
            assert.is_nil(ok)
            assert.is_truthy(err:find('workflow'))
        end)

        it('rejects a spec with an empty goal', function()
            local ok, err = types.validate_run_spec({ workflow = 'w', goal = '', workspace = '/w' })
            assert.is_nil(ok)
            assert.is_truthy(err:find('goal'))
        end)

        it('rejects non-positive timeout_ms', function()
            for _, bad in ipairs({ 0, -5 }) do
                local ok, err = types.validate_run_spec({
                    workflow = 'w',
                    goal = 'g',
                    workspace = '/w',
                    timeout_ms = bad,
                })
                assert.is_nil(ok, tostring(bad))
                assert.is_truthy(err:find('timeout_ms'))
            end
        end)

        it('rejects a non-table budget', function()
            local ok, err = types.validate_run_spec({
                workflow = 'w',
                goal = 'g',
                workspace = '/w',
                budget = 42,
            })
            assert.is_nil(ok)
            assert.is_truthy(err:find('budget'))
        end)

        it('rejects an empty-string adapter', function()
            local ok, err = types.validate_run_spec({
                workflow = 'w',
                goal = 'g',
                workspace = '/w',
                adapter = '',
            })
            assert.is_nil(ok)
            assert.is_truthy(err:find('adapter'))
        end)

        it('rejects non-edges and unknown states in can_transition', function()
            assert.is_false(types.can_transition('created', 'running'))
            assert.is_false(types.can_transition('completed', 'completed'))
            assert.is_false(types.can_transition('running', 'created'))
            assert.is_false(types.can_transition('bogus', 'running'))
            assert.is_false(types.can_transition('running', 'bogus'))
        end)

        it('asserts on an empty or non-string new_id prefix', function()
            assert.has_error(function()
                types.new_id('')
            end)
            assert.has_error(function()
                types.new_id(42)
            end)
        end)
    end)
end)
