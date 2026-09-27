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

-- Phase 1: buffer-local options + vim.g variables (see lua/utils/options/).
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
-- Native Markdown renderer: the single attach path. setup() installs one
-- FileType autocmd for the configured filetypes and is idempotent; the
-- duplicate attach logic that used to live in config.ui is gone.
require('config.markdown.render').setup()
-- Security toolkit: registers the :SecurityAudit command and the
-- diver_security augroup. Placed after plugin-manager setup so any
-- plugin-provided commands it may need are available. setup() is idempotent.
-- Note: this wires up the audit tooling only; it does not intercept or
-- rewrite other subprocess call sites (see lua/security/*.lua).
require('security').setup()
-- Git + git-xet integration: gutter signs and the :Git* commands.
-- Placed with the other toolkit setups; setup() is idempotent and
-- performs no subprocess I/O itself.
require('git').setup()
-- Herd agent-ctrl personas: the :Personas* commands and the :HerdSpawn
-- persona picker hook. Placed with the other toolkit setups; setup() is
-- idempotent and performs no I/O itself (the agents dir is scanned lazily).
require('ai.herd.personas').setup()
-- Nav directory ring: the :Dir* commands and :Nav* checks. Placed with
-- the other toolkit setups; setup() is idempotent and performs no
-- subprocess I/O itself (disk restore only when persist_enabled).
require('nav').setup()
-- Khal calendar: floating agenda + quick-add; setup() is idempotent, no I/O at boot.
require('calendar').setup()
-- Syncthing + Tailscale phone/sync surface: the :Sync* commands.
-- Placed with the other toolkit setups; setup() is idempotent and
-- performs no subprocess I/O itself.
require('sync').setup()
-- Jujutsu (jj) integration: the :Jj dispatcher and the :Jj* checks.
-- Placed with the other toolkit setups; setup() is idempotent and
-- performs no subprocess I/O itself.
require('jj').setup()
-- pass password-store picker: the :Pass* commands.
-- Placed with the other toolkit setups; setup() is idempotent and
-- performs no subprocess I/O itself.
require('pass').setup()
require('bsp')
require('dap')
require('formatters')
require('linters')
-- utils before mappings: ddxmap's setup() guards on :Config* commands
-- created by utils/*; mapping setup must see them.
require('utils')
require('mappings')
-- Tmux navigation + layouts: keymaps disabled; genmap owns C-h/j/k/l and
-- falls through to the adjacent tmux pane at window edges via tmux.navigate().
require('tmux').setup({ keymaps_enabled = false })
-- Long-task notifications (the fish `done` plugin's model: a vim.notify +
-- notify-send toast when a wrapped task exceeds threshold_ms). Placed with
-- the other toolkit setups; setup() is idempotent and performs no
-- subprocess I/O itself.
require('tools.notify').setup()
require('plugin')
require('scip')
-- C4: these modules create their user commands only inside setup();
-- require() alone leaves the :Format*, :Lint* and :Sqlite* families dead
-- (verified exists(':Format') == 0 before this block). Each call is
-- guarded so a module without setup() stays inert.
for _, name in ipairs({ 'formatters', 'linters', 'config.data' }) do
    local ok, mod = pcall(require, name)
    if ok and type(mod) == 'table' and type(mod.setup) == 'function' then
        mod.setup()
    end
end

-- Phase 2: global + window-local options (see lua/utils/options/).
require('utils.options').setup_late()

-- Agent protocols (ACP/A2A/SDKs): commands, autocmds, and the A2A SDK
-- FileType wiring. setup() is idempotent and spawns nothing at startup.
require('ai').setup()
