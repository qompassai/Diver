-- ~/.config/nvim/lua/plugins/ui/css.lua
return {
  {
    "norcalli/nvim-colorizer.lua",
    lazy = true,
    ft = { "css", "scss", "less" },
    dependencies = {
      "folke/neoconf.nvim",
      "saghen/blink.cmp",
      "stevearc/conform.nvim",
      "nvimtools/none-ls.nvim",
      "nvim-treesitter/nvim-treesitter",
      "folke/trouble.nvim",
    },
    config = function(opts)
      require("config.ui.css").setup_all(opts)
    end,
  }
}
