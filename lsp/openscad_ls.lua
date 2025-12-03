-- /qompassai/Diver/lsp/openscad_ls.lua
-- Qompass AI OpenSCAD LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- Reference: https://github.com/Leathong/openscad-LSP
-- cargo install openscad-lsp
vim.lsp.config['openscad-lsp'] = {
  cmd = {
    'openscad-lsp',
    '--stdio'
  },
  filetypes = {
    'openscad'
  },
  root_markers = {
    '.git'
  },
}