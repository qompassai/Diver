-- tests/git_hardening.lua
-- Regression check for utils.git repo-config hardening (CVE-2026-129128).
-- Run from the config root (repo checkout or live ~/.config/nvim):
--   nvim --headless -i NONE -u NONE -c "luafile tests/git_hardening.lua"
-- Builds a hostile fixture repo whose diff.external and core.fsmonitor
-- point at marker-writing scripts. Control: raw git fires both vectors.
-- Hardened: utils.git fires neither and still reports real data.
-- Exit code 0 on success, 1 on any failure.

local root = vim.fn.getcwd()
vim.opt.runtimepath:prepend(root)

local git = require('utils.git')

local failures = 0
local function check(name, ok)
    if ok then
        print('PASS ' .. name)
    else
        failures = failures + 1
        print('FAIL ' .. name)
    end
end

local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, 'p')
local ext_marker = tmp .. '/extdiff-fired'
local fsm_marker = tmp .. '/fsmonitor-fired'

local function write_script(name, marker)
    local path = tmp .. '/' .. name
    vim.fn.writefile({ '#!/bin/sh', "touch '" .. marker .. "'" }, path)
    vim.fn.setfperm(path, 'rwxr-xr-x')
    return path
end

local ext_script = write_script('ext.sh', ext_marker)
local fsm_script = write_script('fsm.sh', fsm_marker)

local function raw(args)
    local argv = { 'git', '-C', tmp }
    vim.list_extend(argv, args)
    return vim.fn.system(argv)
end

raw({ 'init', '-q' })
raw({ 'config', 'diff.external', ext_script })
raw({ 'config', 'core.fsmonitor', fsm_script })
vim.fn.writefile({ 'one' }, tmp .. '/tracked.txt')
raw({ 'add', 'tracked.txt' })
raw({ '-c', 'user.email=test@example.invalid', '-c', 'user.name=test', 'commit', '-qm', 'init' })
vim.fn.writefile({ 'one', 'two' }, tmp .. '/tracked.txt')

-- Control: unhardened git fires both vectors in this fixture.
raw({ 'status', '--porcelain' })
raw({ 'diff' })
check('control: fsmonitor fires under raw git', vim.fn.filereadable(fsm_marker) == 1)
check('control: external diff fires under raw git', vim.fn.filereadable(ext_marker) == 1)
vim.fn.delete(ext_marker)
vim.fn.delete(fsm_marker)

-- Hardened: the editor's own query shapes fire neither, and still report.
local status = git.lines({ 'status', '--porcelain' }, tmp)
local found = false
for _, line in ipairs(status) do
    if line:find('tracked.txt', 1, true) then
        found = true
    end
end
check('hardened status still reports the modified file', found)
local numstat = git.lines({ 'diff', '--numstat', 'HEAD' }, tmp)
check('hardened diff --numstat still reports', #numstat >= 1)
check('fsmonitor never fires through utils.git', vim.fn.filereadable(fsm_marker) == 0)
check('external diff never fires through utils.git', vim.fn.filereadable(ext_marker) == 0)

vim.fn.delete(tmp, 'rf')
os.exit(failures == 0 and 0 or 1)
