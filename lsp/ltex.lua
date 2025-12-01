-- /qompassai/Diver/lsp/ltex.lua
-- Qompass AI Ltex LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
vim.lsp.config['ltex_ls'] = {
  cmd = {
    'ltex-ls',
  },
  filetypes = {
    'bib',
    'gitcommit',
    'org',
    'plaintex',
    --'rst',
    'rnoweb',
    "lualatex",
    "quarto",
    "rmd",
    "context",
    "html",
    "xhtml",
    "mail",
    "text",
  },
  root_markers = {
    '.git',
  },
  settings = {
    ltex = {
      enabled = {
        'bibtex',
        'markdown',
        'tex',
        'rsweave',
        'restructuredtext',
        'latex',
        'plaintext'
      },
      language = 'en-US',
    },
  },
}