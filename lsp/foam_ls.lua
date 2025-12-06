-- /qompassai/Diverfoam_ls.lua
-- Qompass AI Foam LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- Reference:  https://github.com/FoamScience/foam-language-server
-- pnpm add -g foam-language-server
vim.lsp.config['foam_ls'] = {
  cmd = {
    'foam-ls',
    '--stdio'
  },
  filetypes = {
    'foam',
    'OpenFOAM'
  },
  root_markers = {
    '.foamcase',
    '.git',
    'system'
  },
}