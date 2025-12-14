-- /qompassai/Diver/lsp/tombi_ls.lua
-- Qompass AI Tombi LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Reference:  https://tombi-toml.github.io/tombi/
vim.lsp.config['tombi_ls'] = {
  cmd = {
    'tombi',
    'lsp',
  },
  filetypes = {
    'toml',
  },
  root_markers = {
    'tombi.toml',
    'pyproject.toml',
    '.git',
  },
}