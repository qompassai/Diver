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
  -- Iron.nvim: REPL management for Jupyter and other interactive workflows
  {
    "Vigemus/iron.nvim",
    lazy = false,
    config = function()
      require("iron.core").setup {
        config = {
          scratch_repl = true,
          repl_definition = {
            python = {
              command = function()
                if os.getenv "PYTHON_VERSION" == "3.8" then
                  return { "micromamba", "run", "-n", "py38", "ipython" }
                elseif os.getenv "PYTHON_VERSION" == "3.9" then
                  return { "micromamba", "run", "-n", "py39", "ipython" }
                else
                  return { "ipython" }
                end
              end,
            },
            r = {
              command = { "R", "--no-save" }, -- R REPL
            },
            lua = {
              command = { "lua" }, -- Default Lua interpreter
            },
            mojo = {
              command = { "mojo" }, -- Mojo REPL
            },
            bash = {
              command = { "bash" }, -- Bash REPL
            },
          },
          repl_open_cmd = "vertical botright 100 split",
          highlight = {
            italic = true, -- Set highlight for sent text
          },
          preferred = {
            python = "python",
            r = "r",
            lua = "lua",
            bash = "bash",
            mojo = "mojo",
          },
        },
        keymaps = {
          send_motion = "<space>sc",
          visual_send = "<space>sc",
          send_file = "<space>sf",
          send_line = "<space>sl",
          send_mark = "<space>sm",
          mark_motion = "<space>mc",
          mark_visual = "<space>mc",
          remove_mark = "<space>md",
          cr = "<space>s<cr>",
          interrupt = "<space>s<space>",
          exit = "<space>sq",
          clear = "<space>cl",
        },
      }
      local iron = require "iron.core"
      if vim.fn.executable "micromamba" == 1 then
        iron.config.repl_definition.python.mamba = {
          command = { "micromamba", "run", "-n", "py310", "ipython" },
        }
      end
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
