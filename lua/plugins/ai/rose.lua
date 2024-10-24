return {
  "qompassai/rose.nvim",
  lazy = true,
  cmd = { "Rose" },
  keys = {
    { "<leader>qr", ":Rose<CR>", desc = "" },
  },
  opts = {
    model = "phi3.5",
    display_mode = "float",
    show_prompt = false,
    show_model = true,
    no_auto_close = false,
  },
  config = function(_, opts)
    require("gen").setup(opts)
    pcall(io.popen, "ollama serve > /dev/null 2>&1 &")
  end,
}
