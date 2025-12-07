-- /qompassai/Diver/lsp/remark_ls.lua
-- Qompass AI Remark LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.lsp.config['remark_ls'] = {
  cmd = {
    'remark-language-server',
    '--stdio',
  },
  filetypes = {
    'markdown',
    'mdx',
  },
  root_markers = {
    '.remarkrc',
    '.remarkrc.json',
    '.remarkrc.js',
    '.remarkrc.cjs',
    '.remarkrc.mjs',
    '.remarkrc.yml',
    '.remarkrc.yaml',
    '.remarkignore',
  },
  settings = {
    remark = {
      plugins = {
        {
          'remark-preset-lint-recommended',
          {},
        },
        {
          'remark-lint-no-dead-urls',
          {
            skipOffline = true,
          },
        },
      },
      validate = true,
      run = 'onType',
      organizeImports = false,
    },
  },
  on_attach = function(client, bufnr)
    client.server_capabilities.documentFormattingProvider = true
  end
}