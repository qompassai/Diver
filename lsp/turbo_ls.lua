-- /qompassai/Diver/lsp/turbo_ls.lua
-- Qompass AI Turbo LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- pnpm add -g turbo-language-server
---@type vim.lsp.Config
return {
  cmd = { 'turbo-language-server', '--stdio' },
  filetypes = { 'html', 'ruby', 'eruby', 'blade', 'php' },
  root_markers = { 'Gemfile', '.git' },
}