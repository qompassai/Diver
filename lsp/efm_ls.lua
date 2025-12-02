-- /qompassai/Diver/lsp/efm_ls.lua
-- Qompass AI EFM LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Reference: https://github.com/mattn/efm-langserver
-- go install github.com/mattn/efm-langserver@latest
vim.lsp.config['efm'] = {
  filetypes = {
    'python',
    'cpp',
    -- 'lua'
  },
  init_options = {
    documentFormatting = true,
    documentRangeFormatting = true,
    hover = true,
    documentSymbol = true,
    codeAction = true,
    completion = true,
  },
}