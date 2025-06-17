-- /qompassai/Diver/lua/plugins/lang/python.lua
-- ----------------------------------------
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ~/.config/nvim/lua/plugins/lang/python.lua
local py_ft = { "python", "ipynb", "jupyter", "quarto" }
local jupyter_ft = { "ipynb", "jupyter", "quarto" }
local mojo_ft = { "mojo", "🔥" }
return {
  {
    "neovim/nvim-lspconfig",
    ft = py_ft,
    dependencies = {
      { "williamboman/mason-lspconfig.nvim", ft = py_ft },
      { "nvimtools/none-ls.nvim", ft = py_ft },
      { "jpalardy/vim-slime", ft = jupyter_ft },
      { "jmbuhr/otter.nvim", ft = jupyter_ft },
      { "quarto-dev/quarto-nvim", ft = jupyter_ft },
      { "GCBallesteros/jupytext.nvim", ft = jupyter_ft },
      { "kiyoon/jupynium.nvim", ft = jupyter_ft },
      { "mfussenegger/nvim-dap", ft = py_ft },
      { "rcarriga/nvim-dap-ui", ft = py_ft },
      { "mfussenegger/nvim-dap-python", ft = py_ft },
      {
        "linux-cultist/venv-selector.nvim",
        branch = "regexp",
        ft = py_ft,
        opts = {
          stay_on_this_version = true,
          name = ".venv",
          auto_refresh = true,
          search_venv_managers = true,
          notify_user_on_activate = true,
        },
      },
      { "stevearc/dressing.nvim", event = "VeryLazy" },
      { "ibhagwan/fzf-lua", ft = py_ft, dependencies = "nvim-tree/nvim-web-devicons" },
      { "benomahony/uv.nvim", ft = mojo_ft, opts = { picker_integration = true } },
      { "benlubas/molten-nvim", ft = mojo_ft },
      { "jbyuki/nabla.nvim", ft = py_ft },
      { "bfredl/nvim-jupyter", ft = jupyter_ft },
    },
    config = function()
      require("config.lang.python").setup_python(opts)
    end,
    opts = {
      experimental = {
        client = {
          dynamicRegistration = true,
          snippetTextEdit = true,
        },
        server = {
          hoverActions = {
            enable = true,
            prefer = "markdown",
          },
        },
      },
    },
  },
}
