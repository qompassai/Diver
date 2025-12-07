-- /qompassai/Diver/lsp/spyglass_ls.lua
-- Qompass AI SpyGlass LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- https://github.com/SpyglassMC/Spyglass/tree/main/packages/language-server
--pnpm add -g  @spyglassmc/language-server
vim.lsp.config['spyglass_ls'] = {
  cmd = {
    'spyglassmc-language-server',
    '--stdio'
  },
  filetypes = {
    'mcfunction'
  },
  root_markers = {
    'pack.mcmeta'
  },
}