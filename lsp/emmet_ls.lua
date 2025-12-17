-- /qompassai/Diver/lsp/emmet_ls.lua
-- Qompass AI Emmet LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Reference: --- https://github.com/olrtg/emmet-language-server
-- pnpm add -g g @olrtg/emmet-language-server@latest
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'emmet-language-server',
    '--stdio',
  },
  filetypes = { ---@type string[]
    'astro',
    'css',
    'eruby',
    'html',
    'htmlangular',
    'htmldjango',
    'javascriptreact',
    'less',
    'pug',
    'sass',
    'scss',
    'svelte',
    'templ',
    'typescriptreact',
    'vue',
  },
  root_markers = { ---@type string[]
    '.git',
  },
}