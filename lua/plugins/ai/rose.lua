return {
  "qompassai/rose.nvim",
  lazy = false,
  cmd = { "Rose" },
  keys = {
    { "<leader>qr", ":Rose<CR>", desc = "[q]ompass [r]ose" },
  },
  opts = {
    model = "llama3.2:2b",
    display_mode = "float",
    show_prompt = true,
    show_model = true,
    no_auto_close = false,
  },
  config = function(_, opts)
    require("rose").setup(opts)
    pcall(io.popen, "ollama serve > /dev/null 2>&1 &")
  end,
}
