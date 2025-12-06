-- /qompassai/Diver/lsp/ghcide_ls.lua
-- Qompass AI Ghcide LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Deprecated
-- Reference: https://github.com/digital-asset/ghcide
vim.lsp.config['ghcide_ls'] = {
  cmd = {
    'ghcide',
    '--lsp'
  },
  filetypes = {
    'haskell',
    'lhaskell'
  },
  root_markers = {
    'BUILD.bazel',
    'stack.yaml',
    'hie-bios',
    'cabal.config',
    'package.yaml'
  },
}