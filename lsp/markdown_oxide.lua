-- /qompassai/Diver/lsp/markdown_oxide.lua
-- Qompass AI Markdown_oxide LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'markdown-oxide',
  },
  root_markers = { ---@type string[]
    '.git',
    '.obsidian',
    '.moxide.toml',
  },
  filetypes = { ---@type string[]
    'markdown'
  },
}