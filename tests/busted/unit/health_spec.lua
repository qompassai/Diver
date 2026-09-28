-- tests/busted/unit/health_spec.lua
-- Busted unit specs for ai.harness.health (Tiger Style).
-- 4 validation + 4 adversarial. Deterministic, no network.

local health = require('ai.harness.health')
local registry = require('ai.harness.registry')
local store = require('ai.harness.store')

local function stub_adapter(name, caps)
    local gen = 0
    local adapter = {}
    adapter.name = name
    adapter.probe = function()
        return caps
    end
    adapter.start = function(run, _sink)
        gen = gen + 1
        return { adapter = name, generation = gen, run_id = run.id, closed = false }
    end
    adapter.cancel = function(handle, reason)
        handle.cancel_reason = reason
        return true
    end
    adapter.close = function(handle)
        handle.closed = true
    end
    return adapter
end

local function test_caps(extra)
    local caps = {
        available = true,
        streaming = false,
        cancellation = true,
        resume = false,
        permissions = false,
        artifacts = false,
        remote = false,
        tools = false,
        wired_start = true,
    }
    if extra then
        for k, v in pairs(extra) do
            caps[k] = v
        end
    end
    return caps
end

local function ctx_with_stub()
    local reg = registry.new()
    assert(registry.register_adapter(reg, 'stub', stub_adapter('stub', test_caps())))
    return { registry = reg, store = store.new() }, reg
end

describe('health', function()
    it('reports the runtime, adapters, storage, and sandbox shape', function()
        local ctx = ctx_with_stub()
        local report = health.check(ctx)
        assert(report.runtime.lua_version == _VERSION)
        assert(report.runtime.has_vim == true)
        assert(report.runtime.has_uv == true)
        assert(report.storage.runs_stored == 0)
        assert(#report.sandbox.profiles == 4)
        local want = { none = true, readonly = true, restricted = true, standard = true }
        for _, name in ipairs(report.sandbox.profiles) do
            assert(want[name] == true, 'unexpected profile ' .. name)
        end
    end)

    it('reports a probed stub adapter as available and wired', function()
        local ctx = ctx_with_stub()
        local report = health.check(ctx)
        local entry = report.adapters.stub
        assert(entry ~= nil)
        assert(entry.available == true)
        assert(entry.wired_start == true)
    end)

    it('counts stored runs', function()
        local ctx = ctx_with_stub()
        assert(store.save_run(ctx.store, { id = 'r1', state = 'running' }))
        assert(store.save_run(ctx.store, { id = 'r2', state = 'completed' }))
        local report = health.check(ctx)
        assert(report.storage.runs_stored == 2)
    end)

    it('lists sandbox profiles sorted', function()
        local ctx = ctx_with_stub()
        local report = health.check(ctx)
        local profiles = report.sandbox.profiles
        assert(profiles[1] == 'none')
        assert(profiles[2] == 'readonly')
        assert(profiles[3] == 'restricted')
        assert(profiles[4] == 'standard')
    end)
end)

describe('health adversarial', function()
    it('handles a nil ctx', function()
        local report = health.check(nil)
        assert(report.runtime.lua_version == _VERSION)
        assert(next(report.adapters) == nil)
        assert(report.storage.runs_stored == 0)
        assert(#report.sandbox.profiles == 4)
    end)

    it('marks an adapter whose probe raises as unavailable', function()
        local ctx, reg = ctx_with_stub()
        local bad = {
            name = 'bad',
            probe = function()
                error('boom')
            end,
            start = function() end,
            cancel = function() end,
            close = function() end,
        }
        assert(registry.register_adapter(reg, 'bad', bad))
        local report = health.check(ctx)
        assert(report.adapters.bad.available == false)
        assert(report.adapters.bad.error:find('probe raised', 1, true) ~= nil)
        assert(report.adapters.stub.available == true)
    end)

    it('tolerates a store without a runs table', function()
        local ctx = ctx_with_stub()
        ctx.store = {}
        local report = health.check(ctx)
        assert(report.storage.runs_stored == 0)
    end)

    it('reports an empty registry with no adapter entries', function()
        local report = health.check({ registry = registry.new(), store = store.new() })
        assert(next(report.adapters) == nil)
    end)
end)
