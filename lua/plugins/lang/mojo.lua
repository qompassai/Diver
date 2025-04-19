return {
  "qompassai/blaze.nvim",
  lazy = true,
  ft = { "mojo", "🔥" },
  config = function()
    require("blaze.config").setup({
      format_on_save = true,
      enable_linting = true,
      dap = { enabled = true },
      keymaps = true,
    })
  end,
}
