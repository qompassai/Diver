-- /qompassai/Diver/lsp/tofu_ls.lua
-- Qompass AI OpenTofu LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Reference: https://github.com/opentofu/tofu-ls
vim.lsp.config['tofu_ls'] = {
  cmd = {
    'tofu-ls'
  },
  filetypes = {
    'terraform',
    'opentofu',
    'hcl'
  },
  root_markers = {
    '.git',
    '.terraform',
    '.tofu',
    'main.tf',
    'main.tftpl'
  },
}