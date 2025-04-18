-- Replacing Telescope with fzf-lua (full feature parity)
return {
  "ibhagwan/fzf-lua",
  dependencies = {
    "nvim-tree/nvim-web-devicons",
    "folke/tokyonight.nvim",
    "nvim-lua/plenary.nvim",
  },
  lazy = true,
  cmd = "FzfLua",
  keys = function()
    return {
      { "<leader>ff", "<cmd>FzfLua files<cr>", desc = "Find Files" },
      { "<leader>fb", "<cmd>FzfLua buffers<cr>", desc = "Find Buffers" },
      { "<leader>fg", "<cmd>FzfLua live_grep<cr>", desc = "Live Grep" },
      { "<leader>th", "<cmd>FzfLua colorschemes<cr>", desc = "Choose Colorscheme" },
    }
  end,
  opts = function()
    return {
      winopts = {
        height = 0.85,
        width = 0.85,
        preview = { layout = "flex" },
      },
      fzf_opts = {
        ["--layout"] = "reverse-list",
        ["--info"] = "inline",
      },
    }
  end,
  config = function(_, opts)
    local fzf = require("fzf-lua")
    fzf.setup(opts)

    -- Optional: Load additional features/extensions if needed
    -- fzf.register_ui_select() -- if you want ui-select like dropdown
    -- fzf.setup_conda()        -- if you want conda environments, custom extension needed
  end,
}
