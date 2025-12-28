-- /qompassai/Diver/lua/plugins/init.lua
-- Qompass AI Diver Plugins Init
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@meta
vim.opt.packpath = vim.opt.runtimepath:get() ---@type string[]
vim.pack.add {
  {
    src = 'https://github.com/trixnz/sops.nvim'
  },
  --{
  --  src = 'https://github.com/vhyrro/luarocks.nvim'
  --},
  {
    src = 'https://github.com/Saghen/blink.cmp'
  },
  {
    src = 'https://github.com/nvim-treesitter/nvim-treesitter'
  },
  {
    src = 'https://github.com/L3MON4D3/LuaSnip'
  },
  {
    src = 'https://github.com/rafamadriz/friendly-snippets'
  },
  {
    src = 'https://github.com/hrsh7th/cmp-nvim-lua'
  },
  {
    src = 'https://github.com/hrsh7th/cmp-buffer'
  },
  {
    src = 'https://github.com/moyiz/blink-emoji.nvim'
  },
  {
    src = 'https://github.com/Kaiser-Yang/blink-cmp-dictionary'
  },
  {
    src = 'https://github.com/Saghen/blink.compat'
  },
}

return {
  {
    import = 'plugins.core',
  },
  {
    import = 'plugins.ai',
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