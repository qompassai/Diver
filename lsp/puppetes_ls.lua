-- /qompassai/Diver/lsp/puppet_ls.lua
-- Qompass AI Puppet Editor Services LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config['puppetes_ls'] = {
  cmd = {
    'ruby',
    'puppet-languageserver',
    '--stdio',
    '--puppet-settings=--moduledir,/etc/puppetlabs/code/modules',
  },
  filetypes = {
    'puppet',
  },
  root_markers = {
    'metadata.json',
    ".git",
  },
  codeActionProvider = {
    codeActionKinds = {
      "",
      "quickfix",
      "refactor",
    },
    resolveProvider = true,
  },
  colorProvider = false,
  semanticTokensProvider = nil,
  init_options = {
    puppet = {
      editorServices = {
        formatOnType = {
          enable = true,
        },
      },
    },
  },
  settings = {
    puppet = {},
  },
}