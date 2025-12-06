-- /qompassai/Diver/lsp/hls.lua
-- Qompass AI Haskell/WhitePaperLang LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- https://github.com/haskell/haskell-language-server
vim.lsp.config['h_ls'] = {
  cmd = { 'haskell-language-server-wrapper', '--lsp' },
  filetypes = {
    'haskell',
    'lhaskell',
    'cabal',
  },
  root_markers = {
    'hie.yaml',
    'stack.yaml',
    'cabal.project',
    '*.cabal',
    'package.yaml',
  },
  settings = {
    haskell = {
      formattingProvider = 'ormolu',
      cabalFormattingProvider = 'cabal-fmt',
    },
  },
}