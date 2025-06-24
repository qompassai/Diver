return {
 {
  "folke/which-key.nvim",
  config = function()
    require("which-key").setup({
    })
    if require("which-key").health and require("which-key").health.check then
      require("which-key").health.check = function() return {} end
    end
  end
}
}
