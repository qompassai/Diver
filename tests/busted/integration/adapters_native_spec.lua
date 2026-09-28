-- tests/busted/integration/adapters_native_spec.lua
-- Native harness adapter contract checks (Tiger Style).
-- 6 validation (probe shape) + 6 adversarial (start rejection).
-- Deterministic, no network. Probe shape only: available may be false
-- outside Neovim and is never asserted true. Tagged #integration.

local types = require('ai.harness.types')

local ADAPTERS = { 'acp', 'a2a', 'mcp', 'phlow', 'rose', 'herd' }

local function load(name)
    local ok, mod = pcall(require, 'ai.harness.adapters.' .. name)
    assert(ok, 'adapter failed to load: ' .. name .. ': ' .. tostring(mod))
    return mod
end

describe('adapter probe shape #integration', function()
    for _, name in ipairs(ADAPTERS) do
        it('probe ' .. name .. ' returns the full capability shape #integration', function()
            local adapter = load(name)
            assert(type(adapter.name) == 'string' and adapter.name == name)
            local caps = adapter.probe()
            assert(type(caps) == 'table', name .. ' probe must return a table')
            assert(type(caps.available) == 'boolean', name .. ' available must be boolean')
            for _, key in ipairs(types.CAPABILITY_KEYS) do
                local msg = name .. ' capability ' .. key .. ' must be boolean'
                assert(type(caps[key]) == 'boolean', msg)
            end
        end)
    end
end)

describe('adapter start rejection #integration', function()
    it('acp start requires extensions.acp.agent #integration', function()
        local adapter = load('acp')
        local handle, err = adapter.start({ id = 'r-acp', extensions = {} }, {})
        assert(handle == nil)
        assert(err:find('extensions.acp.agent', 1, true) ~= nil)
    end)

    it('a2a start requires extensions.a2a.agent #integration', function()
        local adapter = load('a2a')
        local handle, err = adapter.start({ id = 'r-a2a', extensions = {} }, {})
        assert(handle == nil)
        assert(err:find('extensions.a2a.agent', 1, true) ~= nil)
    end)

    it('mcp start requires extensions.mcp.server #integration', function()
        local adapter = load('mcp')
        local handle, err = adapter.start({ id = 'r-mcp', extensions = {} }, {})
        assert(handle == nil)
        assert(err:find('extensions.mcp.server', 1, true) ~= nil)
    end)

    it('rose start requires extensions.rose.config #integration', function()
        local adapter = load('rose')
        local handle, err = adapter.start({ id = 'r-rose', extensions = {} }, {})
        assert(handle == nil)
        assert(err:find('extensions.rose.config', 1, true) ~= nil)
    end)

    it('phlow start declines as Phase 6 work #integration', function()
        local adapter = load('phlow')
        local handle, err = adapter.start({ id = 'r-phlow', extensions = {} }, {})
        assert(handle == nil)
        assert(err:find('Phase 6', 1, true) ~= nil)
    end)

    it('herd start declines without a usable worker backend #integration', function()
        local adapter = load('herd')
        local ok, handle, err = pcall(adapter.start, { id = 'r-herd', extensions = {} }, {})
        assert(ok == true, 'herd start must not raise, got: ' .. tostring(handle))
        assert(handle == nil, 'herd start must decline outside Neovim')
        assert(type(err) == 'string' and #err > 0, 'herd start must explain the decline')
        assert(err:find('herd', 1, true) ~= nil)
    end)
end)
