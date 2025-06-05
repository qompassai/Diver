-- ~/.config/nvim/lua/plugins/ui/icons.lua
return {
  {
    "nvim-tree/nvim-web-devicons",
    lazy = true,
    config = function()
      require("config.ui.icons").setup_devicons()
    end,
  },
  {
    "yamatsum/nvim-nonicons",
    lazy = true,
    config = function()
      require("config.ui.icons").setup_nonicons()
    end,
  },
}
