-- /qompassai/Diver/lsp/ansible_ls.lua
-- Qompass AI Ansiblels LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
vim.lsp.config['ansible_ls'] = {
  cmd = {
    'ansible-language-server',
    '--stdio'
  },
  filetypes = {
    'yaml.ansible',
    'ansible'
  },
  settings = {
    ansible = {
      ansible = {
        path = 'ansible',
        useFullyQualifiedCollectionNames = true,
      },
      ansibleLint = {
        enabled = true,
        path = 'ansible-lint',
        args = {},
      },
      executionEnvironment = {
        enabled = true,
        containerEngine = 'auto',
        image = '',
        pullPolicy = "missing",
        volumeMounts = {},
      },
      python = {
        activationScript = "",
      },
      completion = {
        provideRedirectModules = true,
        provideModuleOptions = true,
        provideModuleParameters = true,
      },
      validation = {
        enabled = true,
        lint = true,
        schemas = {},
      },
      telemetry = {
        enabled = false,
      },
    },
  },
  root_markers = {
    'ansible.cfg',
    '.ansible-lint'
  },
}