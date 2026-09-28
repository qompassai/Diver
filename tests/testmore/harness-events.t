#!/usr/bin/env lua
-- tests/testmore/harness-events.t
-- TAP specs for ai.harness.events: envelope shape, sequencing, filtering.
-- 4 validation + 4 adversarial. Standalone lua-TestMore; no busted, no network.

local src = debug.getinfo(1, 'S').source:match('^@(.+)$')
local dir = (src and src:match('^(.*)/[^/]+$')) or '.'
local root = dir .. '/..'
package.path = root .. '/lua/?.lua;' .. root .. '/lua/?/init.lua;' .. package.path

_G.vim = {
    uv = {
        hrtime = function()
            return 1
        end,
    },
}

local events = require('ai.harness.events')
local tm = require('Test.More')
tm.plan(8)

-- validation
local sink = events.new_sink()
local e1, err1 = sink:append('r1', 'run.created', { workflow = 'w' }, { source = 'test' })
tm.ok(e1 ~= nil and e1.seq == 1, 'append returns an event with seq 1: ' .. tostring(err1))

local shaped = e1.schema_version == 1 and e1.run_id == 'r1' and e1.kind == 'run.created'
    and e1.source == 'test' and e1.redacted == false and type(e1.ts_ns) == 'number'
tm.ok(shaped, 'envelope carries schema/run/kind/source/redacted/ts')

local e2 = sink:append('r1', 'run.started', {}, {})
tm.ok(e2.seq == 2, 'sequence increments per append')

sink:append('r2', 'run.created', {}, {})
local r1events = sink:events('r1')
local all_r1 = true
for _, e in ipairs(r1events) do
    if e.run_id ~= 'r1' then
        all_r1 = false
    end
end
tm.ok(#r1events == 2 and all_r1, 'events filter per run id')

-- adversarial
local b1, berr1 = sink:append('r1', 'nope.kind', {}, {})
tm.ok(b1 == nil and berr1:find('unknown event kind', 1, true) ~= nil, 'bad kind rejected')

local b2, berr2 = sink:append('', 'run.created', {}, {})
local empty_rejected = b2 == nil and berr2:find('run_id must be a non-empty string', 1, true) ~= nil
tm.ok(empty_rejected, 'empty run_id rejected')

local b3, berr3 = sink:append('r1', 'run.created', 'nope', {})
local payload_rejected = b3 == nil and berr3:find('event payload must be a table', 1, true) ~= nil
tm.ok(payload_rejected, 'non-table payload rejected')

local b4, berr4 = events.make_envelope('r1', 'run.created', {}, 'nope')
local opts_rejected = b4 == nil and berr4:find('event opts must be a table', 1, true) ~= nil
tm.ok(opts_rejected, 'non-table opts rejected')
