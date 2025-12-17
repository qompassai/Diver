-- /qompassai/Diver/lsp/pyrefly_ls.lua
-- Qompass AI Pyrefly LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'pyrefly',
    'lsp',
  },
  filetypes = { ---@type string[]
    'python',
  },
  init_options = {
    pyrefly = {
      displayTypeErrors = 'force-on'
    },
  },
  root_markers = { ---@type string[]
    '.git',
    'MANIFEST.in',
    'pyproject.toml',
    'pyrefly.toml',
    'requirements.txt',
    'setup.cfg',
    'setup.py',
  },
  on_exit = function(code, _, _)
    vim.notify('Closing Pyrefly LSP exited with code: ' .. code, vim.log.levels.INFO)
  end,
}