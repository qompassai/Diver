--- Navigation self-test — proves the nav helpers work.
---
--- Plain-language version: this is a test script, not a feature. It exercises the core navigation helpers and
--- reports pass or fail, so regressions get caught. It runs headless via `nvim -l`; it is not loaded at startup.
---@module 'tests.core_nav'
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.g.mapleader, vim.g.maplocalleader = ' ', ','
local api, fn = vim.api, vim.fn
local count, messages = 0, {}
-- rawset bypasses LuaLS duplicate-set-field; intentional test double.
rawset(vim, 'notify', function(msg)
    messages[#messages + 1] = tostring(msg)
end)
local function check(value, message)
    assert(value, message)
    count = count + 1
end
local function wait(predicate, message)
    check(vim.wait(5000, predicate, 10), message)
end
local bundle = vim.fn.getcwd()
local root = fn.tempname() .. ' nav space'
fn.mkdir(root .. '/a', 'p')
fn.mkdir(root .. '/b', 'p')
fn.writefile({ 'local needle = 1', 'print(needle)' }, root .. '/a/sample.lua')
fn.writefile({ 'needle' }, root .. '/b/sample.lua')
vim.cmd.cd(fn.fnameescape(root))
api.nvim_cmd({ cmd = 'edit', args = { root .. '/a/sample.lua' } }, {})
vim.bo.filetype = 'lua'
local source, window = api.nvim_get_current_buf(), api.nvim_get_current_win()
local parser = require('config.core.parser')
local diagnostics =
    parser.simple_colon_parser('a/sample.lua:1:7: right\nb/sample.lua:1:1: wrong', source, { cwd = root })
check(#diagnostics == 1 and diagnostics[1].col == 6, 'Full paths isolate duplicate basenames')
check(#parser.simple_colon_parser('a/sample.lua:0:1: invalid', source, { cwd = root }) == 0, 'Reject zero lines')
require('config.core.filetype')
check(vim.filetype.match({ filename = 'CMakePresets.json' }) == 'json', 'CMake JSON remains JSON')
check(vim.filetype.match({ filename = '/test/roles/task.yml' }) == 'yaml.ansible', 'Ansible yml')
check(vim.filetype.match({ filename = '/test/example.pg.hcl' }) == 'atlas-schema-postgresql', 'HCL suffix')
local qf = require('config.core.qf')
qf.setup()
local entries = {
    { filename = root .. '/a/sample.lua', lnum = 2, col = 1, text = 'second' },
    { filename = root .. '/a/sample.lua', lnum = 1, col = 1, text = 'first' },
    { filename = root .. '/a/sample.lua', lnum = 1, col = 1, text = 'first' },
}
fn.setqflist({}, ' ', { title = 'original', items = entries, context = { owner = 'test' } })
local target = qf.target('qf')
check(qf.filter(target, 'first'), 'Filter succeeds')
check(#fn.getqflist() == 2, 'Filter result')
vim.cmd.colder()
check(#fn.getqflist() == 3, 'History restores original')
check(qf.transform(target, 'unique'), 'Unique succeeds')
check(#fn.getqflist() == 2, 'Unique removes duplicates')
check(qf.transform(target, 'sort') and fn.getqflist()[1].lnum == 1, 'Sort positions')
check(qf.remove(target, 1, 1) and #fn.getqflist() == 1, 'Remove into history')
check(qf.transfer(target) and #fn.getloclist(window) == 1, 'Copy to location list')
check(qf.filter(qf.target('loc'), 'no-match') and #fn.getloclist(window) == 0, 'Location filter')
check(#fn.getqflist() == 1, 'Location filter preserves quickfix')
local input = vim.ui.input
---@type fun(input?: string)?
local delayed = nil
rawset(vim.ui, 'input', function(_, callback)
    delayed = callback
end)
qf.run('filter', 'qf')
fn.setqflist({}, ' ', { title = 'newer', items = entries })
local prompt = assert(delayed, 'filter picker must prompt for input')
prompt('first')
check(#fn.getqflist() == 3, 'Stale filter rejected')
vim.ui.input = input
local selected
local select_ui = vim.ui.select
rawset(vim.ui, 'select', function(items, _, callback)
    selected = items
    callback(items[1])
end)
qf.history(target)
check(type(selected) == 'table' and #selected > 0, 'History picker')
rawset(vim.ui, 'select', select_ui)
fn.setqflist({}, ' ', { title = 'preview', items = entries })
qf.preview(target, 1)
check(fn.win_gettype(fn.winnr()) ~= 'preview', 'Preview preserves focus')
vim.cmd.pclose()
local async = require('config.core.async')
check(async.available(), 'Native vim.async available')
local task = async.system({ 'python3', '-c', 'print("native async")' })
local result = task:wait(5000)
check(result.code == 0 and result.stdout:find('native async', 1, true), 'Real native task process')
local complete
local process, err = async.spawn({ 'python3', '-c', 'print("x"*10000)' }, { max_output_bytes = 512 }, function(value)
    complete = value
end)
check(process and not err, 'Callback process starts')
wait(function()
    return complete ~= nil
end, 'Bounded process finishes')
check(complete.error ~= nil and #complete.stdout <= 512, 'Oversized output rejected')
complete = nil
async.spawn({ 'python3', '-c', 'import time; time.sleep(10)' }, { timeout = 50 }, function(value)
    complete = value
end)
wait(function()
    return complete ~= nil
end, 'Timeout process finishes')
local timed_out = assert(complete, 'deadline callback must deliver a result')
check(timed_out.code ~= 0, 'Deadline failure')
local observed
local cancelled = async.system({ 'python3', '-c', 'import time; time.sleep(10)' })
async.observe(cancelled, function(error)
    observed = error
end)
async.cancel(cancelled)
wait(function()
    return cancelled:completed()
end, 'Native cancellation completes')
wait(function()
    return observed ~= nil
end, 'Cancellation observer receives error')
local rg = require('config.nav.ripgrep')
local before = fn.getqflist({ id = 0 }).id
rg.search('needle', { cwd = root })
wait(function()
    return fn.getqflist({ id = 0 }).id ~= before
end, 'Real ripgrep completes')
check(#fn.getqflist() == 3, 'Three ripgrep positions')
local bad, parse_error = rg.parse('{invalid}\n', root)
check(not bad and parse_error, 'Malformed rg rejected')
local original_id = fn.getqflist({ id = 0 }).id
api.nvim_set_current_win(window)
rg.search('needle', { kind = 'loc', cwd = root })
wait(function()
    return #fn.getloclist(window) == 3
end, 'rg location results')
check(fn.getqflist({ id = 0 }).id == original_id, 'Local search preserves global list')
vim.cmd.cclose()
vim.cmd.lclose()
api.nvim_set_current_win(window)
local fzf = require('config.nav.fzf')
check(fzf.setup({ picker = 'native' }), 'Native picker setup')
local picked
rawset(vim.ui, 'select', function(items, _, callback)
    callback(items[1])
end)
fzf.fzf_pick({ { label = 'file', value = 42 } }, function(value)
    picked = value
end)
check(picked == 42, 'Native picker works without fzf')
vim.ui.select = select_ui
local searx = require('config.nav.searxng')
local parsed = searx.parse(vim.json.encode({
    results = {
        { title = 'Docs', url = 'https://example.com/docs' },
        { title = 'bad', url = 'file:///etc/passwd' },
        { title = 'bad', url = 'javascript:alert(1)' },
    },
}))
local found = assert(parsed, 'valid fixture response must parse')
check(#found == 1 and found[1].title == 'Docs', 'Only HTTP result URLs')
check(searx.parse('<html>forbidden</html>') == nil, 'Non-JSON response rejected')
local spawn, open = async.spawn, vim.ui.open
local requested, opened
rawset(async, 'spawn', function(argv, _, callback)
    requested = argv
    vim.schedule(function()
        callback({
            code = 0,
            signal = 0,
            stdout = vim.json.encode({
                results = {
                    { title = 'Doc', url = 'https://example.com/doc' },
                },
            }),
            stderr = '',
        })
    end)
    return { kill = function() end }
end)
rawset(vim.ui, 'select', function(items, _, callback)
    callback(items[1])
end)
rawset(vim.ui, 'open', function(url)
    opened = url
end)
searx.setup({ url = 'http://127.0.0.1:9999', engines = 'github' })
searx.search('query & literal', 1)
wait(function()
    return opened ~= nil
end, 'SearXNG async result')
check(vim.tbl_contains(requested, 'q=query & literal'), 'Query is one argv value')
check(requested[2] == '-q' and requested[#requested] == 'http://127.0.0.1:9999/search', 'Explicit endpoint, no curlrc')
check(opened == 'https://example.com/doc', 'Native browser opens selection')
searx.next_page()
check(vim.tbl_contains(requested, 'pageno=2'), 'Pagination')
searx.cancel()
async.spawn, vim.ui.select, vim.ui.open = spawn, select_ui, open
vim.wait(50)
-- Exercise real curl against an isolated loopback HTTP service.
local portfile = root .. '/fixture-port'
local server_done
-- The handle is only kept as a GC root so the exit callback stays alive
-- until the fixture finishes; nothing reads the handle itself.
local _ = vim.system({ 'python3', bundle .. '/tests/searx_fixture.py', portfile }, {}, function(r)
    server_done = r
end)
wait(function()
    return fn.filereadable(portfile) == 1
end, 'Loopback fixture starts')
local port = fn.readfile(portfile)[1]
local title
rawset(vim.ui, 'select', function(items, _, callback)
    title = items[1].title
    callback(items[1])
end)
rawset(vim.ui, 'open', function(url)
    opened = url
end)
opened = nil
searx.setup({ url = 'http://127.0.0.1:' .. port })
searx.search('literal & + q=one')
wait(function()
    return opened ~= nil
end, 'Real curl and JSON integration')
check(title == 'literal & + q=one', 'POST encoding preserved over HTTP')
local message_count = #messages
searx.setup({ url = 'http://127.0.0.1:' .. port .. '/forbidden' })
searx.search('permission response')
wait(function()
    return #messages > message_count
end, 'HTTP error reported')
check(messages[#messages]:find('403', 1, true), 'Disabled JSON response is visible')
wait(function()
    return server_done ~= nil
end, 'Fixture exits')
check(server_done.code == 0, 'Fixture handled both requests')
vim.ui.select, vim.ui.open = select_ui, open
searx.cancel()
-- Export and import exercise native errorformat without overwriting files.
fn.setqflist({}, ' ', { title = 'export', items = entries })
rawset(vim.ui, 'input', function(_, callback)
    callback(root .. '/errors.txt')
end)
qf.run('write_file', 'qf')
check(fn.filereadable(root .. '/errors.txt') == 1, 'Error file export')
local efm = vim.bo.errorformat
vim.bo.errorformat = '%f:%l:%c:%m'
qf.run('load_file', 'qf')
check(#fn.getqflist() == 3 and fn.getqflist()[1].text == 'second', 'Error file import')
vim.bo.errorformat = efm
vim.ui.input = input

local tree = require('config.core.tree')
tree.setup({ folds = true })
check(vim.wo.foldexpr == 'v:lua.vim.treesitter.foldexpr()', 'Native TS folds')
check(#qf.buf_get_ts_highlights(source, 1) > 0, 'Public TS highlights')
check(type(qf.buf_get_lsp_highlights(source, 1)) == 'table', 'Public semantic-token API')
tree.teardown()
api.nvim_create_user_command('ConfigSelfCheck', function() end, {})
local mappings = require('mappings')
check(mappings.setup(), 'Integrated setup')
check(
    fn.maparg(' hs', 'n', false, true).desc == 'ddxmap: Run config self-check',
    'Self-check mapping survives watcher setup'
)
check(fn.maparg(' ng', 'n', false, true).desc == 'navmap: Ripgrep to quickfix', 'rg key')
check(fn.maparg(' qf', 'n', false, true).desc:find('Filter', 1, true), 'qf key')
check(fn.maparg(',nd', 'n', false, true).lhs == nil, 'No symbol keys without LSP')
check(fn.maparg(',dr', 'n', false, true).lhs == nil, 'Lua has no unrelated debugger')
local explorer = require('config.nav.nt')
explorer.open(root)
vim.wait(100)
check(vim.bo.filetype == 'directory', 'Native directory opens')
check(fn.maparg('a', 'n', false, true).buffer == 1, 'Explorer keys buffer-local')
check(fn.maparg('a', 'n', false, true).desc == 'Explorer: Create file exclusively', 'Explorer buffer option works')
explorer.close()
api.nvim_set_current_win(window)
qf.open('qf')
check(vim.bo.filetype == 'qf', 'Quickfix filetype')
check(fn.maparg('dd', 'n', false, true).desc == 'navmap: Remove quickfix entries into history', 'Quickfix deletion key')
check(fn.maparg('p', 'n', false, true).buffer == 1, 'Quickfix preview local')
rawset(vim.ui, 'select', function(items, _, callback)
    callback(items[1])
end)
qf.pick(qf.target('qf'))
check(vim.bo.filetype ~= 'qf', 'Quickfix pick focuses source window')
vim.ui.select = select_ui
vim.cmd.cclose()
mappings.teardown()
check(fn.maparg(' ng', 'n', false, true).lhs == nil, 'Teardown removes owned navigation keys')
fn.delete(root, 'rf')
print(('PASS: %d core/navigation checks on %s'):format(count, tostring(vim.version())))
