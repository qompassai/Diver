-- /qompassai/Diver/lsp/nomad_ls.lua
-- Qompass AI Nomad LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- go install github.com/juliosueiras/nomad-lsp@latest
-- Reference: https://github.com/juliosueiras/nomad-lsp
vim.lsp.config['nomad-lsp'] = {
  cmd = {
    'nomad-lsp'
  },
  filetypes = {
    'hcl.nomad',
    'nomad' },
  root_markers = {
    '*.nomad',
  },
}