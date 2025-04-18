---@type LazyPluginSpec
return {
  "qompassai/rose.nvim",
  lazy = true,
  enabled = true,
  config = function()
    require("rose").setup()
  end,
}
