-- tests/busted/unit/context_spec.lua
-- Spec for ai.harness.context: immutable budgeted context snapshots.
-- 6 validation + 6 adversarial = 12 tests.
-- Run from repo root: busted --run=unit tests/busted/unit/context_spec.lua

local context = require('ai.harness.context')

local function item(overrides)
    local it = { kind = 'note', bytes = 10, hash = 'h1', trust = 'workspace', data = 'x' }
    if overrides then
        for k, v in pairs(overrides) do
            it[k] = v
        end
    end
    return it
end

local function provider(name, priority, items_or_fn)
    local produce = items_or_fn
    if type(produce) ~= 'function' then
        produce = function()
            return items_or_fn
        end
    end
    return assert(context.new_provider(name, priority, produce))
end

describe('ai.harness.context', function()
    local snap

    before_each(function()
        snap = assert(context.new_snapshot('/workspace'))
    end)

    describe('validation', function()
        it('attaches provider items stamped with provider and priority', function()
            local p = provider('docs', context.PRIORITY.task_local, { item() })
            assert.is_true(context.attach(snap, p))
            assert.are.equal(1, #snap.items)
            assert.are.equal('docs', snap.items[1].provider)
            assert.are.equal(context.PRIORITY.task_local, snap.items[1].priority)
        end)

        it('accepts a provider that returns nil', function()
            local p = provider('empty', context.PRIORITY.diagnostics, nil)
            assert.is_true(context.attach(snap, p))
            assert.are.equal(0, #snap.items)
        end)

        it('seals the snapshot against further attaches', function()
            local p = provider('docs', context.PRIORITY.task_local, { item() })
            context.seal(snap)
            assert.is_true(snap.sealed)
            local ok, err = context.attach(snap, p)
            assert.is_nil(ok)
            assert.is_truthy(err:find('sealed'))
        end)

        it('budgets required instructions before retrieved context', function()
            context.attach(snap, provider('web', context.PRIORITY.retrieved, { item({ kind = 'b' }) }))
            context.attach(snap, provider('sys', context.PRIORITY.required, { item({ kind = 'a' }) }))
            local kept, dropped = context.budget(snap, 10)
            assert.are.equal(1, #kept)
            assert.are.equal(1, dropped)
            assert.are.equal('sys', kept[1].provider)
        end)

        it('keeps everything that fits within max_bytes', function()
            context.attach(snap, provider('a', context.PRIORITY.required, { item({ bytes = 5 }) }))
            context.attach(snap, provider('b', context.PRIORITY.retrieved, { item({ bytes = 5 }) }))
            local kept, dropped = context.budget(snap, 10)
            assert.are.equal(2, #kept)
            assert.are.equal(0, dropped)
        end)

        it('emits a metadata-only manifest without item data', function()
            context.attach(snap, provider('docs', context.PRIORITY.task_local, { item() }))
            local m = context.manifest(snap)
            assert.are.equal('/workspace', m.workspace)
            assert.are.equal(10, m.total_bytes)
            assert.are.equal(1, #m.items)
            assert.is_nil(m.items[1].data)
            assert.are.equal('docs', m.items[1].provider)
            assert.are.equal('note', m.items[1].kind)
        end)
    end)

    describe('adversarial', function()
        it('rejects an empty workspace', function()
            local s, err = context.new_snapshot('')
            assert.is_nil(s)
            assert.is_truthy(err:find('workspace'))
        end)

        it('rejects a provider returning garbage', function()
            local p = provider('junk', context.PRIORITY.required, 'junk')
            local ok, err = context.attach(snap, p)
            assert.is_nil(ok)
            assert.is_truthy(err:find('table or nil'))
        end)

        it('rejects items with a bad trust class', function()
            local p = provider('shady', context.PRIORITY.retrieved, { item({ trust = 'mostly' }) })
            local ok, err = context.attach(snap, p)
            assert.is_nil(ok)
            assert.is_truthy(err:find('trust'))
        end)

        it('captures a provider that raises', function()
            local p = provider('boom', context.PRIORITY.required, function()
                error('kaput')
            end)
            local ok, err = context.attach(snap, p)
            assert.is_nil(ok)
            assert.is_truthy(err:find('raised'))
        end)

        it('rejects a negative max_bytes budget', function()
            assert.has_error(function()
                context.budget(snap, -1)
            end)
        end)

        it('rejects an unknown provider priority', function()
            local p, err = context.new_provider('odd', 99, function() end)
            assert.is_nil(p)
            assert.is_truthy(err:find('priority'))
        end)
    end)
end)
