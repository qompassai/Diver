-- /qompassai/Diver/lua/plugins/init.lua
-- Qompass AI Diver Plugins Init
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@meta
vim.opt.packpath = vim.opt.runtimepath:get() ---@type string[]
vim.api.nvim_create_user_command('PackUpdate', function()
    vim.api.nvim_echo({
        {
            'Updating plugins…',
            'None',
        },
    }, false, {})
    vim.pack.update()
    vim.api.nvim_echo({
        {
            'Plugins updated!',
            'None',
        },
    }, false, {})
end, {
    desc = 'Update all vim.pack plugins',
})
vim.pack.add({
    {
        event = {
            'BufEnter',
        },
        branch = 'main',
        hook = function()
            require('config.cicd.sops').sops()
        end,
        src = 'https://github.com/trixnz/sops.nvim',
        update = true,
        version = nil,
    },
    {
        branch = 'main',
        hook = function()
            local lua_cfg = require('config.lang.lua')
            local opts = lua_cfg.lua_luarocks({})
            --require('luarocks-nvim').setup(opts)
            require('luarocks').setup(opts)
        end,
        src = 'https://github.com/vhyrro/luarocks.nvim',
        update = true,
        version = nil,
    },
    {
        branch = 'main',
        src = 'https://github.com/Saghen/blink.cmp',
        update = true,
        version = vim.version.range('1.*'),
    },
    {
        branch = 'main',
        hook = function()
            require('config.core.tree').treesitter({})
        end,
        src = 'https://github.com/nvim-treesitter/nvim-treesitter',
        update = true,
        version = nil,
    },
    {
        branch = 'master',
        src = 'https://github.com/L3MON4D3/LuaSnip',
        version = vim.version.range('2.*'),
    },
    {
        branch = 'main',
        src = 'https://github.com/rafamadriz/friendly-snippets',
        update = true,
        version = nil,
    },
    {
        branch = 'main',
        src = 'https://github.com/hrsh7th/cmp-nvim-lua',
        update = true,
        version = nil,
    },
    {
        branch = 'main',
        src = 'https://github.com/hrsh7th/cmp-buffer',
        version = nil,
    },
    {
        branch = 'master',
        src = 'https://github.com/moyiz/blink-emoji.nvim',
        version = nil,
    },
    {
        branch = 'master',
        src = 'https://github.com/Kaiser-Yang/blink-cmp-dictionary',
        update = true,
        version = vim.version.range('2.*'),
    },
    {
        branch = 'main',
        src = 'https://github.com/Saghen/blink.compat',
        update = true,
        version = vim.version.range('2.*'),
    },
    {
        branch = 'main',
        hook = function()
            require('config.core.flash').flash_cfg()
        end,
        src = 'https://github.com/folke/flash.nvim',
        update = true,
        version = vim.version.range('2.*'),
    },

    {
        branch = 'main',
        hook = function()
            require('mini.ai').setup()
        end,
        opts = {
            custom_textobjects = {},
            n_lines = 500,
            search_method = 'cover_or_next',
        },
        src = 'https://github.com/echasnovski/mini.nvim',
        update = true,
        version = vim.version.range('0.*'),
    },
    {
        cmd = {
            'TroubleToggle',
            'Trouble',
        },
        hook = function(spec)
            require('trouble').setup(spec.opts)
        end,
        opts = require('config.core.trouble')(),
        src = 'https://github.com/folke/trouble.nvim',
    },
})
return {
    {
        import = 'plugins.core',
    },
    {
        {
            import = 'plugins.cloud',
        },
        {
            import = 'plugins.data',
        },
        {
            import = 'plugins.edu',
        },
        {
            import = 'plugins.cicd',
        },
        {
            import = 'plugins.lang',
        },
        {
            import = 'plugins.nav',
        },
        {
            import = 'plugins.ui',
        },
    },
}