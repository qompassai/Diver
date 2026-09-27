-- Adversarial spec: policy scoping and command validation.
-- Run: lua tests/lua/mcp_server/policy_adversarial.lua
local here = debug.getinfo(1, 'S').source:sub(2)
local dir = here:match('^(.*)/[^/]*$')
local stub = dofile(dir .. '/common.lua')

local passed = 0
local function check(value, message)
    assert(value, message)
    passed = passed + 1
end

local policy = require('ai.mcp.server.policy')

local tmp = stub.fresh_dir('policy_adv')
policy.setup({ roots = { tmp }, grant_token = 'tok', run_allowlist = { 'echo' } })

-- `..` escape variants all land on -32602.
do
    local escapes = {
        tmp .. '/..',
        tmp .. '/sub/../../..',
        '/tmp/../etc/passwd',
        tmp .. '//..//etc',
    }
    for _, p in ipairs(escapes) do
        local _, err = policy.scope_path(p)
        check(err ~= nil and err.code == -32602, 'escape -> -32602: ' .. p)
    end
end

-- A path that merely shares a prefix with the root is not inside it.
do
    local sibling = tmp .. '_sibling'
    vim.fn.mkdir(sibling, 'p')
    local _, err = policy.scope_path(sibling .. '/x')
    check(err ~= nil and err.code == -32602, 'prefix-sibling is out of scope')
    os.execute('rm -rf ' .. stub.shquote(sibling))
end

-- run_command: shell metacharacters are literal argv elements, never a
-- shell string. The captured argv must match exactly.
do
    local seen = nil
    stub._system_impl = function(cmd, _)
        seen = cmd
        return { code = 0, stdout = '', stderr = '' }
    end
    local attacks = {
        { 'echo', '; rm -rf /' },
        { 'echo', '$(rm -rf /)' },
        { 'echo', '`rm -rf /`' },
        { 'echo', 'a|b' },
        { 'echo', 'a&&b' },
        { 'echo', 'a\nb' },
    }
    for _, argv in ipairs(attacks) do
        local checked, err = policy.check_command(argv, nil)
        check(err == nil, 'metachar argv passes validation: ' .. argv[2])
        check(checked.argv[2] == argv[2], 'argv element preserved literally: ' .. argv[2])
    end
    check(seen == nil, 'policy validation alone never spawns')
end

-- argv[0] tricks: path forms rejected; lookalikes not allowlisted.
do
    local _, e1 = policy.check_command({ '/bin/echo' }, nil)
    check(e1 ~= nil and e1.code == -32602, 'absolute argv[0] -> -32602')
    local _, e2 = policy.check_command({ './echo' }, nil)
    check(e2 ~= nil and e2.code == -32602, 'relative argv[0] -> -32602')
    local _, e3 = policy.check_command({ 'echo;rm' }, nil)
    check(e3 ~= nil and e3.code == -32000, 'lookalike argv[0] not in allowlist')
    local _, e4 = policy.check_command({ 'ECHO' }, nil)
    check(e4 ~= nil and e4.code == -32000, 'allowlist is case-sensitive')
    local _, e5 = policy.check_command({ 'rm' }, nil)
    check(e5 ~= nil and e5.code == -32000, 'non-allowlisted command denied')
end

-- Malformed argv shapes are -32602, never crashes.
do
    local bad = {
        {},
        'echo',
        { '' },
        { 'echo', 42 },
        { 'echo', 'x\0y' },
        { 'echo', string.rep('y', 4097) },
    }
    for _, argv in ipairs(bad) do
        local _, err = policy.check_command(argv, nil)
        check(err ~= nil and err.code == -32602, 'bad argv -> -32602')
    end
    local sparse = { 'echo' }
    sparse[3] = 'x'
    local _, sparse_err = policy.check_command(sparse, nil)
    check(sparse_err ~= nil and sparse_err.code == -32602, 'sparse argv -> -32602')
    local too_many = {}
    for i = 1, 33 do
        too_many[i] = 'x'
    end
    local _, many_err = policy.check_command(too_many, nil)
    check(many_err ~= nil and many_err.code == -32602, '33-element argv -> -32602')
end

-- cwd is scoped exactly like a path argument.
do
    local _, e1 = policy.check_command({ 'echo' }, '/etc')
    check(e1 ~= nil and e1.code == -32602, 'cwd outside roots -> -32602')
    local _, e2 = policy.check_command({ 'echo' }, tmp .. '/../etc')
    check(e2 ~= nil and e2.code == -32602, 'cwd traversal -> -32602')
    local _, e3 = policy.check_command({ 'echo' }, tmp .. '/.ssh')
    check(e3 ~= nil and e3.code == -32000, 'cwd under .ssh -> -32000')
end

-- scope_path rejects non-strings, empties, and overlong paths.
do
    local _, e1 = policy.scope_path(nil)
    check(e1 ~= nil and e1.code == -32602, 'nil path -> -32602')
    local _, e2 = policy.scope_path('')
    check(e2 ~= nil and e2.code == -32602, 'empty path -> -32602')
    local _, e3 = policy.scope_path(42)
    check(e3 ~= nil and e3.code == -32602, 'non-string path -> -32602')
    local _, e4 = policy.scope_path(tmp .. '/' .. string.rep('a', 5000))
    check(e4 ~= nil and e4.code == -32602, 'overlong path -> -32602')
end

-- Grant confusion: token for one tool does not leak to others, and the
-- deny class stays denied even with a token.
do
    policy.setup({ roots = { tmp }, grant_token = 'tok' })
    local ok1, _ = policy.check_approval('write_file', { grant = 'tok' })
    check(ok1 == true, 'token approves confirm-class tool')
    local ok2, _ = policy.check_approval('mystery', { grant = 'tok' })
    check(ok2 == false, 'token does not approve deny-class tool')
end

os.execute('rm -rf ' .. stub.shquote(tmp))
print('ok policy_adversarial: ' .. passed .. ' checks')
