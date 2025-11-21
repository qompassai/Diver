-- /qompassai/Diver/lsp/lwc_ls.lua
-- Qompass AI Lightning Web Components (LWC) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- -------------------------------------------------
-- Reference: https://www.npmjs.com/package/@salesforce/lwc-language-server
-- pnpm add -g @salesforce/lwc-language-server
---@type vim.lsp.Config
return {
  cmd = { 'lwc-language-server', '--stdio' },
  filetypes = { 'javascript', 'html' },
  root_markers = { 'sfdx-project.json' },
  init_options = {
    embeddedLanguages = {
      javascript = true,
    },
  },
}