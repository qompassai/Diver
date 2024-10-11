return
    {
    "David-Kunz/gen.nvim",
    lazy = false,
    cmd = { "Gen" },
    keys = {
      { "<leader>g", ":Gen<CR>", desc = "Generate with Gen.nvim" }, -- Lazy load on keybinding
    },
    opts = {
      model = "phi3.5",
      display_mode = "float",
      show_prompt = false,
      show_model = false,
      no_auto_close = false,
    },
    config = function(_, opts)
      require("gen").setup(opts)
      pcall(io.popen, "ollama serve > /dev/null 2>&1 &")
        end
  }
