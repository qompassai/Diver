-- /qompassai/Diver/lsp/nextflow_ls.lua
-- Qompass AI Nextflow LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- References: https://livesys.se/posts/nextflow-lsp-with-neovim/
vim.lsp.config['nextflow_ls'] = {
  cmd = {
    'java',
    '-jar',
    'nextflow',
  },
  filetypes = {
    'nextflow',
    'nf',
    'groovy',
    'config',
  },
  root_markers = {
    '.git',
    'main.nf',
    'nextflow.config',
  },
  settings = {
    nextflow = {
      format = {
        enabled = true,
        indentSize = 2,
        preserveEmptyContent = false,
      },
      completion = {
        enabled = true,
        includeModules = true,
      },
      validation = {
        enabled = true,
        warnOnUnusedVariables = true,
        processSchema = 'nf-core',
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
      nextflow = {
        trace = {
          server = 'verbose',
        },
        additionalModulePaths = {},
      },
    },
  },
}