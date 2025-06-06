-- /qompassai/Diver/lua/plugins/lang/lua.lua

-- -- Copyright (C) 2025 Qompass AI, All rights reserved

-- ----------------------------------------

local lua_config = require("config.lang.lua")

return {
  {
    "folke/neoconf.nvim",
    priority = 1000,
    opts = lua_config.neoconf(),
    config = function(_, opts)
      require("neoconf").setup(opts)
    end,
  },
  {
    "folke/lazydev.nvim",
    lazy = true,
    ft = { "lua", "luau" },
    dependencies = {
      "Bilal2453/luvit-meta",
    },
    config = function(_, opts)
      lua_config.lua_lazydev(opts)
    end,
  },
  {
    "nvimtools/none-ls.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "gbprod/none-ls-luacheck.nvim",
      "nvimtools/none-ls-extras.nvim",
    },
     config = function(_, opts)
      require("null-ls").setup({
        sources = lua_config.lua_nls(opts),
      })
    end,
  },
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre", "BufNewFile" },
    config = function()
      lua_config.lua_conform()
    end,
  },
  {
    "neovim/nvim-lspconfig",
    ft = { "lua", "luau" },
    config = function()
      lua_config.lua_lsp()
    end,
  },
  {
    "folke/trouble.nvim",
    cmd = { "TroubleToggle", "Trouble" },
  },
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "L3MON4D3/LuaSnip",
      "hrsh7th/cmp-omni",
      "camspiers/luarocks",
      "camspiers/snap",
    },
    opts = function(_, opts)
      local cmp = require("cmp")
      cmp.setup(opts or {})
      cmp.setup.filetype("lua", {
        sources = cmp.config.sources({
          { name = "lazydev" },
          { name = "luasnip" },
          { name = "nvim_lsp" },
          { name = "blink" },
          { name = "nvim-cmp" },
        }),
      })
    end,
  },
  {
    "camspiers/luarocks",
    lazy = true,
    opts = {
      rocks = { "fzy", "magick" },
       enabled = false,
      hererocks = true,
    },
    config = function(_, opts)
      require("luarocks").setup(opts)
    end,
   },
  {
    "camspiers/snap",
  dependencies = { "camspiers/luarocks" },
    lazy = true,
  },
}
