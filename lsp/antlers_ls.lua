-- /qompassai/Diver/lsp/antlers_ls.lua
-- Qompass AI Antlers LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- pnpm add -g antlers-language-server
vim.lsp.config['antlers_ls'] = {
  cmd = {
    'antlersls',
    '--stdio'
  },
  filetypes = {
    'antlers',
    'html.antlers',
    'antlers.html'
  },
  root_markers = {
    ".git",
    'composer.json',
    'package.json',
    'antlers.config.js'
  },
  settings = {
    antlers = {
      formatting = {
        enabled = true,
        indentSize = 2,
      },
      validation = {
        enabled = true,
        strict = false,
      },
      completion = {
        enabled = true,
        triggerCharacters = {
          "{",
          " ",
          "."
        },
      },
      snippets = {
        enabled = true,
      },
      logs = {
        enabled = true,
        trace = true,
      },
      hover = {
        enabled = true,
      },
      folding = {
        enabled = true,
      },
    },
  },
  init_options = {
    settings = {
      antlers = {
        trace = {
          server = 'on'
        },
      },
    },
  },
}