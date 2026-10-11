-- #################################################################
-- /qompassai/diver/lua/dev/test.lua
-- Qompass AI Diver Test Runner (Tiger Style)
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
---@module 'dev.test'
--
-- In-editor test runner for the diver `tests/` tree.
--
-- Contract:
-- - Tests run in a headless nvim subprocess with the FULL config
--   (`-u init.lua`), never in the current editor instance.
-- - `:DiverTest` with no args runs the test file matching the current
--   buffer's subject (e.g. editing `lua/dev/git.lua` runs `tests/dev/`
--   and `tests/git/`); with an arg it runs that path.
-- - `:DiverTestAll` runs the whole `tests/` tree; bounded by
--   TEST_TIMEOUT_MS.
-- - Output goes to a scratch buffer; failures are listed, never thrown.

local M = {}

local api = vim.api

local rce = require('security.rce')

local setup_done = false

---Subprocess wall-clock cap per test invocation.
M.TEST_TIMEOUT_MS = 120000

---Run test files in a headless subprocess; show output in a scratch buffer.
---@param paths string[] Test files or directories (relative to config root).
local function run_tests(paths)
    local root = vim.fn.stdpath('config')
    local existing = {}
    for _, p in ipairs(paths) do
        local full = root .. '/' .. p
        if vim.fn.filereadable(full) == 1 or vim.fn.isdirectory(full) == 1 then
            existing[#existing + 1] = p
        end
    end
    if #existing == 0 then
        vim.notify('DiverTest: no test files found for ' .. table.concat(paths, ', '), vim.log.levels.WARN)
        return
    end
    -- Build a single luafile chain for files; directories expand to *.lua.
    local cmds = {}
    for _, p in ipairs(existing) do
        local full = root .. '/' .. p
        if vim.fn.isdirectory(full) == 1 then
            for _, f in ipairs(vim.fn.glob(full .. '*.lua', false, true)) do
                cmds[#cmds + 1] = string.format([[ -c "luafile %s"]], vim.fn.fnameescape(f))
            end
        else
            cmds[#cmds + 1] = string.format([[ -c "luafile %s"]], vim.fn.fnameescape(full))
        end
    end
    if #cmds == 0 then
        vim.notify('DiverTest: no .lua test files under ' .. table.concat(existing, ', '), vim.log.levels.WARN)
        return
    end
    local cmd = { 'nvim', '--headless', '--noplugin', '-u', root .. '/init.lua' }
    for _, c in ipairs(cmds) do
        -- -c args are single argv entries; split the quoted form.
        cmd[#cmd + 1] = '-c'
        cmd[#cmd + 1] = c:match([[%-c "(.*)"]])
    end
    cmd[#cmd + 1] = '-c'
    cmd[#cmd + 1] = 'qall!'

    vim.notify('DiverTest: running ' .. #cmds .. ' file(s)…')
    local result, exec_err = rce.safe_exec(cmd, {
        cwd = root,
        timeout_ms = M.TEST_TIMEOUT_MS,
    })
    local buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_name(buf, 'diver-test-output')
    local lines = {}
    if exec_err ~= nil then
        lines = { 'ERROR: ' .. exec_err }
    elseif result ~= nil then
        for line in (result.stdout .. '\n' .. (result.stderr or '')):gmatch('[^\n]+') do
            lines[#lines + 1] = line
        end
        lines[#lines + 1] = string.format('-- exit code %d --', result.code)
    end
    api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    api.nvim_set_current_buf(buf)
    vim.bo[buf].filetype = 'diver-test'
end

---Map a source path to candidate test directories.
---@param src string Absolute source path.
---@return string[] test_dirs
local function test_dirs_for(src)
    local dirs = {}
    -- lua/dev/git.lua -> tests/dev/, tests/git/
    for area in src:gmatch('lua/([^/]+)/') do
        dirs[#dirs + 1] = 'tests/' .. area .. '/'
    end
    -- lua/dev/git.lua -> tests/git.lua, tests/dev_git.lua candidates
    local base = vim.fn.fnamemodify(src, ':t:r')
    dirs[#dirs + 1] = 'tests/' .. base .. '.lua'
    return dirs
end

---Run tests for the current buffer's subject area, or the given path.
function M.run(opts)
    local target = opts.args ~= '' and opts.args or nil
    if target then
        run_tests({ target })
        return
    end
    local src = api.nvim_buf_get_name(0)
    if src == '' then
        vim.notify('DiverTest: no file for current buffer; pass a path', vim.log.levels.WARN)
        return
    end
    run_tests(test_dirs_for(src))
end

---Run the entire tests/ tree.
function M.run_all()
    run_tests({ 'tests/' })
end

function M.setup()
    if setup_done then
        return
    end
    setup_done = true
    api.nvim_create_user_command('DiverTest', function(opts)
        M.run(opts)
    end, { nargs = '?', complete = 'dir', desc = 'Run tests for current buffer or given path' })
    api.nvim_create_user_command('DiverTestAll', function()
        M.run_all()
    end, { desc = 'Run the full diver test suite headless' })
end

return M
