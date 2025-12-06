-- /qompassai/Diver/lsp/puppet_ls.lua
-- Qompass AI Puppet LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.lsp.config['puppet_ls'] = {
  cmd = {
    'puppet-languageserver',
    '--stdio'
  },
  filetypes = {
    'puppet'
  },
  root_markers = {
    'manifests',
    '.puppet-lint.rc',
    'hiera.yaml',
    '.git',
  },
}