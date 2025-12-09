-- /qompassai/Diver/lsp/astgrep_ls.lua
-- Qompass AI Astgrep LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Reference:  -- https://ast-grep.github.io/reference/languages.html
-- pnpm add -g @ast-grep/cli
vim.lsp.config['astgrep_ls'] = {
  cmd = {
    'ast-grep',
    'lsp'
  },
  workspace_required = true,
  reuse_client = function(client, config)
    config.cmd_cwd = config.root_dir
    return client.config.cmd_cwd == config.cmd_cwd
  end,
  filetypes = {
    'bash',
    'c',
    'cpp',
    'csharp',
    'css',
    'elixir',
    'go',
    'haskell',
    'html',
    'java',
    'javascript',
    'javascriptreact',
    'javascript.jsx',
    'json',
    'kotlin',
    'lua',
    'nix',
    'php',
    'python',
    'ruby',
    'rust',
    'scala',
    'solidity',
    'swift',
    'typescript',
    'typescriptreact',
    'typescript.tsx',
    'yaml',
  },
  root_markers = {
    'sgconfig.yaml',
    "sgconfig.yml"
  },
}