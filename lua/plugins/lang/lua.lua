-- /qompassai/Diver/lua/plugins/lang/lua.lua

-- -- Copyright (C) 2025 Qompass AI, All rights reserved

-- ----------------------------------------

local lua_conf = require("config.lang.lua")
local lua_ft = { "lua", "luau" }
return {
  {
    "folke/neoconf.nvim",
    ft = lua_ft,
    lazy = false,
    priority = 1000,
    opts = lua_conf.neoconf(),
    config = function(_, opts)
      require("neoconf").setup(opts)
    end,
  },
  {
    "folke/lazydev.nvim",
     ft = lua_ft,
    dependencies = {
      "Bilal2453/luvit-meta",
    },
    config = function(_, opts)
      lua_conf.lua_lazydev(opts)
    end,
  },
  {
    "nvimtools/none-ls.nvim",
    ft = lua_ft,
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "gbprod/none-ls-luacheck.nvim",
      "nvimtools/none-ls-extras.nvim",
    },
    config = function(_, opts)
      require("null-ls").setup({
        sources = lua_conf.lua_nls(opts),
      })
    end,
  },
  {
    "stevearc/conform.nvim",
    ft = lua_ft,
    event = { "BufWritePre", "BufNewFile" },
    config = function()
      lua_conf.lua_conform()
    end,
  },
  {
    "neovim/nvim-lspconfig",
    ft = lua_ft,
    config = function()
      lua_conf.lua_lsp()
    end,
  },
  {
    "folke/trouble.nvim",
    ft = lua_ft,
    cmd = { "TroubleToggle", "Trouble" },
  },
  {
    "hrsh7th/nvim-cmp",
    ft = lua_ft,
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
   event = { "BufReadPre", "BufNewFile" },
  ft = lua_ft,
  opts = { ... },
  config = function(_, opts)
    require("luarocks").setup(opts)
  end,
},
{
  "camspiers/snap",
 event = { "BufReadPre", "BufNewFile" },
  ft = lua_ft,
  dependencies = { "camspiers/luarocks" },
},
}
