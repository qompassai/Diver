return {
  "akinsho/toggleterm.nvim",
  lazy = true,
  cmd = { "ToggleTerm" },
  config = function()
    require("toggleterm").setup({
      size = 20,
      open_mapping = [[<c-\>]],
      direction = "float",
    })
  end,
}
