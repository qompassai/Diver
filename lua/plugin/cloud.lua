--- Cloud plugin specs — plugins for working with cloud services.
---
--- Plain-language version: this file lists the plugins related to cloud workflows (deployments, remote resources)
--- and how they should be installed and configured. It is read when the plugin manager sets up plugins.
---@module 'plugin.cloud'
-- /qompassai/Diver/lua/plugins/cloud.lua
-- Qompass AI Diver Cloud Plugins
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---Build a `vim.pack` spec (or plain URL) for a GitHub repo.
---
---Plain-language version: give it 'owner/name' and get back the full GitHub
---address; hand it a plugin spec too and it fills the address in and hands
---the spec back.
---@param repo string GitHub 'owner/name', for example 'folke/which-key.nvim'.
---@param opts? vim.pack.Spec Optional spec; when given, its `src` is filled in.
---@return string|vim.pack.Spec The repo URL, or `opts` with `src` filled in.
local function gh_impl(repo, opts)
    if opts then
        ---@cast opts vim.pack.Spec
        opts.src = 'https://github.com/' .. repo
        return opts
    end
    return 'https://github.com/' .. repo
end
-- Publish the runtime implementation of the `_G.gh` global declared in the
-- type dictionary (lua/types/nvim.lua). rawset provides the value without
-- re-declaring the typed field, which the checker would flag as a duplicate.
rawset(_G, 'gh', gh_impl)
local gh = gh_impl -- local alias; luacheck does not see _G.gh as a global
local add = vim.pack.add
local range = vim.version.range
add({
    gh('chipsenkbeil/distant.nvim', {
        hook = function()
            require('distant'):setup()
        end,
        update = true,
        version = 'v0.3',
    }),
    gh('amitds1997/remote-nvim.nvim', {
        hook = function()
            require('remote-nvim').setup({
                method = 'ssh',
                default_user = os.getenv('USER'),
                picker = 'telescope',
                ssh_config = vim.fn.expand('~/.ssh/config'),
            })
        end,
        update = true,
        version = range('*'),
    }),
    gh('nosduco/remote-sshfs.nvim', {
        hook = function()
            require('remote-sshfs').setup(require('config.cloud.sshfs').opts)
            local sshfs = require('remote-sshfs')
            local fzf = require('fzf-lua')
            vim.keymap.set('n', '<leader>ss', function()
                fzf.fzf_exec(sshfs.list_connections(), {
                    prompt = 'SSHFS > ',
                    actions = {
                        ['default'] = function(selected)
                            if selected[1] then
                                sshfs.connect(selected[1])
                            end
                        end,
                    },
                })
            end, {
                desc = '[SSHFS] Connect to remote host',
            })
        end,
        update = true,
        version = 'main',
    }),
    gh('samsze0/utils.nvim', {
        update = true,
        version = 'main',
    }),
    gh('samsze0/websocket.nvim', {
        update = true,
        version = 'main',
    }),
}, {
    confirm = false,
    load = true,
})
