return {
  "qompassai/blaze.nvim",
  ft = { "mojo", "🔥" },
  config = function(opts)
    require("config.lang.mojo").setup_mojo(opts)
  end,
}
