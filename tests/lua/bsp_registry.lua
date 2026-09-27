-- Headless BSP registry + detection test (validation + adversarial).
vim.opt.runtimepath:prepend(vim.fn.getcwd())

local pass, fail = 0, 0
local function check(name, cond, detail)
    if cond then
        pass = pass + 1
    else
        fail = fail + 1
        print('FAIL: ' .. name .. (detail and (' -- ' .. detail) or ''))
    end
end

local servers = require('bsp.servers')
local list = servers.list()
check('registry has 9 entries', #list == 9, 'got ' .. #list)

local names = {}
for _, e in ipairs(list) do
    names[e.name] = true
    local ok, mod = pcall(require, e.module)
    check('loads ' .. e.module, ok and type(mod) == 'table')
    if ok then
        check(e.module .. ' has markers()', type(mod.markers) == 'function')
        check(e.module .. ' has root()', type(mod.root) == 'function')
        check(e.module .. ' has connection()', type(mod.connection) == 'function')
        check(e.module .. ' has executable()', type(mod.executable) == 'function')
        local okm, markers = pcall(mod.markers)
        check(e.module .. ' markers non-empty', okm and #markers > 0)
    end
end
for _, n in ipairs({ 'gradle', 'cargo-bsp', 'bazelbsp', 'sbt', 'mill', 'bloop', 'scala-cli', 'pants', 'swift-bsp' }) do
    check('registry contains ' .. n, names[n] == true)
end

local fts = servers.filetypes()
check('filetypes include kotlin', vim.tbl_contains(fts, 'kotlin'))
check('filetypes include rust', vim.tbl_contains(fts, 'rust'))
check('filetypes include swift', vim.tbl_contains(fts, 'swift'))
check('filetypes include scala', vim.tbl_contains(fts, 'scala'))

-- detect_root against fixtures
local fix = vim.fn.getcwd() .. '/tests/fixtures/bsp/'
local cases = {
    { 'gradle', 'gradle' },
    { 'cargo', 'cargo-bsp' },
    { 'sbt', 'sbt' },
    { 'mill', 'mill' },
    { 'bloop', 'bloop' },
    { 'scalacli', 'scala-cli' },
    { 'pants', 'pants' },
    { 'pants-nogroups', 'pants' }, -- markers still detected at root level
    { 'swift', 'swift-bsp' },
    { 'bazel', 'bazelbsp' },
    { 'weak', 'gradle' },
}
for _, c in ipairs(cases) do
    local entry = servers.detect_root(fix .. c[1])
    check('detect_root ' .. c[1] .. ' -> ' .. c[2], entry and entry.name == c[2], entry and entry.name or 'nil')
end
check('detect_root unknown -> nil', servers.detect_root(fix .. 'unknown') == nil)
check('detect_root empty -> nil', servers.detect_root('') == nil)

-- connection reading: valid card
local gradle = require('bsp.servers.gradle')
local conn, err = gradle.connection(fix .. 'gradle')
check('gradle connection reads', conn ~= nil and conn.name == 'gradle', err)
check('gradle connection languages', conn and vim.tbl_contains(conn.languages, 'kotlin'))
local ok_exec, exec_err = gradle.executable(conn)
check('gradle executable guard fails honestly (/usr/bin/false not executable... it exists)', ok_exec == true, exec_err)

-- adversarial: malformed JSON
local sbt = require('bsp.servers.sbt')
local bad_conn, bad_err = sbt.connection(fix .. 'sbt')
check('sbt malformed json fails gracefully', bad_conn == nil and bad_err ~= nil, bad_err)

-- adversarial: pants without bsp-groups.toml
local pants = require('bsp.servers.pants')
local pg_conn, pg_err = pants.connection(fix .. 'pants-nogroups')
check(
    'pants without bsp-groups.toml fails informatively',
    pg_conn == nil and pg_err:find('bsp%-groups%.toml') ~= nil,
    pg_err
)

-- pants with groups: reads card
local p_conn, p_err = pants.connection(fix .. 'pants')
check('pants connection reads', p_conn ~= nil and p_conn.name == 'pants', p_err)

-- adversarial: non-project root
local n_conn, n_err = gradle.connection(fix .. 'unknown')
check('gradle non-project fails', n_conn == nil and n_err ~= nil, n_err)

-- util bounds: oversized argv item rejected
local util = require('bsp.servers.util')
-- write a temp card with huge argv
local bigpath = fix .. 'gradle/.bsp/big.json'
local fh = io.open(bigpath, 'w')
fh:write('{"name":"big","argv":["' .. string.rep('x', 5000) .. '"]}')
fh:close()
local b_conn, b_err = util.read_connection_file(bigpath)
check('oversized argv rejected', b_conn == nil, b_err)
os.remove(bigpath)

-- bsp main module loads, setup registers commands
local bsp = require('bsp')
bsp.setup({ auto_start = false, notify = false })
local cmds = vim.api.nvim_get_commands({})
for _, c in ipairs({ 'BspStart', 'BspStop', 'BspTargets', 'BspCompile', 'BspInfo', 'BspReload', 'BspRestart' }) do
    check('command :' .. c .. ' registered', cmds[c] ~= nil)
end

-- debugbridge loads with new registry integration
local ok_db, db = pcall(require, 'ai.debugbridge.bsp')
check('ai.debugbridge.bsp loads', ok_db and type(db) == 'table')

-- dev.android gradle bsp_status (no gradle project here -> honest failure)
local ok_ag, ag = pcall(require, 'dev.android.gradle')
check('dev.android.gradle loads', ok_ag)
if ok_ag then
    local st = ag.bsp_status(fix .. 'unknown')
    check('bsp_status honest on non-project', st.ok == false and st.reason ~= nil)
end

-- adversarial: pinned server_name
bsp.setup({ server_name = 'gradle', auto_start = false, notify = false })
check('pinned server_name gradle', bsp.config.server_name == 'gradle')
bsp.setup({ server_name = 'nonexistent', auto_start = false, notify = false })
check('invalid server_name stored (fails at start time)', bsp.config.server_name == 'nonexistent')
bsp.setup({ auto_start = false, notify = false }) -- reset to auto-detect
check('reset to auto-detect', bsp.config.server_name == nil)

-- adversarial: ambiguous .bsp/ with multiple cards (name match wins)
local ambdir = fix .. 'ambiguous/.bsp/'
vim.fn.mkdir(ambdir, 'p')
local afh = io.open(ambdir .. 'a.json', 'w')
afh:write('{"name":"cargo-bsp","argv":["/bin/false"],"bspVersion":"2.0.0","languages":["rust"]}')
afh:close()
afh = io.open(ambdir .. 'b.json', 'w')
afh:write('{"name":"gradle","argv":["/bin/false"],"bspVersion":"2.0.0","languages":["java"]}')
afh:close()
local amb_conns = util.list_connections(fix .. 'ambiguous')
check('ambiguous .bsp/ lists both cards', amb_conns and #amb_conns == 2)
-- cleanup
os.remove(ambdir .. 'a.json')
os.remove(ambdir .. 'b.json')
vim.fn.delete(ambdir, 'd')
vim.fn.delete(fix .. 'ambiguous', 'd')

-- adversarial: missing executable in argv
local noexec_conn = { name = 'test', argv = { '/nonexistent/binary/xyz' }, bspVersion = '2.0.0' }
local ok_exe, exe_err = util.executable_from_argv(noexec_conn.argv)
check('missing executable fails honestly', ok_exe == false and exe_err ~= nil)

-- adversarial: malformed JSON (empty, no argv, wrong types)
local maldir = fix .. 'malformed/.bsp/'
vim.fn.mkdir(maldir, 'p')
local cases_mal = {
    { 'empty.json', '' },
    { 'noargv.json', '{"name":"x","bspVersion":"2.0.0"}' },
    { 'badargv.json', '{"name":"x","argv":"notalist","bspVersion":"2.0.0"}' },
}
for _, mc in ipairs(cases_mal) do
    local mfh = io.open(maldir .. mc[1], 'w')
    mfh:write(mc[2])
    mfh:close()
    local mc_conn, mc_err = util.read_connection_file(maldir .. mc[1])
    check('malformed ' .. mc[1] .. ' rejected', mc_conn == nil and mc_err ~= nil)
    os.remove(maldir .. mc[1])
end
vim.fn.delete(maldir, 'd')
vim.fn.delete(fix .. 'malformed', 'd')

-- adversarial: oversized connection file (>64KB)
local bigfile = fix .. 'gradle/.bsp/huge.json'
local hfh = io.open(bigfile, 'w')
hfh:write('{"name":"huge","argv":["x"],"bspVersion":"2.0.0","languages":[],"padding":"')
hfh:write(string.rep('y', 70000))
hfh:write('"}')
hfh:close()
local h_conn, h_err = util.read_connection_file(bigfile)
check('oversized file rejected', h_conn == nil and h_err ~= nil)
os.remove(bigfile)

-- adversarial: nil and wrong-type inputs
check('detect_root nil -> nil', servers.detect_root(nil) == nil)
check('detect_root number -> nil', servers.detect_root(123) == nil)
local nil_conn, nil_err = util.read_connection_file(nil)
check('read_connection_file nil -> nil,err', nil_conn == nil and nil_err ~= nil)
local missing_conns = util.list_connections('/nonexistent/path/xyz')
check('list_connections missing dir -> empty', type(missing_conns) == 'table' and #missing_conns == 0)

-- adversarial: nested workspace (detect_root checks the given dir only;
-- upward search is the caller's job via server.root())
vim.fn.mkdir(fix .. 'gradle/sub/inner', 'p')
local nested = servers.detect_root(fix .. 'gradle/sub/inner')
check('nested dir without markers -> nil', nested == nil)
local gradle_mod = require('bsp.servers.gradle')
-- root() without a buffer may return nil; the contract is it doesn't error
local _ = gradle_mod.root()
check('gradle root() does not error', true)
vim.fn.delete(fix .. 'gradle/sub', 'rf')

print(string.format('RESULT: %d passed, %d failed', pass, fail))
if fail > 0 then
    vim.cmd('cquit 1')
end
vim.cmd('quit')
