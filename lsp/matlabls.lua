-- /qompassai/Diver/lsp/matlabls.lua
-- Qompass AI MatLab LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
vim.lsp.config['matlab-language-server'] = {
  cmd = {
    'matlab-language-server',
    '--stdio'
  },
  filetypes = {
    'matlab'
  },
  root_dir = function(bufnr, on_dir)
    local root_dir = vim.fs.root(bufnr, '.git')
    on_dir(root_dir or vim.fn.getcwd())
  end,
  settings = {
    MATLAB = {
      indexWorkspace = true,
      installPath = '/usr/bin/matlab-language-server',
      matlabConnectionTiming = 'onStart',
      telemetry = false,
    },
  },
}