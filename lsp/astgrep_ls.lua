-- /qompassai/Diver/lsp/astgrep_ls.lua
-- Qompass AI Astgrep LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Reference:  -- https://ast-grep.github.io/reference/languages.html
vim.lsp.config['astgrep_ls'] = {
  cmd = {
    'ast-grep',
    'lsp'
  },
  reuse_client = function(client, config)
    config.cmd_cwd = config.root_dir
    return client.config.cmd_cwd == config.cmd_cwd
  end,
  filetypes = {
    'c',
    'cpp',
    'rust',
    'go',
    'java',
    'python',
    'javascript',
    "javascriptreact",
    "javascript.jsx",
    "typescript",
    "typescriptreact",
    "typescript.tsx",
    "html",
    "css",
    "kotlin",
    "dart",
  },
  root_markers = {
    'sgconfig.yaml',
    "sgconfig.yml"
  },
}