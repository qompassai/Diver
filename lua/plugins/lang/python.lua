-- /qompassai/Diver/lua/plugins/lang/python.lua
-- Qompass AI Diver Python Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
local py_ft = { "python", "ipynb", "jupyter", "quarto" }
local jupyter_ft = { "ipynb", "jupyter", "quarto" }
local mojo_ft = { "mojo", "🔥" }
local python_cfg = require("config.lang.python")
return {
  { "jpalardy/vim-slime", ft = jupyter_ft },
  { "jmbuhr/otter.nvim", ft = jupyter_ft },
  { "quarto-dev/quarto-nvim", ft = jupyter_ft },
  { "GCBallesteros/jupytext.nvim", ft = jupyter_ft },
  { "kiyoon/jupynium.nvim", ft = jupyter_ft },
  { "bfredl/nvim-jupyter", ft = jupyter_ft },
  --	{
  --		'mfussenegger/nvim-dap-python',
  --		dependencies = { 'mfussenegger/nvim-dap', 'rcarriga/nvim-dap-ui' },
  --		ft = py_ft,
  --		config = function(_, opts)
  --			python_cfg = require('config.lang.python')
  --			python_cfg.py_dap()
  --			python_cfg.python_cfg(opts)
  --		end,
  --		opts = {
  --			experimental = {
  --				client = { dynamicRegistration = true, snippetTextEdit = true },
  --				server = { hoverActions = { enable = true, prefer = 'markdown' } }
  --			}
  {
    "linux-cultist/venv-selector.nvim",
    branch = "main",
    ft = py_ft,
    opts = {
      stay_on_this_version = true,
      name = ".venv",
      auto_refresh = true,
      search_venv_managers = true,
      notify_user_on_activate = true,
    },
  },
  {
    "benomahony/uv.nvim",
    ft = py_ft,
    opts = { keymaps = false, picker_integration = true },
  },
  { "benlubas/molten-nvim", ft = mojo_ft },
  { "jbyuki/nabla.nvim", ft = py_ft },
}
