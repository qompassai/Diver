-- /qompassai/Diver/lsp/remark_ls.lua
-- Qompass AI Remark LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'remark-language-server',
    '--stdio',
  },
  filetypes = { ---@type string[]
    'markdown',
    'mdx',
  },
  root_markers = { ---@type string[]
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
            skipOffline = true, ---@type boolean
          },
        },
      },
      validate = true, ---@type boolean
      run = 'onType',
      organizeImports = false, ---@type boolean
    },
  },
  on_attach = function(client, bufnr)
    client.server_capabilities.documentFormattingProvider = true
  end,
}