-- Jupyter Plugin Group

return {
  -- Jupytext: Convert Jupyter notebooks to scripts and vice versa
  {
    "GCBallesteros/jupytext.nvim",
    lazy = false,
    config = function()
      require("jupytext").setup {
        notebook_to_script_cmd = "jupytext --to py",
        script_to_notebook_cmd = "jupytext --to ipynb",
      }
    end,
  },
  -- Jupynium: Integration with Jupyter notebooks
  {
    "kiyoon/jupynium.nvim", -- need 'pip install notebook nbclassic jupyter-console'
    lazy = false,
    build = "pip3 install --user . --break-system-packages",
    dependencies = {
      "stevearc/dressing.nvim", -- Optional, UI for :JupyniumKernelSelect
    },
    config = function()
      require("jupynium").setup {}
    end,
  },

  {
    "bfredl/nvim-jupyter",
    lazy = false,
    config = function()
      -- No specific configuration needed for basic usage, but you can add custom settings here
    end,
  },

  {
    "stevearc/dressing.nvim", -- UI improvement for Jupynium Kernel selection
    lazy = false,
    config = function()
      require("dressing").setup {
        input = {
          default_prompt = "> ",
        },
        select = {
          backend = { "telescope", "fzf", "builtin" },
        },
      }
    end,
  },
}
