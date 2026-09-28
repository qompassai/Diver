-- tests/busted/unit/supervisor_spec.lua
-- Busted unit specs for ai.harness.supervisor (Tiger Style).
-- 10 validation + 10 adversarial. Deterministic, no network.

local events = require('ai.harness.events')
local registry = require('ai.harness.registry')
local supervisor = require('ai.harness.supervisor')
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

local function new_sup(opts)
    opts = opts or {}
    local sink = events.new_sink()
    local reg = registry.new()
    assert(registry.register_adapter(reg, 'stub', stub_adapter('stub', test_caps())))
    local sup, err = supervisor.new({ registry = reg, sink = sink, runs_max = opts.runs_max })
    assert(sup ~= nil, err)
    return sup, sink, reg
end

local function run_spec(overrides)
    local spec = { workflow = 'code.change', goal = 'do the thing', workspace = '/tmp/ws' }
    if overrides then
        for k, v in pairs(overrides) do
            spec[k] = v
        end
    end
    return spec
end

local function create_started(sup)
    local run = assert(supervisor.create(sup, run_spec()))
    local ok, err = supervisor.start_run(sup, run.id, 'stub')
    assert(ok, err)
    return run
end

local function count_kind(sink, run_id, kind)
    local n = 0
    for _, event in ipairs(sink:events(run_id)) do
        if event.kind == kind then
            n = n + 1
        end
    end
    return n
end

local function sink_append_completed(sink, run_id)
    sink:append(run_id, 'model.completed', { outcome = 'completed' }, {})
end

describe('supervisor lifecycle', function()
    it('creates a run in created state and emits run.created', function()
        local sup, sink = new_sup()
        local run = assert(supervisor.create(sup, run_spec()))
        assert(run.state == 'created')
        assert(type(run.id) == 'string' and #run.id > 0)
        assert(run.attempt == 1)
        assert(run.root_id == run.id)
        assert(run.budget ~= nil)
        assert(count_kind(sink, run.id, 'run.created') == 1)
        assert(#sink:events(run.id) == 1)
    end)

    it('start_run drives created -> queued -> running and emits run.started', function()
        local sup, sink = new_sup()
        local run = assert(supervisor.create(sup, run_spec()))
        local ok, err = supervisor.start_run(sup, run.id, 'stub')
        assert(ok, err)
        assert(run.state == 'running')
        local evts = sink:events(run.id)
        assert(evts[1].kind == 'run.created')
        assert(evts[2].kind == 'run.state_changed')
        assert(evts[2].payload.from == 'created' and evts[2].payload.to == 'queued')
        assert(evts[3].kind == 'run.state_changed')
        assert(evts[3].payload.from == 'queued' and evts[3].payload.to == 'running')
        assert(evts[4].kind == 'run.started')
        assert(evts[4].payload.adapter == 'stub')
    end)

    it('cancel marks the run cancelled, calls adapter.cancel, emits run.finished', function()
        local sup, sink = new_sup()
        local run = create_started(sup)
        local ok, err = supervisor.cancel(sup, run.id, 'user asked')
        assert(ok, err)
        assert(run.state == 'cancelled')
        assert(run.handle.cancel_reason == 'user asked')
        assert(count_kind(sink, run.id, 'run.finished') == 1)
        local finished = nil
        for _, e in ipairs(sink:events(run.id)) do
            if e.kind == 'run.finished' then
                finished = e
            end
        end
        assert(finished.payload.state == 'cancelled')
    end)

    it('resume re-queues a cancelled run with attempt + 1', function()
        local sup = new_sup()
        local run = create_started(sup)
        assert(supervisor.cancel(sup, run.id, 'stop'))
        local ok, err = supervisor.resume(sup, run.id)
        assert(ok, err)
        assert(run.attempt == 2)
        assert(run.state == 'running')
        assert(run.handle ~= nil)
    end)

    it('spawn_child records parentage and inherits the root id', function()
        local sup = new_sup()
        local parent = create_started(sup)
        local child, err = supervisor.spawn_child(sup, parent.id, run_spec())
        assert(child ~= nil, err)
        assert(child.parent_id == parent.id)
        assert(child.root_id == parent.root_id)
        assert(child.id ~= parent.id)
        local found = false
        for _, cid in ipairs(parent.children) do
            if cid == child.id then
                found = true
            end
        end
        assert(found, 'parent.children must list the child')
    end)

    it('finish with completed emits exactly one run.finished and closes the handle', function()
        local sup, sink = new_sup()
        local run = create_started(sup)
        local ok, err = supervisor.finish(sup, run.id, 'completed', 'done')
        assert(ok, err)
        assert(run.state == 'completed')
        assert(count_kind(sink, run.id, 'run.finished') == 1)
        assert(run.handle.closed == true)
    end)

    it('tick times out a run past its deadline', function()
        local sup = new_sup()
        local run = assert(supervisor.create(sup, run_spec({ timeout_ms = 1 })))
        local ok, serr = supervisor.start_run(sup, run.id, 'stub')
        assert(ok, serr)
        local acted = supervisor.tick(sup, math.huge)
        assert(acted >= 1)
        assert(supervisor.get(sup, run.id).state == 'timed_out')
    end)

    it('retry_run schedules backoff with attempt + 1', function()
        local sup = new_sup()
        local run = create_started(sup)
        local ok, err = supervisor.retry_run(sup, run.id, 'transient')
        assert(ok, err)
        assert(run.state == 'retry_wait')
        assert(run.attempt == 2)
        assert(type(run.retry_at_ns) == 'number')
        assert(run.retry_at_ns > types.now_ns())
    end)

    it('consume overflow emits budget.exhausted and tick drains it to failed', function()
        local sup, sink = new_sup()
        local run = create_started(sup)
        assert(supervisor.consume(sup, run.id, 'turn', 1))
        local ok, err = supervisor.consume(sup, run.id, 'turn', 1000000)
        assert(ok == nil)
        assert(err:find('budget exhausted', 1, true) ~= nil)
        assert(count_kind(sink, run.id, 'budget.exhausted') == 1)
        local acted = supervisor.tick(sup, types.now_ns())
        assert(acted >= 1)
        assert(supervisor.get(sup, run.id).state == 'failed')
    end)

    it('drain finishes a run on model.completed', function()
        local sup, sink = new_sup()
        local run = create_started(sup)
        sink_append_completed(sink, run.id)
        local acted = supervisor.tick(sup, types.now_ns())
        assert(acted >= 1)
        assert(supervisor.get(sup, run.id).state == 'completed')
    end)
end)

describe('supervisor adversarial', function()
    it('invalid transition emits a diagnostic instead of mutating silently', function()
        local sup, sink = new_sup()
        local run = assert(supervisor.create(sup, run_spec()))
        local ok, err = supervisor.finish(sup, run.id, 'completed')
        assert(ok == nil)
        assert(err:find('invalid transition', 1, true) ~= nil)
        assert(run.state == 'created', 'state must not move on invalid transition')
        local found = false
        for _, event in ipairs(sink:events(run.id)) do
            if event.kind == 'diagnostic.observed' and event.payload.kind == 'invalid_transition' then
                found = true
                assert(event.payload.from == 'created')
                assert(event.payload.to == 'completed')
            end
        end
        assert(found, 'diagnostic.observed expected for the invalid transition')
    end)

    it('double finish is rejected', function()
        local sup = new_sup()
        local run = create_started(sup)
        assert(supervisor.finish(sup, run.id, 'completed'))
        local ok, err = supervisor.finish(sup, run.id, 'completed')
        assert(ok == nil)
        assert(err:find('invalid transition', 1, true) ~= nil)
    end)

    it('cancel on a terminal run is rejected', function()
        local sup = new_sup()
        local run = create_started(sup)
        assert(supervisor.finish(sup, run.id, 'completed'))
        local ok, err = supervisor.cancel(sup, run.id)
        assert(ok == nil)
        assert(err:find('already terminal', 1, true) ~= nil)
    end)

    it('resume on a non-terminal run is rejected', function()
        local sup = new_sup()
        local run = create_started(sup)
        local ok, err = supervisor.resume(sup, run.id)
        assert(ok == nil)
        assert(err:find('resume requires a terminal run', 1, true) ~= nil)
    end)

    it('unknown run ids are rejected', function()
        local sup = new_sup()
        local _, err1 = supervisor.finish(sup, 'nope', 'completed')
        assert(err1:find('unknown run', 1, true) ~= nil)
        local _, err2 = supervisor.cancel(sup, 'nope')
        assert(err2:find('unknown run', 1, true) ~= nil)
        local _, err3 = supervisor.resume(sup, 'nope')
        assert(err3:find('unknown run', 1, true) ~= nil)
        local _, err4 = supervisor.start_run(sup, 'nope')
        assert(err4:find('unknown run', 1, true) ~= nil)
        assert(supervisor.get(sup, 'nope') == nil)
        assert(supervisor.check_generation(sup, 'nope', 0) == false)
    end)

    it('run bound is enforced', function()
        local sup = new_sup({ runs_max = 1 })
        local run = assert(supervisor.create(sup, run_spec()))
        assert(run ~= nil)
        local run2, err2 = supervisor.create(sup, run_spec())
        assert(run2 == nil)
        assert(err2:find('run bound', 1, true) ~= nil)
    end)

    it('child of a terminal parent is rejected', function()
        local sup = new_sup()
        local parent = create_started(sup)
        assert(supervisor.finish(sup, parent.id, 'completed'))
        local child, err = supervisor.spawn_child(sup, parent.id, run_spec())
        assert(child == nil)
        assert(err:find('parent run is already terminal', 1, true) ~= nil)
    end)

    it('retry past the attempt ceiling is rejected', function()
        local sup = new_sup()
        local run = create_started(sup)
        run.attempt = 4
        local ok, err = supervisor.retry_run(sup, run.id, 'x')
        assert(ok == nil)
        assert(err:find('retry attempt ceiling exceeded', 1, true) ~= nil)
    end)

    it('cancel bumps generation so a late model.completed is ignored', function()
        local sup, sink = new_sup()
        local run = create_started(sup)
        assert(supervisor.check_generation(sup, run.id, 0) == true)
        local ok, err = supervisor.cancel(sup, run.id, 'stop')
        assert(ok, err)
        assert(supervisor.check_generation(sup, run.id, 0) == false)
        assert(supervisor.check_generation(sup, run.id, 1) == true)
        sink:append(run.id, 'model.completed', { outcome = 'completed' }, {})
        supervisor.tick(sup, types.now_ns())
        assert(supervisor.get(sup, run.id).state == 'cancelled')
        assert(count_kind(sink, run.id, 'run.finished') == 1)
    end)

    it('unknown outcome and unknown budget kind are rejected', function()
        local sup = new_sup()
        local run = create_started(sup)
        local ok, err = supervisor.finish(sup, run.id, 'exploded')
        assert(ok == nil)
        assert(err:find('unknown outcome', 1, true) ~= nil)
        local ok2, err2 = supervisor.consume(sup, run.id, 'bogus_kind', 1)
        assert(ok2 == nil)
        assert(err2:find('unknown budget kind', 1, true) ~= nil)
    end)
end)
