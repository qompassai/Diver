-- /qompassai/Diver/lsp/twiggy_ls.lua
-- Qompass AI Twiggy LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference: https://github.com/moetelo/twiggy
--pnpm add -g twiggy-language-server
vim.lsp.config['twiggy_ls'] = {
  cmd = {
    'twiggy-language-server',
    '--stdio'
  },
  filetypes = {
    'twig'
  },
  root_markers = {
    'composer.json',
    '.git'
  },
}