-- tests/busted/unit/approval_spec.lua
-- Spec for ai.harness.approval: async human approval queue.
-- 6 validation + 6 adversarial = 12 tests.
-- Run from repo root: busted --run=unit tests/busted/unit/approval_spec.lua

local approval = require('ai.harness.approval')
local types = require('ai.harness.types')

local function make_request(queue, overrides)
    local request = { tool = 'fs.write', risk = 'irreversible', summary = 'write file' }
    local opts = nil
    if overrides then
        if overrides.request then
            for k, v in pairs(overrides.request) do
                request[k] = v
            end
        end
        opts = overrides.opts
    end
    return assert(approval.request(queue, 'run-1', request, opts))
end

describe('ai.harness.approval', function()
    local queue

    before_each(function()
        queue = approval.new()
    end)

    describe('validation', function()
        it('creates a pending approval retrievable by id', function()
            local id = make_request(queue)
            assert.is_truthy(id:match('^approval%-'))
            local got = approval.get(queue, id)
            assert.is_truthy(got)
            assert.are.equal('pending', got.state)
            assert.are.equal('run-1', got.run_id)
            assert.are.equal('fs.write', got.tool)
            assert.are.equal('irreversible', got.risk)
        end)

        it('records an approval decision with the decider', function()
            local id = make_request(queue)
            assert.is_true(approval.decide(queue, id, 'approved', 'matt'))
            local got = approval.get(queue, id)
            assert.are.equal('approved', got.state)
            assert.are.equal('matt', got.decided_by)
        end)

        it('records a denial', function()
            local id = make_request(queue)
            assert.is_true(approval.decide(queue, id, 'denied'))
            assert.are.equal('denied', approval.get(queue, id).state)
        end)

        it('lists pending approvals oldest first, excluding decided ones', function()
            local id1 = make_request(queue)
            local id2 = make_request(queue)
            approval.decide(queue, id1, 'denied')
            local pending = approval.pending(queue)
            assert.are.equal(1, #pending)
            assert.are.equal(id2, pending[1].id)
        end)

        it('expires overdue requests to expired via sweep', function()
            local id = make_request(queue, { opts = { timeout_ms = 1000 } })
            local got = approval.get(queue, id)
            local expired = approval.sweep_expired(queue, got.deadline_ns + 1)
            assert.are.equal(1, expired)
            assert.are.equal('expired', approval.get(queue, id).state)
            assert.are.equal(0, #approval.pending(queue))
        end)

        it('stamps a deadline after creation by default', function()
            local id = make_request(queue)
            local got = approval.get(queue, id)
            assert.is_true(got.deadline_ns > got.created_ns)
            assert.is_true(got.deadline_ns > types.now_ns() - 2000000000)
        end)
    end)

    describe('adversarial', function()
        it('rejects deciding an unknown id', function()
            local ok, err = approval.decide(queue, 'approval-nope', 'approved')
            assert.is_nil(ok)
            assert.is_truthy(err:find('unknown approval id'))
        end)

        it('rejects deciding twice', function()
            local id = make_request(queue)
            assert.is_true(approval.decide(queue, id, 'approved'))
            local ok, err = approval.decide(queue, id, 'denied')
            assert.is_nil(ok)
            assert.is_truthy(err:find('already approved'))
        end)

        it('rejects a bad decision string', function()
            local id = make_request(queue)
            local ok, err = approval.decide(queue, id, 'maybe')
            assert.is_nil(ok)
            assert.is_truthy(err:find('approved'))
        end)

        it('rejects new requests when the queue is full', function()
            for _ = 1, 128 do
                make_request(queue)
            end
            local id, err = approval.request(queue, 'run-1', { tool = 'fs.write', risk = 'observe' })
            assert.is_nil(id)
            assert.is_truthy(err:find('full'))
        end)

        it('rejects zero or negative timeouts', function()
            local id, err = approval.request(
                queue,
                'run-1',
                { tool = 'fs.write', risk = 'observe' },
                { timeout_ms = 0 }
            )
            assert.is_nil(id)
            assert.is_truthy(err:find('positive'))
        end)

        it('returns nil for unknown ids and expires nothing early', function()
            local id = make_request(queue, { opts = { timeout_ms = 60000 } })
            assert.is_nil(approval.get(queue, 'approval-nope'))
            local got = approval.get(queue, id)
            assert.are.equal(0, approval.sweep_expired(queue, got.deadline_ns - 1))
            assert.are.equal('pending', approval.get(queue, id).state)
        end)
    end)
end)
