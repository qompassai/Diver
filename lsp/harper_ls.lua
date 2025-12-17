-- /qompassai/Diver/lsp/harper_ls.lua
-- Qompass AI Harper LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- https://github.com/automattic/harper
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'harper-ls',
    '--stdio',
  },
  filetypes = { ---@type string[]
    'asciidoc',
    'c',
    'clojure',
    'cmake',
    'cpp',
    'cs',
    'dart',
    'gitcommit',
    'go',
    'haskell',
    'html',
    'java',
    'javascript',
    'lua',
    'markdown',
    'nix',
    'php',
    'python',
    'ruby',
    'rust',
    'sh',
    'swift',
    'toml',
    'typescript',
    'typescriptreact',
    'typst',
  },
  root_markers = {
    '.git',
  },
  settings = {
    ['harper-ls'] = {
      --userDictPath = '~/dict.txt'
    },
  },
}