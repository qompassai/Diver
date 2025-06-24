-- /qompassai/Diver/lua/plugins/ui/icons.lua
return {
  {
    "nvim-tree/nvim-web-devicons",
    config = function()
      require("config.ui.icons").setup_devicons()
    end,
  },
  {
    "yamatsum/nvim-nonicons",
    config = function()
      require("config.ui.icons").setup_nonicons()
    end,
  },
  {
    "zakissimo/smoji.nvim",
    dependencies = {
      "stevearc/dressing.nvim"
    },
    config = function()
      require("smoji").setup()
    end,
  },
}
