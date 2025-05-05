-- ~/.config/nvim/lua/plugins/lang/lua.lua
return {
  {
    "folke/neoconf.nvim",
    lazy = false,
    priority = 1000,
  },
  {
    "folke/lazydev.nvim",
    lazy = true,
    ft = "lua",
    dependencies = {
      "camspiers/luarocks",
      "saghen/blink.cmp",
      "stevearc/conform.nvim",
      "folke/trouble.nvim",
      "nvimtools/none-ls.nvim",
      "gbprod/none-ls-luacheck.nvim",
      "nvimtools/none-ls-extras.nvim"
    },
  }
}
