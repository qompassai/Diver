-- /qompassai/diver/lsp/psalm.lua
-- Qompass AI Diver Psalm LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--References: composer global require vimeo/psalm
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'psalm',
    '--language-server',
  },
  filetypes = {
    'php',
    'phps',
    'blade',
  },
  root_markers = {
    'psalm.xml',
    'psalm.xml.dist',
    'composer.jsonc',
    '.git',
  },
  settings = {
    psalm = {
      errorLevel = 2,
      phpVersion = '8.4',
      reportUnusedCode = true,
      severity = 'all',
      showHints = true,
      showInfo = true,
      showSuggestions = true,
      strictTyping = true,
      useCache = true,
    },
  },
}