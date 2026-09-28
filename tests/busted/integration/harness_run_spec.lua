-- tests/busted/integration/harness_run_spec.lua
-- End-to-end harness runs through the public init API (Tiger Style).
-- 8 validation + 8 adversarial. Deterministic, no network.
-- Every name carries the #integration tag; the .busted integration task
-- filters on it.

local harness = require('ai.harness')
local registry = require('ai.harness.registry')
local supervisor = require('ai.harness.supervisor')
local events = require('ai.harness.events')
local types = require('ai.harness.types')

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

local function state()
    if harness._state == nil then
        assert(harness.setup())
    end
    local reg = harness._state.registry
    if registry.get_adapter(reg, 'istub') == nil then
        assert(registry.register_adapter(reg, 'istub', stub_adapter('istub', test_caps())))
    end
    return harness._state
end

local function spec(overrides)
    local s = {
        workflow = 'code.change',
        goal = 'do the thing',
        workspace = '/tmp/ws',
        adapter = 'istub',
    }
    if overrides then
        for k, v in pairs(overrides) do
            s[k] = v
        end
    end
    return s
end

local function start_run(overrides)
    local st = state()
    local id, err = harness.run(spec(overrides))
    assert(id ~= nil, err)
    return id, st
end

local function complete_via_drain(st, run_id, outcome)
    st.sink:append(run_id, 'model.completed', { outcome = outcome or 'completed' }, {})
    supervisor.tick(st.supervisor, types.now_ns())
end

local function count_kind(st, run_id, kind)
    local n = 0
    for _, event in ipairs(st.sink:events(run_id)) do
        if event.kind == kind then
            n = n + 1
        end
    end
    return n
end

describe('harness run lifecycle #integration', function()
    it('runs created -> running -> completed end to end #integration', function()
        local id, st = start_run()
        assert(supervisor.get(st.supervisor, id).state == 'running')
        complete_via_drain(st, id, 'completed')
        assert(supervisor.get(st.supervisor, id).state == 'completed')
        assert(count_kind(st, id, 'run.finished') == 1)
    end)

    it('cancel path settles a run as cancelled #integration', function()
        local id, st = start_run()
        local ok, err = harness.cancel(id, 'user asked')
        assert(ok, err)
        local run = supervisor.get(st.supervisor, id)
        assert(run.state == 'cancelled')
        assert(run.handle.cancel_reason == 'user asked')
    end)

    it('budget exhaustion fails the run via drain #integration', function()
        local id, st = start_run({ budget = { turn = 1 } })
        assert(supervisor.consume(st.supervisor, id, 'turn', 1))
        local ok, err = supervisor.consume(st.supervisor, id, 'turn', 1)
        assert(ok == nil)
        assert(err:find('budget exhausted', 1, true) ~= nil)
        assert(count_kind(st, id, 'budget.exhausted') == 1)
        supervisor.tick(st.supervisor, types.now_ns())
        assert(supervisor.get(st.supervisor, id).state == 'failed')
    end)

    it('an unknown adapter name is rejected at start #integration', function()
        state()
        local id, err = harness.run(spec({ adapter = 'nope' }))
        assert(id == nil)
        assert(err:find('unknown adapter', 1, true) ~= nil)
    end)

    it('a child completes before its parent finishes #integration', function()
        local st = state()
        local parent_id = assert(harness.run(spec()))
        local sup = st.supervisor
        local child, cerr = supervisor.spawn_child(sup, parent_id, spec())
        assert(child ~= nil, cerr)
        assert(supervisor.start_run(sup, child.id, 'istub'))
        complete_via_drain(st, child.id, 'completed')
        assert(supervisor.get(sup, child.id).state == 'completed')
        local ok, ferr = supervisor.finish(sup, parent_id, 'completed')
        assert(ok, ferr)
        assert(supervisor.get(sup, parent_id).state == 'completed')
    end)

    it('resume after cancel re-runs the workflow #integration', function()
        local id, st = start_run()
        assert(harness.cancel(id, 'pause'))
        local ok, err = harness.resume(id)
        assert(ok, err)
        local run = supervisor.get(st.supervisor, id)
        assert(run.state == 'running')
        assert(run.attempt == 2)
        complete_via_drain(st, id, 'completed')
        assert(run.state == 'completed')
    end)

    it('exactly one run.finished is emitted for duplicate completions #integration', function()
        local id, st = start_run()
        st.sink:append(id, 'model.completed', { outcome = 'completed' }, {})
        st.sink:append(id, 'model.completed', { outcome = 'completed' }, {})
        supervisor.tick(st.supervisor, types.now_ns())
        assert(supervisor.get(st.supervisor, id).state == 'completed')
        assert(count_kind(st, id, 'run.finished') == 1)
    end)

    it('check_generation goes stale after cancel #integration', function()
        local id, st = start_run()
        assert(supervisor.check_generation(st.supervisor, id, 0) == true)
        assert(harness.cancel(id))
        assert(supervisor.check_generation(st.supervisor, id, 0) == false)
        assert(supervisor.check_generation(st.supervisor, id, 1) == true)
    end)
end)

describe('harness run adversarial #integration', function()
    it('run with an unknown adapter names the missing adapter #integration', function()
        state()
        local id, err = harness.run(spec({ adapter = 'ghost' }))
        assert(id == nil)
        assert(err:find('unknown adapter', 1, true) ~= nil)
        assert(err:find('ghost', 1, true) ~= nil)
    end)

    it('finishing a parent with a live child is blocked #integration', function()
        local st = state()
        local parent_id = assert(harness.run(spec()))
        local sup = st.supervisor
        local child = assert(supervisor.spawn_child(sup, parent_id, spec()))
        assert(supervisor.start_run(sup, child.id, 'istub'))
        local ok, err = supervisor.finish(sup, parent_id, 'completed')
        assert(ok == nil)
        assert(err:find('parent run owns live children', 1, true) ~= nil)
        assert(supervisor.get(sup, parent_id).state == 'running')
        -- clean up: finish the child so no live run leaks into later tests
        complete_via_drain(st, child.id, 'completed')
        assert(supervisor.finish(sup, parent_id, 'completed'))
    end)

    it('a late model.completed after cancel is ignored #integration', function()
        local id, st = start_run()
        assert(harness.cancel(id, 'stop'))
        st.sink:append(id, 'model.completed', { outcome = 'completed' }, {})
        supervisor.tick(st.supervisor, types.now_ns())
        assert(supervisor.get(st.supervisor, id).state == 'cancelled')
        assert(count_kind(st, id, 'run.finished') == 1)
    end)

    it('double cancel is rejected #integration', function()
        local id = start_run()
        assert(harness.cancel(id))
        local ok, err = harness.cancel(id)
        assert(ok == nil)
        assert(err:find('already terminal', 1, true) ~= nil)
    end)

    it('tick with no runs is a no-op #integration', function()
        local sink = events.new_sink()
        local reg = registry.new()
        local sup, serr = supervisor.new({ registry = reg, sink = sink })
        assert(sup ~= nil, serr)
        assert(supervisor.tick(sup, types.now_ns()) == 0)
        assert(sink:count() == 0)
    end)

    it('unknown run ids are rejected across the API #integration', function()
        local st = state()
        local _, err1 = supervisor.finish(st.supervisor, 'nope', 'completed')
        assert(err1:find('unknown run', 1, true) ~= nil)
        local _, err2 = supervisor.cancel(st.supervisor, 'nope')
        assert(err2:find('unknown run', 1, true) ~= nil)
        local _, err3 = supervisor.resume(st.supervisor, 'nope')
        assert(err3:find('unknown run', 1, true) ~= nil)
        local _, err4 = harness.cancel('nope')
        assert(err4:find('unknown run', 1, true) ~= nil)
        local _, err5 = harness.resume('nope')
        assert(err5:find('unknown run', 1, true) ~= nil)
    end)

    it('resume of a completed run is rejected #integration', function()
        local id, st = start_run()
        complete_via_drain(st, id, 'completed')
        assert(supervisor.get(st.supervisor, id).state == 'completed')
        local ok, err = harness.resume(id)
        assert(ok == nil)
        assert(err:find('invalid transition', 1, true) ~= nil)
    end)

    it('run with an empty spec is rejected #integration', function()
        state()
        local id, err = harness.run({})
        assert(id == nil)
        assert(err:find('run spec.workflow', 1, true) ~= nil)
    end)
end)
