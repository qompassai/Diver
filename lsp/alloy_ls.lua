-- /qompassai/Diver/lsp/alloy_ls.lua
-- Qompass AI Alloy LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.filetype.add({
  pattern = {
    ['.*/*.als'] = 'alloy',
  },
})
return {
  cmd = {
    'alloy',
    'lsp',
  },
  filetypes = {
    'alloy',
  },
  root_markers = {
    '.git',
  },
}