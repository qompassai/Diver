--- Navigation plugin specs — plugins for moving around code.
---
--- Plain-language version: this file lists the plugins that help you jump around your codebase (file finders,
--- symbol browsers) and how they should be installed and configured. It is read when the plugin manager sets up
--- plugins.
---@module 'plugin.nav'
-- /qompassai/Diver/lua/plugins/nav.lua
-- Qompass AI Diver Navigation Plugins
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---Build a `vim.pack` spec (or plain URL) for a GitHub repo.
---
---Plain-language version: give it 'owner/name' and get back the full GitHub
---address; hand it a plugin spec too and it fills the address in and hands
---the spec back.
---@param repo string GitHub 'owner/name', for example 'ibhagwan/fzf-lua'.
---@param opts? vim.pack.Spec Optional spec; when given, its `src` is filled in.
---@return string|vim.pack.Spec The repo URL, or `opts` with `src` filled in.
local function gh_fallback(repo, opts)
    if opts then
        ---@cast opts vim.pack.Spec
        opts.src = 'https://github.com/' .. repo
        return opts
    end
    return 'https://github.com/' .. repo
end
-- Reuse the shared helper when plugin.cloud already defined it; otherwise use
-- the local copy so this file works standalone.
local gh = _G.gh or gh_fallback
local add = vim.pack.add
local api = vim.api
local range = vim.version.range
api.nvim_create_user_command('FzfLua', function(opts)
    local fzf = require('fzf-lua')
    local action = opts.args ~= '' and opts.args or 'files'
    fzf[action]()
end, {
    nargs = '*',
    complete = function(arg_lead, cmd_line, cursor_pos)
        return require('fzf-lua').complete(arg_lead, cmd_line, cursor_pos)
    end,
    desc = 'FzfLua fuzzy finder',
})
add({
    gh('ibhagwan/fzf-lua', {
        branch = 'main',
        cmd = { 'FzfLua' },
        hook = function()
            local fzf_config = require('config.nav.fzf')
            fzf_config.fzf_setup()
            for _, keymap in ipairs(fzf_config.keymaps) do
                vim.keymap.set(keymap[1], keymap[2], keymap[3], keymap[4] or {})
            end
        end,
        update = true,
    }),
    gh('s1n7ax/nvim-window-picker', {
        hook = function()
            require('window-picker').setup({
                filter_rules = {
                    autoselect_one = true,
                    bo = {
                        buftype = {
                            'quickfix',
                            'terminal',
                        },
                        filetype = {
                            'neo-tree',
                            'neo-tree-popup',
                            'notify',
                        },
                    },
                    include_current_win = true,
                },
            })
        end,
        update = true,
        version = range('2.*'),
    }),
    gh('MunifTanjim/nui.nvim', {
        update = true,
        version = 'main',
    }),
}, {
    confirm = false,
    load = true,
})
