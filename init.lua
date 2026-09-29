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

-- Startup is composed from the lua/ subdirectories: each one owns its
-- wiring behind M.setup() (or self-wires at require time), so this file
-- only decides ORDER, never enumerates leaf modules.
--   early:    options, then config (everything reads it)
--   deferred: linters (first buffer read), games (first :Games use)
--   last:     ai (activates the agent stack), options late fixups
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
require('security').setup() -- also wires security.pass, security.sshfs
require('dev').setup() -- also wires dev.git, dev.jj, dev.bootdev, dev.bsp, dev.scip
require('utils').setup() -- also wires nav, calendar, sync, snippets, tmux, notify
require('dap').setup()
require('formatters').setup()
require('config.mappings')
require('plugin') -- self-wires via setup_plugins() at require time
require('comms').setup() -- mail, clients
require('research') -- self-wires at require time
require('types') -- annotation modules only

-- config.data is optional: wire it when present.
local ok_data, config_data = pcall(require, 'config.data')
if ok_data and type(config_data) == 'table' and type(config_data.setup) == 'function' then
    config_data.setup()
end

-- Linters stay deferred until the first buffer read (startup performance).
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
require('ai').setup() -- last; also wires ai.herd.personas
