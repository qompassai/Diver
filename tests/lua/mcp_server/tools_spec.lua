-- Validation spec: MCP tool registry + read tools + get_diagnostics.
-- Run: lua tests/lua/mcp_server/tools_spec.lua
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

local tmp = stub.fresh_dir('tools_spec')
policy.setup({ roots = { tmp } })
tools.setup()

local function call(name, args, meta)
    local result, err = tools.call(name, args or {}, meta)
    check(err == nil, 'no protocol error for ' .. name .. ': ' .. (err and err.message or ''))
    check(result ~= nil, 'result for ' .. name)
    return result
end

-- tools/list: seven tools, sorted, no handlers on the wire, honest hints.
do
    local list = tools.list()
    check(#list == 7, 'seven MVP tools, got ' .. #list)
    local names = {}
    for _, def in ipairs(list) do
        names[#names + 1] = def.name
        check(def.handler == nil, 'handler not exposed for ' .. def.name)
        check(type(def.inputSchema) == 'table', 'inputSchema for ' .. def.name)
        check(type(def.annotations) == 'table', 'annotations for ' .. def.name)
    end
    local sorted = {}
    for _, n in ipairs(names) do
        sorted[#sorted + 1] = n
    end
    table.sort(sorted)
    check(table.concat(names, ',') == table.concat(sorted, ','), 'tools/list is sorted')
    local by_name = {}
    for _, def in ipairs(list) do
        by_name[def.name] = def
    end
    for _, name in ipairs({ 'read_file', 'list_files', 'search_text', 'get_diagnostics' }) do
        check(by_name[name].annotations.readOnlyHint == true, name .. ' is readOnlyHint')
        check(by_name[name].annotations.idempotentHint == true, name .. ' is idempotentHint')
    end
    check(by_name.write_file.annotations.destructiveHint == true, 'write_file destructiveHint')
    check(by_name.run_command.annotations.openWorldHint == true, 'run_command openWorldHint')
    check(by_name.run_command.annotations.readOnlyHint == false, 'run_command not readOnly')
end

-- read_file: happy path, offset/limit window.
do
    local path = tmp .. '/read.txt'
    local lines = {}
    for i = 1, 20 do
        lines[#lines + 1] = 'line ' .. i
    end
    stub.write_file(path, table.concat(lines, '\n') .. '\n')
    local res = call('read_file', { path = path })
    check(res.isError ~= true, 'read_file succeeds')
    check(res.content[1].text:find('line 1\n') ~= nil, 'content starts at line 1')
    local res2 = call('read_file', { path = path, offset = 5, limit = 3 })
    check(res2.content[1].text == 'line 5\nline 6\nline 7', 'offset/limit window exact')
end

-- read_file: limit clamps to the 2000-line window.
do
    local path = tmp .. '/big.txt'
    local lines = {}
    for i = 1, 2500 do
        lines[#lines + 1] = 'l' .. i
    end
    stub.write_file(path, table.concat(lines, '\n'))
    local res = call('read_file', { path = path, limit = 1000000 })
    local count = 0
    for _ in res.content[1].text:gmatch('[^\n]+') do
        count = count + 1
    end
    check(count == 2000, 'limit clamps to 2000 lines, got ' .. count)
end

-- read_file: missing file is an execution failure (isError), not a
-- protocol error.
do
    local res = call('read_file', { path = tmp .. '/nope.txt' })
    check(res.isError == true, 'missing file -> isError=true')
    check(res.content[1].text:find('cannot read') ~= nil, 'isError explains')
end

-- list_files: sorted entries, directories suffixed, glob filter.
do
    vim.fn.mkdir(tmp .. '/sub', 'p')
    stub.write_file(tmp .. '/b.lua', 'x')
    stub.write_file(tmp .. '/a.txt', 'x')
    stub.write_file(tmp .. '/sub/c.txt', 'x')
    local res = call('list_files', { dir = tmp })
    check(res.isError ~= true, 'list_files succeeds')
    local text = res.content[1].text
    check(text:find('sub/') ~= nil, 'directory suffixed with /')
    check(text:find('a.txt') ~= nil and text:find('b.lua') ~= nil, 'files listed')
    local res2 = call('list_files', { dir = tmp, glob = '*.lua' })
    check(res2.content[1].text == 'b.lua', 'glob filters to *.lua')
end

-- search_text: rg argv form, pattern passed literally.
do
    local seen_cmd = nil
    stub._executables = { rg = true }
    stub._system_impl = function(cmd, _)
        seen_cmd = cmd
        return { code = 0, stdout = 'a.txt:3:hello world\n', stderr = '' }
    end
    local res = call('search_text', { pattern = 'hello; rm -rf', dir = tmp })
    check(res.isError ~= true, 'search succeeds')
    check(res.content[1].text == 'a.txt:3:hello world', 'hit text returned')
    check(seen_cmd[1] == 'rg', 'argv[0] is rg')
    local found = false
    for _, part in ipairs(seen_cmd) do
        if part == 'hello; rm -rf' then
            found = true
        end
        check(type(part) == 'string', 'argv element is a string')
    end
    check(found, 'pattern travels as one literal argv element')
    check(seen_cmd[#seen_cmd] == tmp, 'search scoped to dir')
end

-- search_text: rg exit 1 means no matches, not an error.
do
    stub._system_impl = function(_, _)
        return { code = 1, stdout = '', stderr = '' }
    end
    local res = call('search_text', { pattern = 'zzz_no_match', dir = tmp })
    check(res.isError ~= true, 'no matches is not an error')
    check(res.content[1].text == 'no matches', 'no-matches text')
end

-- search_text: missing rg is an honest isError.
do
    stub._executables = {}
    local res = call('search_text', { pattern = 'x', dir = tmp })
    check(res.isError == true, 'missing rg -> isError')
    check(res.content[1].text:find('ripgrep') ~= nil, 'explains rg is missing')
end

-- get_diagnostics: linter findings are data (isError false).
do
    stub._executables = { luacheck = true }
    local seen_cmd = nil
    stub._system_impl = function(cmd, _)
        seen_cmd = cmd
        return { code = 1, stdout = 'x.lua:1:1: (W211) unused variable\n', stderr = '' }
    end
    stub.write_file(tmp .. '/x.lua', 'local unused = 1\n')
    local res = call('get_diagnostics', { path = tmp .. '/x.lua' })
    check(res.isError ~= true, 'linter findings are not errors')
    check(res.content[1].text:find('W211') ~= nil, 'finding text returned')
    check(seen_cmd[1] == 'luacheck', 'luacheck invoked')
    check(seen_cmd[#seen_cmd]:find('x.lua$') ~= nil, 'scoped path passed')
end

-- get_diagnostics: .py extension dispatches to ruff.
do
    stub._executables = { ruff = true }
    local seen_cmd = nil
    stub._system_impl = function(cmd, _)
        seen_cmd = cmd
        return { code = 1, stdout = 'x.py:1:1: F401 unused import\n', stderr = '' }
    end
    stub.write_file(tmp .. '/x.py', 'import os\n')
    local res = call('get_diagnostics', { path = tmp .. '/x.py' })
    check(res.isError ~= true, '.py findings are not errors')
    check(seen_cmd[1] == 'ruff', 'ruff invoked for .py')
end

-- get_diagnostics: no linter installed -> honest isError.
do
    stub._executables = {}
    local res = call('get_diagnostics', { path = tmp .. '/x.lua' })
    check(res.isError == true, 'missing linter -> isError')
end

-- get_diagnostics: unsupported extension -> honest isError.
do
    stub._executables = { luacheck = true }
    stub.write_file(tmp .. '/x.zzz', '???')
    local res = call('get_diagnostics', { path = tmp .. '/x.zzz' })
    check(res.isError == true, 'unknown extension -> isError')
end

-- Unknown tool is a protocol error (-32602), distinct from isError.
do
    local result, err = tools.call('nope', {}, nil)
    check(result == nil, 'no result for unknown tool')
    check(err ~= nil and err.code == -32602, 'unknown tool -> -32602')
end

-- Bad shapes are protocol errors: missing required, wrong type, unknown arg.
do
    local _, e1 = tools.call('read_file', {}, nil)
    check(e1 ~= nil and e1.code == -32602, 'missing path -> -32602')
    local _, e2 = tools.call('read_file', { path = 42 }, nil)
    check(e2 ~= nil and e2.code == -32602, 'non-string path -> -32602')
    local _, e3 = tools.call('read_file', { path = tmp .. '/a.txt', bogus = 1 }, nil)
    check(e3 ~= nil and e3.code == -32602, 'unknown argument -> -32602')
end

-- Every tools/call is audited.
do
    local before = #stub._audit_records
    call('read_file', { path = tmp .. '/a.txt' })
    check(#stub._audit_records == before + 1, 'tool call audited')
    local rec = stub._audit_records[#stub._audit_records]
    check(rec.via == 'mcp-server' and rec.tool == 'read_file', 'audit record shape')
end

os.execute('rm -rf ' .. stub.shquote(tmp))
print('ok tools_spec: ' .. passed .. ' checks')
