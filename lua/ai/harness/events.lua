-- /qompassai/diver/lua/ai/harness/events.lua
-- Qompass AI Agent Harness: append-only typed event stream (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- All harness behavior becomes typed events in one append-only stream.
-- The sink is in-memory for Phase 1; persistence lives in store.lua.
-- Event envelopes carry run_id, sequence, monotonic timestamp, source
-- adapter, schema version, and redaction status. Prompt/completion content
-- is never captured unless the caller opts in via payload fields.

local types = require('ai.harness.types')

local M = {}

local SEQ_MAX = 1000000000
local SINK_EVENTS_MAX = 100000

---@class AiHarnessEvent
---@field schema_version integer
---@field run_id string
---@field parent_id? string
---@field seq integer
---@field ts_ns integer
---@field source string
---@field kind string
---@field payload table
---@field redacted boolean

---@class AiHarnessSink
---@field append fun(self: AiHarnessSink, run_id: string, kind: string, payload?: table, opts?: table): AiHarnessEvent?, string?
---@field events fun(self: AiHarnessSink, run_id?: string): AiHarnessEvent[]
---@field count fun(self: AiHarnessSink): integer

---Build and validate one envelope without appending it.
---@param run_id string
---@param kind string
---@param payload? table
---@param opts? table
---@return AiHarnessEvent? event
---@return string? err
function M.make_envelope(run_id, kind, payload, opts)
    if type(run_id) ~= 'string' or run_id == '' then
        return nil, 'event run_id must be a non-empty string'
    end
    if not types.is_valid_event_kind(kind) then
        return nil, 'unknown event kind: ' .. tostring(kind)
    end
    opts = opts or {}
    if type(opts) ~= 'table' then
        return nil, 'event opts must be a table when given'
    end
    payload = payload or {}
    if type(payload) ~= 'table' then
        return nil, 'event payload must be a table when given'
    end
    local event = {
        schema_version = types.SCHEMA_VERSION,
        run_id = run_id,
        parent_id = opts.parent_id,
        seq = opts.seq or 0,
        ts_ns = opts.ts_ns or types.now_ns(),
        source = opts.source or 'harness',
        kind = kind,
        payload = payload,
        redacted = opts.redacted == true,
    }
    return event
end

---Create an append-only in-memory sink.
---@return AiHarnessSink
function M.new_sink()
    local stored = {} ---@type AiHarnessEvent[]
    local seq = 0

    local sink = {}

    ---@param run_id string
    ---@param kind string
    ---@param payload? table
    ---@param opts? table
    ---@return AiHarnessEvent? event
    ---@return string? err
    function sink:append(run_id, kind, payload, opts)
        if #stored >= SINK_EVENTS_MAX then
            return nil, 'event sink is full'
        end
        seq = (seq + 1) % SEQ_MAX
        opts = opts or {}
        opts.seq = seq
        local event, err = M.make_envelope(run_id, kind, payload, opts)
        if event == nil then
            return nil, err
        end
        stored[#stored + 1] = event
        return event
    end

    ---Return a copy of stored events, optionally filtered by run.
    ---@param run_id? string
    ---@return AiHarnessEvent[]
    function sink:events(run_id)
        local out = {}
        for _, event in ipairs(stored) do
            if run_id == nil or event.run_id == run_id then
                out[#out + 1] = event
            end
        end
        return out
    end

    ---@return integer
    function sink:count()
        return #stored
    end

    return sink
end

return M
