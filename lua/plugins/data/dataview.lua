return {
  "vidocqh/data-viewer.nvim",
  enabled = true,
  lazy = false,
  opts = {},
  dependencies = {
    "nvim-lua/plenary.nvim",
    "chrisbra/csv.vim",
    "dhruvasagar/vim-table-mode",
    "kkharji/sqlite.lua",
    "hat0uma/csvview.nvim",
    config = function()
      require("csvview").setup()
    end,
  },
}
