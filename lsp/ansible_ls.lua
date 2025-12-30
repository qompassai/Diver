-- /qompassai/Diver/lsp/ansible_ls.lua
-- Qompass AI Ansible LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
--Reference:  https://github.com/ansible/vscode-ansible
---@source https://docs.ansible.com/projects/vscode-ansible/configuration/
-- pnpm add -g @ansible/ansible-language-server@latest
return {
  cmd = {
    'ansible-language-server',
    '--stdio',
  },
  filetypes = {
    'yaml.ansible',
    'ansible',
  },
  root_markers = {
    'ansible.cfg',
    '.ansible-lint',
  },
  settings = {
    ansible = {
      ansible = {
        path = 'ansible',
        reuseTerminal = false,
        useFullyQualifiedCollectionNames = true,
      },
      ansibleServer = {
        trace = {
          server = 'verbose',
        },
      },
      completion = {
        provideModuleOptions = true,
        provideModuleParameters = true,
        provideRedirectModules = true,
      },
      executionEnvironment = {
        containerEngine = 'auto',
        enabled = true,
        image = '',
        pull = {
          arguments = {},
          policy = 'missing',
        },
        volumeMounts = {},
      },
      lightspeed = {
        apiEndpoint = 'https://c.ai.ansible.redhat.com',
        apiKey = '',
        enabled = false,
        provider = 'wca',
        modelName = '',
        suggestions = {
          enabled = false,
          waitWindow = 500,
        },
        timeout = 30000,
      },
      python = {
        activationScript = '',
        interpreterPath = 'python3',
      },
      validation = {
        arguments = {},
        enabled = true,
        lint = true,
        path = 'ansible-lint'
      },
      telemetry = {
        enabled = false,
      },
    },
  },
}