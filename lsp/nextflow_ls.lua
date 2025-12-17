-- /qompassai/Diver/lsp/nextflow_ls.lua
-- Qompass AI Nextflow LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'java',
    '-jar',
    'nextflow-language-server-all.jar',
  },
  filetypes = { ---@type string[]
    'nextflow',
  },
  root_markers = { ---@type string[]
    '.git',
    'nextflow.config',
  },
  settings = {
    settings = {
      nextflow = {
        files = {
          exclude = { ---@type string[]
            '.git',
            '.nf-test',
            'work'
          },
        },
      },
    },
  },
}