-- /qompassai/Diver/lua/plugins/lang/python.lua
-- ----------------------------------------
-- Copyright (C) 2025 Qompass AI, All rights reserved
return {
  {
    "neovim/nvim-lspconfig",
    lazy = true,
    ft = { "python", "ipynb", "jupyter" },
    dependencies = {
      "williamboman/mason-lspconfig.nvim",
      "nvimtools/none-ls.nvim",
      "jpalardy/vim-slime",
      "quarto-dev/quarto-nvim",
      "jbyuki/nabla.nvim",
      "benlubas/molten-nvim",
      "nvim-treesitter/nvim-treesitter",
      {
        "benomahony/uv.nvim",
        lazy = true,
        opts = {
          picker_integration = true,
        },
      },
      "mfussenegger/nvim-dap",
      "rcarriga/nvim-dap-ui",
      "mfussenegger/nvim-dap-python",
      "bfredl/nvim-jupyter",
      "stevearc/dressing.nvim",
      {
        "linux-cultist/venv-selector.nvim",
        branch = "regexp",
        lazy = true,
        ft = { "python", "ipynb", "jupyter" },
        keys = {
          { ",v", "<cmd>VenvSelect<cr>", desc = "Select Python venv" },
          {
            ",V",
            "<cmd>VenvSelectCached<cr>",
            desc = "Use cached venv",
          },
        },
        opts = {
          stay_on_this_version = true,
          name = ".venv",
          auto_refresh = true,
          search_venv_managers = true,
          notify_user_on_activate = true,
        },
      },
      { "ibhagwan/fzf-lua", lazy = true, dependencies = { "nvim-tree/nvim-web-devicons" } },
    },
     config = function()
      require("config.lang.python").setup_python()
    end,
  },
}
