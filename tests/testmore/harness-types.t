#!/usr/bin/env lua
-- tests/testmore/harness-types.t
-- TAP specs for ai.harness.types: transitions, terminal set, run-spec validation.
-- 5 validation + 5 adversarial. Standalone lua-TestMore; no busted, no network.

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

local types = require('ai.harness.types')
local tm = require('Test.More')
tm.plan(10)

-- validation
tm.ok(types.can_transition('created', 'queued'), 'created -> queued is valid')
tm.ok(types.can_transition('running', 'completed'), 'running -> completed is valid')
tm.ok(types.can_transition('failed', 'queued'), 'failed -> queued is valid (resume)')
tm.ok(types.is_terminal('timed_out') and not types.is_terminal('running'),
    'terminal set is exact')
local ok, verr = types.validate_run_spec({ workflow = 'code.change', goal = 'g', workspace = '/w' })
tm.ok(ok == true, 'valid run spec passes: ' .. tostring(verr))

-- adversarial
tm.ok(not types.can_transition('created', 'completed'), 'created -> completed is invalid')
tm.ok(not types.can_transition('completed', 'queued'), 'completed -> queued is invalid')
tm.ok(not types.is_valid_event_kind('nope.kind'), 'unknown event kind is rejected')
local ok2, err2 = types.validate_run_spec({ workflow = 'w', workspace = '/w' })
tm.ok(ok2 == nil and err2:find('goal', 1, true) ~= nil, 'spec without goal is rejected')
local ok3, err3 = types.validate_run_spec('not-a-table')
tm.ok(ok3 == nil and err3:find('must be a table', 1, true) ~= nil, 'non-table spec is rejected')
