-- /qompassai/Diver/lsp/prisma_ls.lua
-- Qompass AI Prisma LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- pnpm add -g @prisma/language-server
--Reference: https://www.npmjs.com/package/@prisma/language-server
vim.lsp.config['prisma_ls'] = {
  cmd = {
    'prisma-language-server',
    '--stdio' },
  filetypes = {
    'prisma'
  },
  settings = {
    prisma = {
      prismaFmtBinPath = '',
    },
  },
  root_markers = {
    '.git',
    'package.json'
  },
}