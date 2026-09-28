#!/usr/bin/env luajit
---@version >5.1
-- /qompassai/Diver/init.lua
-- Qompass AI Diver Init
--[[
Copyright (C) 2026 Qompass AI

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
--]]
-- --------------------------------------------------

local env = vim.env
local fn = vim.fn
local is_windows = fn.has('win32') == 1 or fn.has('win64') == 1
local l = vim.loader
vim.keymap.set('n', '<Space>', '<Nop>', {
    silent = true,
})
require('utils.options').setup_early()
if not is_windows then
    env.MOJO_STDLIB_PATH = fn.expand('~/.local/share/mojo/.pixi/envs/default/lib/mojo')
else
    env.MOJO_STDLIB_PATH = fn.expand('~/AppData/Local/mojo/.pixi/envs/default/lib/mojo')
end
l.enable()
require('config.init').config({
    core = true,
    cicd = true,
    cloud = true,
    debug = false,
    edu = true,
    lang = true,
    nav = true,
    ui = true,
})
require('config.ui.render').setup()
require('security').setup()
require('dev.git').setup()
require('ai.herd.personas').setup()
require('utils.nav').setup()
require('utils.calendar').setup()
require('utils.sync').setup()
require('dev.jj').setup()
require('dev.bootdev').setup()
require('security.pass').setup()
require('dev.bsp')
require('dap').setup()
require('formatters')
require('utils')
require('utils.snippets').setup()
require('config.mappings')
require('utils.tmux').setup({ keymaps_enabled = false })
require('utils.notify').setup()
require('plugin')
require('dev.scip')
require('security.sshfs').setup()
for _, name in ipairs({
    'formatters',
    'config.data',
}) do
    local ok, mod = pcall(require, name)
    if ok and type(mod) == 'table' and type(mod.setup) == 'function' then
        mod.setup()
    end
end
vim.api.nvim_create_autocmd('BufReadPre', {
    once = true,
    group = vim.api.nvim_create_augroup('DiverDeferLinters', { clear = true }),
    callback = function()
        local ok, linters = pcall(require, 'linters')
        if ok and type(linters) == 'table' and type(linters.setup) == 'function' then
            pcall(linters.setup)
        end
        local ok2, core_lint = pcall(require, 'config.core.lint')
        if ok2 and type(core_lint) == 'table' and type(core_lint.setup) == 'function' then
            pcall(core_lint.setup)
        end
    end,
})
require('utils.options').setup_late()
require('ai').setup()
