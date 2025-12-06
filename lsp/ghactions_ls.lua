-- /qompassai/Diver/lsp/ghactions_ls.lua
-- Qompass AI Github Actions LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
-- Reference: https://github.com/lttb/gh-actions-language-server
-- pnpm add -g gh-actions-language-server
vim.lsp.config['ghactions_ls'] = {
  cmd = {
    'gh-actions-language-server',
    '--stdio'
  },
  filetypes = {
    'yaml',
    'yml'
  },
  root_dir = function(bufnr, on_dir)
    local parent = vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr))
    if
        vim.endswith(parent, '/.github/workflows')
        or vim.endswith(parent, '/.forgejo/workflows')
        or vim.endswith(parent, '/.gitea/workflows')
    then
      on_dir(parent)
    end
  end,
  init_options = {},
  capabilities = {
    workspace = {
      didChangeWorkspaceFolders = {
        dynamicRegistration = true,
      },
    },
  },
}