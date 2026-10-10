-- tests/busted/unit/registry_spec.lua
-- Spec for ai.harness.registry: explicit adapter/tool/workflow registry.
-- 9 validation + 13 adversarial = 22 tests.
-- Run from repo root: busted --run=unit tests/busted/unit/registry_spec.lua

local registry = require('ai.harness.registry')

local function fake_tool(extra)
    local def = {
        description = 'fake tool',
        input_schema = { path = { required = true, type = 'string' } },
        run = function()
            return {}
        end,
    }
    if extra then
        for k, v in pairs(extra) do
            def[k] = v
        end
    end
    return def
end

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
            assert.is_true(registry.register_tool(reg, 'fs_read', fake_tool({ description = 'read a file' })))
            assert.are.equal('read a file', registry.get_tool(reg, 'fs_read').description)
            registry.register_tool(reg, 'abc', fake_tool({ description = 'abc' }))
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

        it('lists workflows in sorted order', function()
            registry.register_workflow(reg, 'zeta_flow', { adapter = 'acp' })
            registry.register_workflow(reg, 'alpha_flow', { adapter = 'mcp' })
            assert.are.same({ 'alpha_flow', 'zeta_flow' }, registry.list_workflows(reg))
        end)

        it('registers no builtin tools from the default list', function()
            assert.is_true(registry.register_builtin_tools(reg))
            assert.are.same({}, registry.list_tools(reg))
        end)

        it('registers a builtin tool from a stubbed module', function()
            package.loaded['ai.harness.tools.stub_echo'] = fake_tool({ description = 'stub echo' })
            local ok, err = registry.register_builtin_tools(reg, { 'stub_echo' })
            package.loaded['ai.harness.tools.stub_echo'] = nil
            assert.is_true(ok, err)
            assert.are.equal('stub echo', registry.get_tool(reg, 'stub_echo').description)
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

        it('rejects tool definitions without a run function', function()
            local def = fake_tool()
            def.run = nil
            local ok, err = registry.register_tool(reg, 'norun', def)
            assert.is_nil(ok)
            assert.is_truthy(err:find('run'))
            local def2 = fake_tool({ run = 'not a function' })
            local ok2, err2 = registry.register_tool(reg, 'norun2', def2)
            assert.is_nil(ok2)
            assert.is_truthy(err2:find('run'))
        end)

        it('rejects tool definitions without an input_schema', function()
            local def = fake_tool()
            def.input_schema = nil
            local ok, err = registry.register_tool(reg, 'noschema', def)
            assert.is_nil(ok)
            assert.is_truthy(err:find('input_schema'))
            local def2 = fake_tool({ input_schema = 'path' })
            local ok2, err2 = registry.register_tool(reg, 'noschema2', def2)
            assert.is_nil(ok2)
            assert.is_truthy(err2:find('input_schema'))
        end)

        it('rejects duplicate tool registration', function()
            assert.is_true(registry.register_tool(reg, 'duptool', fake_tool()))
            local ok, err = registry.register_tool(reg, 'duptool', fake_tool())
            assert.is_nil(ok)
            assert.is_truthy(err:find('already registered'))
        end)

        it('rejects workflows without a string adapter', function()
            local ok, err = registry.register_workflow(reg, 'badw', {})
            assert.is_nil(ok)
            assert.is_truthy(err:find('adapter'))
        end)

        it('rejects workflow registrations past the registry cap', function()
            for i = 1, 256 do
                assert.is_true(registry.register_workflow(reg, 'wf' .. i, { adapter = 'acp' }))
            end
            local ok, err = registry.register_workflow(reg, 'wf257', { adapter = 'acp' })
            assert.is_nil(ok)
            assert.is_truthy(err:find('full'))
        end)

        it('rejects a builtin tool whose module fails to load', function()
            local ok, err = registry.register_builtin_tools(reg, { 'no_such_tool' })
            assert.is_nil(ok)
            assert.is_truthy(err:find('failed to load'))
        end)

        it('rejects a builtin tool module returning an unrunnable def', function()
            package.loaded['ai.harness.tools.stub_broken'] = { description = 'no run here' }
            local ok, err = registry.register_builtin_tools(reg, { 'stub_broken' })
            package.loaded['ai.harness.tools.stub_broken'] = nil
            assert.is_nil(ok)
            assert.is_truthy(err:find('run'))
            assert.is_nil(registry.get_tool(reg, 'stub_broken'))
        end)

        it('rejects a builtin tool that is already registered', function()
            package.loaded['ai.harness.tools.stub_echo'] = fake_tool()
            assert.is_true(registry.register_tool(reg, 'stub_echo', fake_tool()))
            local ok, err = registry.register_builtin_tools(reg, { 'stub_echo' })
            package.loaded['ai.harness.tools.stub_echo'] = nil
            assert.is_nil(ok)
            assert.is_truthy(err:find('already registered'))
        end)
    end)
end)
