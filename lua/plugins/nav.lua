-- /qompassai/Diver/lua/plugins/nav.lua
-- Qompass AI Diver Navigation Plugins
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@return string|vim.pack.Spec
_G.gh = function(repo, opts) ---@param repo string
    if opts then ---@cast opts vim.pack.Spec
        opts.src = 'https://github.com/' .. repo
        return opts
    end
    return 'https://github.com/' .. repo
end
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
    gh('nvim-neo-tree/neo-tree.nvim', {
        cmd = {
            'Neotree',
            'NeoTreeClose',
            'NeoTreeFloat',
            'NeoTreeFocus',
            'NeoTreeReveal',
            'NeoTreeShow',
        },
        hook = function()
            require('neo-tree').setup(require('config.nav.neotree').neotree_cfg())
        end,
        update = true,
        version = range('3.*'),
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
    gh('nvim-tree/nvim-web-devicons', {
        update = true,
        version = 'master',
    }),
}, {
    confirm = false,
    load = true,
})
