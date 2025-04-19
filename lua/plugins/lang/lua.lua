-- ~/.config/nvim/lua/plugins/lang/lua.lua
return {
    {
    "folke/lazydev.nvim",
    ft = "lua",
    dependencies = {
      "folke/neoconf.nvim",
      "camspiers/luarocks",
      "saghen/blink.cmp",
      "stevearc/conform.nvim",
      "nvimtools/none-ls.nvim",
      "gbprod/none-ls-luacheck.nvim",
      "folke/trouble.nvim",
      "nvimtools/none-ls-extras.nvim"},
      lazy = true,
      config = function(opts)
        require("config.lua").setup_all(opts)
      end,
    }
  }
