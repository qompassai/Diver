-- /qompassai/Diver/lua/plugins/init.lua
-- Qompass AI Diver Plugins Init
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@meta
vim.opt.packpath = vim.opt.runtimepath:get() ---@type string[]
vim.pack.add({
    {
        event = {
            'BufEnter',
        },
        src = 'https://github.com/trixnz/sops.nvim',
    },
    {
        src = 'https://github.com/vhyrro/luarocks.nvim',
        version = nil,
    },
    {
        branch = 'main',
        src = 'https://github.com/Saghen/blink.cmp',
        version = vim.version.range('1.*'),
    },
    {
        src = 'https://github.com/nvim-treesitter/nvim-treesitter',
    },
    {
        src = 'https://github.com/nathom/filetype.nvim',
    },
    {
        src = 'https://github.com/L3MON4D3/LuaSnip',
    },
    {
        src = 'https://github.com/rafamadriz/friendly-snippets',
    },
    {
        src = 'https://github.com/hrsh7th/cmp-nvim-lua',
    },
    {
        brance = 'main',
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
        version = vim.version.range('2.*'),
    },
    {
        branch = 'main',
        src = 'https://github.com/Saghen/blink.compat',
        version = vim.version.range('2.*'),
    },
    {
        name = 'flash.nvim',
        src = 'https://github.com/folke/flash.nvim',
        hook = function()
            require('config.core.flash').flash_cfg()
        end,
    },
    --[[
  {
    cond = function()
      return vim.env.GITLAB_TOKEN ~= nil and vim.env.GITLAB_TOKEN ~= ''
    end,
    event = {
      'BufReadPre',
      'BufNewFile'
    },
    filetypes = {
      'go',
      'javascript',
      'python',
      'ruby'
    },
    src = 'https://gitlab.com/gitlab-org/editor-extensions/gitlab.vim.git',
    opts = {
      statusline = {
        enabled = true,
      },
    },
  },
  --]]
    {
        branch = 'main',
        hook = function()
            require('mini.ai').setup()
        end,
        name = 'mini.ai',
        opts = {
            n_lines = 500,
            custom_textobjects = {},
            search_method = 'cover_or_next',
        },
        src = 'https://github.com/echasnovski/mini.nvim',
        version = 'v0.17.0',
    },
    {
        name = 'trouble.nvim',
        src = 'https://github.com/folke/trouble.nvim',
        cmd = {
            'TroubleToggle',
            'Trouble',
        },
        opts = require('config.core.trouble')(),
        hook = function(spec)
            require('trouble').setup(spec.opts)
        end,
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
