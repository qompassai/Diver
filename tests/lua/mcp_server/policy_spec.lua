-- Validation spec: MCP server fail-closed policy.
-- Run: lua tests/lua/mcp_server/policy_spec.lua
local here = debug.getinfo(1, 'S').source:sub(2)
local dir = here:match('^(.*)/[^/]*$')
local stub = dofile(dir .. '/common.lua')

local passed = 0
local function check(value, message)
    assert(value, message)
    passed = passed + 1
end

local policy = require('ai.mcp.server.policy')

local tmp = stub.fresh_dir('policy_spec')

-- setup defaults to cwd when no roots are given, and is idempotent.
do
    policy.setup({})
    local roots = policy.roots()
    check(#roots == 1, 'one default root')
    check(roots[1]:sub(1, 1) == '/', 'default root is absolute')
    policy.setup({ roots = { tmp } })
    policy.setup({ roots = { tmp } })
    check(policy.roots()[1] == tmp, 're-setup replaces config')
end

-- scope_path: relative anchors at the first root; absolute under root ok.
do
    policy.setup({ roots = { tmp } })
    vim.fn.mkdir(tmp .. '/sub', 'p')
    local scoped, err = policy.scope_path('sub')
    check(err == nil and scoped == tmp .. '/sub', 'relative anchors at root')
    local scoped2, err2 = policy.scope_path(tmp .. '/sub')
    check(err2 == nil and scoped2 == tmp .. '/sub', 'absolute under root ok')
    local scoped3, err3 = policy.scope_path(tmp)
    check(err3 == nil and scoped3 == tmp, 'the root itself is in scope')
    local scoped4, err4 = policy.scope_path(tmp .. '/./sub/../sub')
    check(err4 == nil and scoped4 == tmp .. '/sub', 'dot segments collapse')
end

-- Multiple roots: a path under any root is in scope.
do
    local tmp2 = stub.fresh_dir('policy_spec2')
    policy.setup({ roots = { tmp, tmp2 } })
    local scoped, err = policy.scope_path(tmp2 .. '/x')
    check(err == nil and scoped == tmp2 .. '/x', 'second root in scope')
    os.execute('rm -rf ' .. stub.shquote(tmp2))
end

-- Approval classes: reads auto, writes need grants, unknown tools denied.
do
    policy.setup({ roots = { tmp } })
    for _, tool in ipairs({ 'read_file', 'list_files', 'search_text', 'get_diagnostics' }) do
        local ok, _ = policy.check_approval(tool, nil)
        check(ok == true, tool .. ' is auto-approved')
    end
    for _, tool in ipairs({ 'write_file', 'edit_file', 'run_command' }) do
        local ok, reason = policy.check_approval(tool, nil)
        check(ok == false, tool .. ' needs a grant')
        check(type(reason) == 'string', tool .. ' denial explains')
    end
    local ok, _ = policy.check_approval('mystery_tool', nil)
    check(ok == false, 'unknown tool is denied')
end

-- Confirmation via setup grant and via _meta token.
do
    policy.setup({ roots = { tmp }, confirm_grants = { write_file = true } })
    local ok, _ = policy.check_approval('write_file', nil)
    check(ok == true, 'static confirm grant approves')
    local ok2, _ = policy.check_approval('edit_file', nil)
    check(ok2 == false, 'static grant is per-tool')

    policy.setup({ roots = { tmp }, grant_token = 's3cret' })
    local ok3, _ = policy.check_approval('edit_file', { grant = 's3cret' })
    check(ok3 == true, '_meta grant token approves')
    local ok4, _ = policy.check_approval('edit_file', { grant = 'wrong' })
    check(ok4 == false, 'wrong grant token denied')
    local ok5, _ = policy.check_approval('edit_file', 's3cret')
    check(ok5 == false, 'non-table _meta denied')
end

-- check_command: valid argv passes; cwd is scoped.
do
    policy.setup({ roots = { tmp }, run_allowlist = { 'ls', 'echo' } })
    local checked, err = policy.check_command({ 'ls', '-la' }, nil)
    check(err == nil and checked.argv[2] == '-la', 'allowlisted argv passes')
    check(checked.cwd == nil, 'nil cwd stays nil')
    local checked2, err2 = policy.check_command({ 'echo', 'hi' }, tmp .. '/sub')
    check(err2 == nil and checked2.cwd == tmp .. '/sub', 'cwd scoped under roots')
end

-- audit: hermetic, never throws, records the decision.
do
    policy.setup({ roots = { tmp } })
    local before = #stub._audit_records
    local recorded = policy.audit('read_file', tmp .. '/x', 'allowed')
    check(recorded == true, 'audit records')
    check(#stub._audit_records == before + 1, 'one record appended')
    local rec = stub._audit_records[#stub._audit_records]
    check(rec.tool == 'read_file' and rec.via == 'mcp-server', 'record fields')
    check(rec.decision == 'allowed', 'decision recorded')
end

-- audit degrades to false when the audit module is missing entirely.
do
    package.loaded['ai.security.auditlog'] = nil
    package.preload['ai.security.auditlog'] = function()
        error('module gone')
    end
    local recorded = policy.audit('read_file', 'x', 'allowed')
    check(recorded == false, 'missing audit module -> false, no throw')
end

os.execute('rm -rf ' .. stub.shquote(tmp))
print('ok policy_spec: ' .. passed .. ' checks')
