return {
  "jalvesaq/zotcite",
  lazy = false,
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-telescope/telescope.nvim",
  },
  config = function()
    require("zotcite").setup {}
  end,
}
