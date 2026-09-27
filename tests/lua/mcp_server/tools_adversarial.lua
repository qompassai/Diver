-- Adversarial spec: tool registry, path scoping, write tools, run_command.
-- Run: lua tests/lua/mcp_server/tools_adversarial.lua
local here = debug.getinfo(1, 'S').source:sub(2)
local dir = here:match('^(.*)/[^/]*$')
local stub = dofile(dir .. '/common.lua')

local passed = 0
local function check(value, message)
    assert(value, message)
    passed = passed + 1
end

local policy = require('ai.mcp.server.policy')
local tools = require('ai.mcp.server.tools')

local tmp = stub.fresh_dir('tools_adv')
policy.setup({ roots = { tmp }, grant_token = 'tok', run_allowlist = { 'echo' } })
tools.setup()

local GRANT = { grant = 'tok' }

local function call_ok(name, args)
    local result, err = tools.call(name, args or {}, GRANT)
    check(err == nil, 'no protocol error for ' .. name .. ': ' .. (err and err.message or ''))
    check(result ~= nil, 'result for ' .. name)
    return result
end

local function file_exists(path)
    local f = io.open(path, 'r')
    if f == nil then
        return false
    end
    f:close()
    return true
end

-- Path traversal: `..` escapes -> -32602.
do
    local _, err = tools.call('read_file', { path = tmp .. '/../../etc/passwd' }, nil)
    check(err ~= nil and err.code == -32602, 'dotdot escape -> -32602')
    local _, err2 = tools.call('read_file', { path = '/etc/passwd' }, nil)
    check(err2 ~= nil and err2.code == -32602, 'absolute outside roots -> -32602')
    local _, err3 = tools.call('read_file', { path = 'a/../../../etc/hostname' }, nil)
    check(err3 ~= nil and err3.code == -32602, 'relative climb-out -> -32602')
end

-- Symlink escape: a link inside the roots pointing outside is re-checked.
do
    vim.fn.mkdir(tmp .. '/real', 'p')
    stub.write_file(tmp .. '/real/secret.txt', 'inside')
    os.execute('ln -s /etc ' .. stub.shquote(tmp .. '/evil'))
    os.execute('ln -s ' .. stub.shquote(tmp .. '/real') .. ' ' .. stub.shquote(tmp .. '/oklink'))
    local _, err = tools.call('read_file', { path = tmp .. '/evil/passwd' }, nil)
    check(err ~= nil and err.code == -32602, 'symlink to /etc -> -32602')
    local res, err2 = tools.call('read_file', { path = tmp .. '/oklink/secret.txt' }, nil)
    check(err2 == nil and res.isError ~= true, 'symlink inside roots still works')
    check(res.content[1].text == 'inside', 'symlink content reads through')
end

-- Secret paths are denied even inside the roots (-32000 policy denial).
do
    vim.fn.mkdir(tmp .. '/.ssh', 'p')
    stub.write_file(tmp .. '/.ssh/id_rsa', 'fake')
    stub.write_file(tmp .. '/.env', 'fake')
    stub.write_file(tmp .. '/creds.pem', 'fake')
    for _, p in ipairs({ tmp .. '/.ssh/id_rsa', tmp .. '/.env', tmp .. '/creds.pem' }) do
        local _, err = tools.call('read_file', { path = p }, nil)
        check(err ~= nil and err.code == -32000, 'secret path denied: ' .. p)
    end
end

-- Control characters (including embedded newlines) in paths are rejected.
do
    local _, err = tools.call('read_file', { path = tmp .. '/a\nb' }, nil)
    check(err ~= nil and err.code == -32602, 'embedded newline in path -> -32602')
    local _, err2 = tools.call('read_file', { path = 'x\0y' }, nil)
    check(err2 ~= nil and err2.code == -32602, 'NUL in path -> -32602')
end

-- write_file: create refuses when the file exists; overwrite replaces.
do
    local p = tmp .. '/w.txt'
    stub.write_file(p, 'old')
    local res, err = tools.call('write_file', { path = p, content = 'new', mode = 'create' }, GRANT)
    check(err == nil and res.isError == true, 'create on existing -> isError')
    local res2 = call_ok('write_file', { path = p, content = 'new', mode = 'overwrite' })
    check(res2.isError ~= true, 'overwrite succeeds')
    local back = tools.call('read_file', { path = p }, nil)
    check(back.content[1].text == 'new', 'overwrite content round-trips')
end

-- write_file without a grant is denied before touching the filesystem.
do
    local p = tmp .. '/denied.txt'
    local _, err = tools.call('write_file', { path = p, content = 'x', mode = 'create' }, nil)
    check(err ~= nil and err.code == -32000, 'write without grant -> -32000')
    check(not file_exists(p), 'denied write creates nothing')
end

-- write_file: bad mode enum is a shape error.
do
    local args = { path = tmp .. '/x', content = 'x', mode = 'append' }
    local _, err = tools.call('write_file', args, GRANT)
    check(err ~= nil and err.code == -32602, 'bad mode enum -> -32602')
end

-- edit_file: exact replace works; absent/ambiguous fail loudly.
do
    local p = tmp .. '/e.txt'
    stub.write_file(p, 'hello world\n')
    local res = call_ok('edit_file', { path = p, old_text = 'world', new_text = 'there' })
    check(res.isError ~= true, 'exact edit succeeds')
    local back = tools.call('read_file', { path = p }, nil)
    check(back.content[1].text == 'hello there', 'edit applied')
    local res2 = call_ok('edit_file', { path = p, old_text = 'missing', new_text = 'x' })
    check(res2.isError == true, 'absent old_text -> isError')
    stub.write_file(p, 'aa aa\n')
    local res3 = call_ok('edit_file', { path = p, old_text = 'aa', new_text = 'b' })
    check(res3.isError == true, 'ambiguous old_text -> isError')
    local back3 = tools.call('read_file', { path = p }, nil)
    check(back3.content[1].text == 'aa aa', 'ambiguous edit changes nothing')
end

-- run_command: default deny, grant gate, then literal argv.
do
    policy.setup({ roots = { tmp } }) -- no allowlist: deny-all
    local _, err = tools.call('run_command', { cmd = { 'echo', 'hi' } }, GRANT)
    check(err ~= nil and err.code == -32000, 'empty allowlist -> -32000')
    policy.setup({ roots = { tmp }, grant_token = 'tok', run_allowlist = { 'echo' } })
    local _, err2 = tools.call('run_command', { cmd = { 'echo', 'hi' } }, nil)
    check(err2 ~= nil and err2.code == -32000, 'run_command without grant -> -32000')
    local seen = nil
    stub._executables = { echo = true }
    stub._system_impl = function(cmd, opts)
        seen = { cmd = cmd, opts = opts }
        return { code = 0, stdout = 'hi\n', stderr = '' }
    end
    local res = call_ok('run_command', { cmd = { 'echo', '; rm -rf /' } })
    check(res.isError ~= true, 'allowlisted command runs')
    check(seen.cmd[1] == 'echo' and seen.cmd[2] == '; rm -rf /', 'metachars stay literal argv')
    check(#seen.cmd == 2, 'no shell splitting of argv')
    check(seen.opts.cwd == nil, 'no cwd means no cwd passed')
end

-- run_command: a real-Neovim-style SystemObj (needs :wait()) works too.
do
    stub._executables = { echo = true }
    local waited = false
    stub._system_impl = function(cmd, _)
        return {
            wait = function(_self)
                waited = true
                return { code = 0, stdout = 'obj\n', stderr = '' }
            end,
        }
    end
    local res = call_ok('run_command', { cmd = { 'echo', 'hi' } })
    check(waited, ':wait() called on SystemObj-like handle')
    check(res.isError ~= true, 'SystemObj result accepted')
    check(res.content[1].text:find('obj') ~= nil, 'waited stdout surfaced')
end

-- run_command: argv[0] with a slash is rejected even when allowlisted.
do
    policy.setup({ roots = { tmp }, grant_token = 'tok', run_allowlist = { 'echo' } })
    local _, err = tools.call('run_command', { cmd = { '/bin/echo', 'hi' } }, GRANT)
    check(err ~= nil and err.code == -32602, 'argv[0] path -> -32602')
    local _, err2 = tools.call('run_command', { cmd = { './echo', 'hi' } }, GRANT)
    check(err2 ~= nil and err2.code == -32602, 'relative argv[0] -> -32602')
end

-- run_command: nonzero exit is isError, not a protocol error.
do
    stub._system_impl = function(_, _)
        return { code = 3, stdout = '', stderr = 'boom\n' }
    end
    local res = call_ok('run_command', { cmd = { 'echo', 'x' } })
    check(res.isError == true, 'nonzero exit -> isError')
    check(res.content[1].text:find('exit code: 3') ~= nil, 'exit code reported')
    check(res.content[1].text:find('boom') ~= nil, 'stderr included')
end

-- run_command: cwd outside the roots is rejected.
do
    local _, err = tools.call('run_command', { cmd = { 'echo' }, cwd = '/etc' }, GRANT)
    check(err ~= nil and err.code == -32602, 'cwd escape -> -32602')
end

-- search_text: hits cap at 100.
do
    policy.setup({ roots = { tmp } })
    stub._executables = { rg = true }
    local out = {}
    for i = 1, 150 do
        out[#out + 1] = 'f.txt:' .. i .. ':hit'
    end
    stub._system_impl = function(_, _)
        return { code = 0, stdout = table.concat(out, '\n'), stderr = '' }
    end
    local res = call_ok('search_text', { pattern = 'hit', dir = tmp })
    local count = 0
    for _ in res.content[1].text:gmatch('[^\n]+') do
        count = count + 1
    end
    check(count == 100, 'hits cap at 100, got ' .. count)
end

-- list_files: entries cap at 500 with a truncation note.
do
    local many = tmp .. '/many'
    vim.fn.mkdir(many, 'p')
    for i = 1, 505 do
        stub.write_file(many .. '/f' .. i, 'x')
    end
    local res = call_ok('list_files', { dir = many })
    local count = 0
    for _ in res.content[1].text:gmatch('[^\n]+') do
        count = count + 1
    end
    check(count == 501, '500 entries + truncation note, got ' .. count)
    check(res.content[1].text:find('truncated at 500') ~= nil, 'truncation is disclosed')
end

os.execute('rm -rf ' .. stub.shquote(tmp))
print('ok tools_adversarial: ' .. passed .. ' checks')
