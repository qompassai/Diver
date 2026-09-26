--- Recon subsystem self-test: skills loader, annotations, gate,
--- parsers, tools, and the WebMCP bridge round-trip.
---
--- Plain-language version: this is a test script, not a feature. It
--- exercises the recon modules and reports pass or fail. It runs
--- headless via `nvim -l`; it is not loaded at startup.
---@module 'tests.recon'
-- #################################################################
-- /qompassai/diver/tests/lua/recon.lua
-- Qompass AI Diver Lua Recon Test
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
local T = {}
function T.assert(value, message)
    assert(value, message)
end
function T.assert_eq(a, b, message)
    assert(a == b, message or ('expected ' .. vim.inspect(a) .. ' == ' .. vim.inspect(b)))
end

local here = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fn.fnamemodify(here, ':h:h:h')
package.path = root .. '/lua/?.lua;' .. root .. '/lua/?/init.lua;' .. package.path

local passed = 0
local function check(name, cond)
    T.assert(cond, 'FAILED: ' .. name)
    passed = passed + 1
    print('ok: ' .. name)
end

-- 1. Annotations -------------------------------------------------
local ann = require('ai.security.annotations')
local a = ann.for_skill({ name = 's', category = 'recon', tags = { 'passive' } })
check('recon/passive is read-only', a.readOnlyHint and not a.consequentialHint)
check('recon output is untrusted content', a.untrustedContentHint)
check('debugging hint carried (false)', a.debugging == false)
a = ann.for_skill({ name = 's', category = 'redteam', tags = {} })
check('redteam is consequential', a.consequentialHint and not a.readOnlyHint)
a = ann.for_skill({ name = 's', category = 'chains', tags = {} })
check('chains is consequential', a.consequentialHint)
a = ann.for_skill({ name = 's', category = 'meta', tags = {} })
check('meta is read-only', a.readOnlyHint and not a.consequentialHint)
a = ann.for_skill({ name = 's', category = 'mystery', tags = {} })
check('unknown category defaults consequential', a.consequentialHint)
a = ann.for_endpoint('read')
check('endpoint read annotates read-only', a.readOnlyHint)
a = ann.for_endpoint('execute')
check('endpoint execute annotates consequential+untrusted', a.consequentialHint and a.untrustedContentHint)
check('needs_confirmation true for consequential', ann.needs_confirmation({ consequentialHint = true }))
check('needs_confirmation false for read-only', not ann.needs_confirmation({ readOnlyHint = true }))

-- 2. Skills loader (against the real library if present) --------
local skills = require('ai.mcp.skills')
local skills_dir = vim.fn.stdpath('data') .. '/recon-skills'
if vim.fn.isdirectory(skills_dir) == 1 then
    local loaded, errors = skills.scan(skills_dir)
    check('skills scan loads >100', loaded > 100)
    check('skills scan has no errors', #errors == 0)
    local cms = skills.get('cms-detection')
    check('cms-detection found', cms ~= nil)
    check('cms-detection is recon', cms.category == 'recon')
    local defs = skills.tool_defs()
    check('tool_defs excludes non-invocable', #defs < loaded)
    local pb = skills.get('pentest-playbook')
    check('pentest-playbook not model-invocable', pb ~= nil and not pb.model_invocable)
    local found_in_defs = false
    for _, d in ipairs(defs) do
        if d.name == 'recon.pentest-playbook' then
            found_in_defs = true
        end
    end
    check('pentest-playbook excluded from tool defs', not found_in_defs)
    local done_exec = false
    skills.execute('pentest-playbook', { target = 'example.com' }, 'test', function(ok, _res)
        check('non-invocable skill refuses execute', not ok)
        done_exec = true
    end)
    check('execute callback ran', done_exec)
    local done_unknown = false
    skills.execute('no-such-skill', { target = 'example.com' }, 'test', function(ok, _res)
        check('unknown skill errors', not ok)
        done_unknown = true
    end)
    check('unknown skill callback ran', done_unknown)

    -- name validation: upstream contract is lowercase alphanumerics
    -- with single-hyphen separators (Lua patterns cannot quantify
    -- groups, so the loader checks this in parts)
    local tmpdir = vim.fn.tempname()
    vim.fn.mkdir(tmpdir .. '/good-skill', 'p')
    vim.fn.mkdir(tmpdir .. '/bad-skill', 'p')
    local good = table.concat({
        '---',
        'name: good-skill',
        'description: fine',
        'category: recon',
        '---',
        '# Good',
        '',
    }, '\n')
    local bad = table.concat({
        '---',
        'name: Bad_Name',
        'description: bad',
        'category: recon',
        '---',
        '# Bad',
        '',
    }, '\n')
    local fh = assert(io.open(tmpdir .. '/good-skill/SKILL.md', 'w'))
    fh:write(good)
    fh:close()
    fh = assert(io.open(tmpdir .. '/bad-skill/SKILL.md', 'w'))
    fh:write(bad)
    fh:close()
    local n_loaded, n_errors = skills.scan(tmpdir)
    check('name validation loads the good skill', n_loaded == 1)
    check('name validation rejects the bad name', #n_errors == 1)
    check('name validation error names the skill', n_errors[1]:find('Bad_Name') ~= nil)
    vim.fn.delete(tmpdir, 'rf')
    skills.scan() -- restore the real library
else
    print('skip: recon-skills library not installed at ' .. skills_dir)
end

-- 3. Gate ---------------------------------------------------------
local gate = require('ai.recon.gate')
gate.setup({ auto_authorize = true })
local gate_done = false
gate.check('recon.x', 'example.com', { readOnlyHint = true }, 'test', function(ok, _reason)
    check('read-only allowed', ok)
    gate_done = true
end)
check('gate callback ran', gate_done)
gate.setup({ auto_authorize = false })
-- headless has no UI: confirm_tool_call default-denies
local denied_done = false
gate.check('recon.y', 'example.com', { consequentialHint = true }, 'test', function(ok, _reason)
    check('consequential denied headless without auto-auth', not ok)
    denied_done = true
end)
check('deny callback ran', denied_done)
gate.setup({ auto_authorize = true }) -- restore default

-- 4. Parsers ------------------------------------------------------
local parse = require('ai.recon.parse')
local hosts = parse.nmap_grepable(
    'Host: 10.0.0.1 (gw) Status: Up\n' .. 'Host: 10.0.0.1 (gw) Ports: 22/open/tcp//ssh///, 80/closed/tcp//http///\n'
)
check('nmap_grepable one host', #hosts == 1)
check('nmap_grepable two ports', #hosts[1].ports == 2)
check('nmap_grepable port fields', hosts[1].ports[1].port == 22 and hosts[1].ports[1].service == 'ssh')
local h, skipped = parse.httpx('{"url":"http://a/","status_code":200,"title":"hi"}\nbroken\n')
check('httpx one host', #h == 1)
check('httpx skips bad lines', skipped == 1)
check('httpx status field', h[1].status == 200)

-- 5. Tools --------------------------------------------------------
local tools = require('ai.recon.tools')
local listed = tools.list()
check('tools list non-empty', #listed > 0)
check('curl available', tools.available('curl'))
check('nmap not installed here', not tools.available('nmap'))
local run_done = false
tools.run('nope', {}, function(ok, _res)
    check('unknown tool errors', not ok)
    run_done = true
end)
check('unknown tool callback ran', run_done)
local miss_done = false
tools.run('nmap', { '127.0.0.1' }, function(ok, _res)
    check('missing binary reports unavailable', not ok)
    miss_done = true
end)
check('missing binary callback ran', miss_done)

-- 6. Audit log ----------------------------------------------------
local auditlog = require('ai.security.auditlog')
check(
    'audit log append works',
    auditlog.append({ tool = 'test', target = 'example.com', via = 'test', decision = 'test' })
)

-- 7. Bridge round-trip (token-gated) ------------------------------
local bridge = require('ai.webmcp.bridge')
local token_mod = require('ai.security.token')
local test_token = assert(token_mod.mint('bridge', 300))
local st = bridge.start({ port = 17899 })
check('bridge starts', st.running)
local wc = require('websocket.client')
local finished = false
local unauth_rejected, bad_auth_rejected = false, false
local authed, got_tools, got_ping = false, false, false
local client = nil
client = wc.WebsocketClient.new({
    connect_addr = 'ws://127.0.0.1:17899',
    on_message = function(_, raw)
        local msg = vim.json.decode(raw)
        if msg.id == 1 then
            unauth_rejected = not msg.ok and tostring(msg.error):find('unauthorized') ~= nil
        elseif msg.id == 2 then
            bad_auth_rejected = not msg.ok
        elseif msg.id == 3 then
            authed = msg.ok == true
        elseif msg.id == 4 then
            got_tools = msg.ok and #(msg.result.tools or {}) >= 10
        elseif msg.id == 5 then
            got_ping = msg.ok and msg.result.pong == true
        elseif msg.id == 6 then
            check('bridge rejects unknown method', not msg.ok)
            finished = true
        end
    end,
    on_connect = function()
        local send = function(id, method, params)
            client:try_send_data(vim.json.encode({ id = id, method = method, params = params }))
        end
        send(1, 'bridge.tools', {}) -- no token yet: must be rejected
        send(2, 'bridge.auth', { token = 'v1.bogus.bogus' })
        send(3, 'bridge.auth', { token = test_token })
        send(4, 'bridge.tools', {})
        send(5, 'bridge.ping', {}) -- public: works with or without auth
        send(6, 'nope.nope', {})
    end,
})
client:try_connect()
vim.wait(5000, function()
    return finished
end)
check('bridge round-trip finished', finished)
check('bridge rejects unauthenticated tools call', unauth_rejected)
check('bridge rejects bad token', bad_auth_rejected)
check('bridge.auth accepts valid token', authed)
check('bridge.tools lists endpoints', got_tools)
check('bridge.ping pongs', got_ping)
local st2 = bridge.start({ port = 17899 })
check('bridge start is idempotent', st2.running)
bridge.stop()
check('bridge stops', not bridge.status().running)

print(('recon tests: %d passed'):format(passed))

-- 8. WebMCP discovery -----------------------------------------------
local webmcp = require('ai.mcp.webmcp')
local disc_done = false
bridge.start({ port = 17898 })
webmcp.discover('ws://127.0.0.1:17898', function(ok, res)
    check('webmcp discover ok', ok)
    check('webmcp discover finds endpoints', res.tools ~= nil and #res.tools >= 10)
    check('webmcp discover tags source', res.tools[1].source == 'ws://127.0.0.1:17898')
    disc_done = true
end, test_token)
vim.wait(8000, function()
    return disc_done
end)
check('webmcp discover finished', disc_done)
local bad_done = false
webmcp.discover('not-a-url', function(ok, _res)
    check('webmcp discover rejects bad url', not ok)
    bad_done = true
end)
check('webmcp bad-url callback ran', bad_done)
bridge.stop()

print(('recon tests total: %d passed'):format(passed))
