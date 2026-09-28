#!/usr/bin/env lua
-- tests/testmore/harness-policy.t
-- TAP specs for ai.harness.policy: allow rules, default deny, path checks.
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

local policy = require('ai.harness.policy')
local tm = require('Test.More')
tm.plan(10)

local function req(overrides)
    local r = { risk = 'observe', tool = 'fs.read', workspace = '/w' }
    if overrides then
        for k, v in pairs(overrides) do
            r[k] = v
        end
    end
    return r
end

-- validation
local p1 = assert(policy.new({ rules = { { risk = 'observe', decision = 'allow' } } }))
local d1 = policy.decide(p1, req())
tm.ok(d1.decision == 'allow' and d1.reason == 'matched rule', 'matching allow rule allows')

local p2 = assert(policy.new({ default = 'allow' }))
local d2 = policy.decide(p2, req({ risk = 'network' }))
tm.ok(d2.decision == 'allow' and d2.reason == 'no rule matched', 'default allow permits unmatched')

tm.ok(policy.path_in_workspace('/w/a/b', '/w') == true, 'nested path stays in workspace')
tm.ok(policy.path_in_workspace('/w', '/w') == true, 'workspace root itself is inside')

local p3 = assert(policy.new({ rules = { { risk = 'process', decision = 'approval' } } }))
local d3 = policy.decide(p3, req({ risk = 'process', tool = 'exec.run' }))
tm.ok(d3.decision == 'approval', 'approval decision is returned')

-- adversarial
local dn = policy.decide(nil, req())
tm.ok(dn.decision == 'deny' and dn.reason == 'no policy configured', 'nil policy denies')

local de = policy.decide(p1, req({ paths = { '/etc/passwd' } }))
local escaped = de.decision == 'deny' and de.reason:find('path escapes workspace', 1, true) ~= nil
tm.ok(escaped, 'path escape denies')

local du = policy.decide(p1, req({ risk = 'nuke' }))
tm.ok(du.decision == 'deny' and du.reason == 'unknown risk class', 'unknown risk denies')

local p4 = assert(policy.new())
local dd = policy.decide(p4, req())
tm.ok(dd.decision == 'deny' and dd.reason == 'no rule matched', 'default deny denies unmatched')

local dm = policy.decide(p4, 'garbage')
tm.ok(dm.decision == 'deny' and dm.reason == 'malformed request', 'malformed request denies')
