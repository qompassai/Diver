-- /qompassai/Diver/lua/plugins/lang/lua.lua
-- ----------------------------------------
-- Copyright (C) 2025 Qompass AI, All rights reserved

local lua_config = require("config.lang.lua")

return {
  {
    "folke/neoconf.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("neoconf").setup(lua_config.neoconf())
    end,
  },
  {
    "folke/lazydev.nvim",
    ft = "lua",
    dependencies = {
      "Bilal2453/luvit-meta",
      "camspiers/luarocks",
      "saghen/blink.cmp",
      "stevearc/conform.nvim",
      "folke/trouble.nvim",
      "nvimtools/none-ls.nvim",
      "gbprod/none-ls-luacheck.nvim",
      "nvimtools/none-ls-extras.nvim",
      "b0o/SchemaStore.nvim",
      "L3MON4D3/LuaSnip",
      "hrsh7th/nvim-cmp",
    },
    config = function()
      lua_config.lua_lazydev()
    end,
  },
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    config = function(_, opts)
      local cmp = require("cmp")
      cmp.setup(opts)
      cmp.setup.filetype("lua", {
        sources = cmp.config.sources({
          { name = "lazydev" },
          { name = "luasnip" },
          { name = "nvim_lsp" },
        }),
      })
    end,
  },
}
