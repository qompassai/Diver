-- tests/busted/unit/init_spec.lua
-- Busted unit specs for the ai.harness public API (Tiger Style).
-- 6 validation + 6 adversarial. Deterministic, no network.
-- The stub adapter is registered into harness state via the module-local
-- M._state test seam; real builtin adapters stay registered but unused.

local harness = require('ai.harness')
local registry = require('ai.harness.registry')
local supervisor = require('ai.harness.supervisor')

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

local function spec(overrides)
    local s = { workflow = 'code.change', goal = 'do the thing', workspace = '/tmp/ws' }
    if overrides then
        for k, v in pairs(overrides) do
            s[k] = v
        end
    end
    return s
end

---Ensure harness state exists and the stub adapter is registered.
local function ensure_harness()
    if harness._state == nil then
        assert(harness.setup())
    end
    local reg = harness._state.registry
    if registry.get_adapter(reg, 'stub') == nil then
        assert(registry.register_adapter(reg, 'stub', stub_adapter('stub', test_caps())))
    end
    return harness._state
end

local function run_via_api()
    local st = ensure_harness()
    local id, err = harness.run(spec({ adapter = 'stub' }))
    assert(id ~= nil, err)
    return id, st
end

describe('harness setup', function()
    it('setup initializes state with all collaborators', function()
        assert(harness.setup())
        local st = harness._state
        assert(st ~= nil)
        assert(st.sink ~= nil and st.registry ~= nil)
        assert(st.supervisor ~= nil and st.policy ~= nil)
    end)

    it('double setup keeps the first state', function()
        assert(harness.setup())
        local first = harness._state
        assert(harness.setup())
        assert(harness._state == first, 'second setup must not replace state')
    end)

    it('version reports the harness version', function()
        assert(harness.version() == '0.1.0')
    end)
end)

describe('harness run lifecycle', function()
    it('run starts a run through the public API', function()
        local id, st = run_via_api()
        local run = supervisor.get(st.supervisor, id)
        assert(run ~= nil)
        assert(run.state == 'running')
    end)

    it('cancel cancels a live run through the public API', function()
        local id, st = run_via_api()
        local ok, err = harness.cancel(id, 'test')
        assert(ok, err)
        assert(supervisor.get(st.supervisor, id).state == 'cancelled')
    end)

    it('resume re-queues a cancelled run through the public API', function()
        local id, st = run_via_api()
        assert(harness.cancel(id))
        local ok, err = harness.resume(id)
        assert(ok, err)
        local run = supervisor.get(st.supervisor, id)
        assert(run.state == 'running')
        assert(run.attempt == 2)
    end)
end)

describe('harness adversarial', function()
    it('run before setup is rejected', function()
        local saved = harness._state
        harness._state = nil
        local id, err = harness.run(spec({ adapter = 'stub' }))
        harness._state = saved
        assert(id == nil)
        assert(err:find('harness not set up', 1, true) ~= nil)
    end)

    it('run with a bad spec is rejected', function()
        ensure_harness()
        local id, err = harness.run({})
        assert(id == nil)
        assert(err:find('run spec.workflow', 1, true) ~= nil)
    end)

    it('cancel of an unknown run is rejected', function()
        ensure_harness()
        local ok, err = harness.cancel('nope')
        assert(ok == nil)
        assert(err:find('unknown run', 1, true) ~= nil)
    end)

    it('resume of a non-terminal run is rejected', function()
        local id = run_via_api()
        local ok, err = harness.resume(id)
        assert(ok == nil)
        assert(err:find('resume requires a terminal run', 1, true) ~= nil)
    end)

    it('setup with bad opts is rejected', function()
        local saved = harness._state
        harness._state = nil
        local ok, err = harness.setup('nope')
        harness._state = saved
        assert(ok == nil)
        assert(err:find('setup opts must be a table', 1, true) ~= nil)
    end)

    it('run with an unknown adapter is rejected', function()
        ensure_harness()
        local id, err = harness.run(spec({ adapter = 'nope' }))
        assert(id == nil)
        assert(err:find('unknown adapter', 1, true) ~= nil)
    end)
end)
