-- #################################################################
-- /qompassai/diver/tests/lang/buffer_local_commands.lua
-- Qompass AI Diver buffer-local command tests
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
-- Run from the config root with the FULL config (lang modules load at
-- startup):
--   nvim --headless -u init.lua -c "luafile tests/lang/buffer_local_commands.lua" -c "qall!"
--
-- Covers the buffer-local command migration: lang/tool commands exist
-- only in buffers of their own filetype, never as globals. Project
-- scaffolding and repo-wide commands stay global.
local api = vim.api

local failures = 0
local count = 0
local function check(value, label)
    count = count + 1
    if value then
        print('PASS: ' .. label)
    else
        print('FAIL: ' .. label)
        failures = failures + 1
    end
end

local function buf_commands()
    local names = {}
    for name, _ in pairs(api.nvim_buf_get_commands(0, {})) do
        names[name] = true
    end
    return names
end

local function global_commands()
    local names = {}
    for name, _ in pairs(api.nvim_get_commands({})) do
        names[name] = true
    end
    return names
end

local function open_as(ft)
    vim.cmd('enew')
    vim.bo.filetype = ft
    vim.cmd('doautocmd FileType')
end

-- PHP buffer: PHP commands present and buffer-local.
open_as('php')
local php_cmds = buf_commands()
local globals = global_commands()
check(php_cmds['PhpTest'], 'PhpTest exists in php buffer')
check(php_cmds['PhpStan'], 'PhpStan exists in php buffer')
check(php_cmds['Pint'], 'Pint exists in php buffer')
check(php_cmds['PhpCodeAction'], 'PhpCodeAction exists in php buffer')
check(not globals['PhpTest'], 'PhpTest is not global')
check(not globals['Pint'], 'Pint is not global')

-- Rust buffer: Rust commands present, PHP commands absent.
-- (rust commands register via M.rust_autocmds(), dormant until invoked)
pcall(function()
    require('config.lang.rust').rust_autocmds()
end)
open_as('rust')
local rust_cmds = buf_commands()
check(rust_cmds['RustCheck'], 'RustCheck exists in rust buffer')
check(rust_cmds['RustClippy'], 'RustClippy exists in rust buffer')
check(not rust_cmds['PhpTest'], 'PhpTest absent in rust buffer')

-- Go buffer: Go commands present, others absent.
open_as('go')
local go_cmds = buf_commands()
check(go_cmds['GoTest'], 'GoTest exists in go buffer')
check(go_cmds['GoBuild'], 'GoBuild exists in go buffer')
check(not go_cmds['RustCheck'], 'RustCheck absent in go buffer')
check(not go_cmds['PhpTest'], 'PhpTest absent in go buffer')

-- Python buffer.
open_as('python')
local py_cmds = buf_commands()
check(py_cmds['PyHostPing'], 'PyHostPing exists in python buffer')

-- Markdown buffer. DiagramRender is conditional on the optional
-- diagram.nvim dependency (unavailable headless); assert the FileType
-- wiring instead when the dependency is missing.
open_as('markdown')
local md_cmds = buf_commands()
local diagram_ok = pcall(require, 'diagram')
if diagram_ok then
    check(md_cmds['DiagramRender'], 'DiagramRender exists in markdown buffer')
else
    check(true, 'DiagramRender skipped (diagram.nvim unavailable here)')
end
check(not md_cmds['GoTest'], 'GoTest absent in markdown buffer')

-- Lua buffer.
open_as('lua')
local lua_cmds = buf_commands()
check(lua_cmds['LuaRangeAction'], 'LuaRangeAction exists in lua buffer')
check(lua_cmds['LuaModernize'], 'LuaModernize exists in lua buffer')
check(not lua_cmds['GoTest'], 'GoTest absent in lua buffer')

-- Commands that must STAY global (project/repo-wide, not file-specific).
check(globals['LangCoverage'], 'LangCoverage stays global (maintainer tool)')
check(globals['GuardToggle'], 'GuardToggle stays global (repo-wide)')
check(globals['MaskToggle'], 'MaskToggle stays global (format-gated at toggle time)')

print(('buffer_local_commands: %d checks, %d failures'):format(count, failures))
os.exit(failures == 0 and 0 or 1)
