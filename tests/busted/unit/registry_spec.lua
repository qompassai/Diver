-- tests/busted/unit/registry_spec.lua
-- Spec for ai.harness.registry: explicit adapter/tool/workflow registry.
-- 6 validation + 6 adversarial = 12 tests.
-- Run from repo root: busted --run=unit tests/busted/unit/registry_spec.lua

local registry = require('ai.harness.registry')

local function fake_adapter()
    return {
        probe = function()
            return {}
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

describe('ai.harness.registry', function()
    local reg

    before_each(function()
        reg = registry.new()
    end)

    describe('validation', function()
        it('registers and retrieves an adapter', function()
            local a = fake_adapter()
            assert.is_true(registry.register_adapter(reg, 'acme', a))
            assert.are.equal(a, registry.get_adapter(reg, 'acme'))
        end)

        it('lists adapters in sorted order', function()
            registry.register_adapter(reg, 'zeta', fake_adapter())
            registry.register_adapter(reg, 'alpha', fake_adapter())
            registry.register_adapter(reg, 'mid', fake_adapter())
            assert.are.same({ 'alpha', 'mid', 'zeta' }, registry.list_adapters(reg))
        end)

        it('registers and lists tools', function()
            assert.is_true(registry.register_tool(reg, 'fs_read', { description = 'read a file' }))
            assert.are.equal('read a file', registry.get_tool(reg, 'fs_read').description)
            registry.register_tool(reg, 'abc', { description = 'abc' })
            assert.are.same({ 'abc', 'fs_read' }, registry.list_tools(reg))
        end)

        it('registers and retrieves a workflow', function()
            assert.is_true(registry.register_workflow(reg, 'review', { adapter = 'acp' }))
            assert.are.equal('acp', registry.get_workflow(reg, 'review').adapter)
        end)

        it('loads the six built-in protocol adapters', function()
            assert.is_true(registry.register_builtins(reg))
            local names = registry.list_adapters(reg)
            assert.are.same({ 'a2a', 'acp', 'herd', 'mcp', 'phlow', 'rose' }, names)
        end)

        it('exposes usable probe/start/cancel/close on builtins', function()
            assert.is_true(registry.register_builtins(reg))
            local a = registry.get_adapter(reg, 'phlow')
            assert.is_true(type(a.probe) == 'function')
            assert.is_true(type(a.start) == 'function')
            assert.is_true(type(a.cancel) == 'function')
            assert.is_true(type(a.close) == 'function')
        end)
    end)

    describe('adversarial', function()
        it('rejects duplicate adapter registration', function()
            assert.is_true(registry.register_adapter(reg, 'dup', fake_adapter()))
            local ok, err = registry.register_adapter(reg, 'dup', fake_adapter())
            assert.is_nil(ok)
            assert.is_truthy(err:find('already registered'))
        end)

        it('rejects bad names: uppercase, dashes, empty', function()
            for _, bad in ipairs({ 'Upper', 'with-dash', '', 'has space' }) do
                local ok, err = registry.register_adapter(reg, bad, fake_adapter())
                assert.is_nil(ok, bad)
                assert.is_truthy(err:find('name'), bad)
            end
        end)

        it('rejects an adapter missing the cancel function', function()
            local a = fake_adapter()
            a.cancel = nil
            local ok, err = registry.register_adapter(reg, 'nocancel', a)
            assert.is_nil(ok)
            assert.is_truthy(err:find('cancel'))
        end)

        it('returns nil for unknown adapter, tool, and workflow names', function()
            assert.is_nil(registry.get_adapter(reg, 'missing'))
            assert.is_nil(registry.get_tool(reg, 'missing'))
            assert.is_nil(registry.get_workflow(reg, 'missing'))
        end)

        it('rejects tool definitions without a description', function()
            local ok, err = registry.register_tool(reg, 'badt', {})
            assert.is_nil(ok)
            assert.is_truthy(err:find('description'))
            local ok2, err2 = registry.register_tool(reg, 'badt2', 'desc')
            assert.is_nil(ok2)
            assert.is_truthy(err2)
        end)

        it('rejects workflows without a string adapter', function()
            local ok, err = registry.register_workflow(reg, 'badw', {})
            assert.is_nil(ok)
            assert.is_truthy(err:find('adapter'))
        end)
    end)
end)
