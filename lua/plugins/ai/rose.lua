return {
  "qompassai/rose.nvim",
  lazy = false,
  cmd = { "Rose" },
  keys = {
    { "<leader>qr", ":Rose<CR>", desc = "[q]ompass [r]ose" },
  },
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "folke/noice.nvim",
  },
  opts = {
    model = "llama3.2:3b",
    display_mode = "float",
    show_prompt = true,
    show_model = true,
    no_auto_close = false,
    telescope_opts = {
      theme = "dropdown",
    },
  },
  config = function(_, opts)
    require("rose").setup(opts)

    require("noice").setup {
      lsp = {
        hover = {
          enabled = true,
        },
      },
      presets = {
        bottom_search = true,
        command_palette = true,
      },
    }
    pcall(io.popen, "ollama serve > /dev/null 2>&1 &")
  end,
}
