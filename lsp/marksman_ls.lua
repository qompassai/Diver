-- /qompassai/Diver/lsp/marksman_ls.lua
-- Qompass AI Marksman LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
--Reference:  https://github.com/artempyanykh/marksman
--https://github.com/artempyanykh/marksman/blob/main/docs/install.md
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'marksman',
    'server',
  },
  filetypes = { ---@type string[]
    'markdown',
    'markdown.mdx',
  },
  root_markers = { ---@type string[]
    '.marksman.toml',
    '.git',
    '.hg',
    '.svn',
  },
  on_attach = function(client, bufnr)
    client.server_capabilities.documentFormattingProvider = false
  end,
}