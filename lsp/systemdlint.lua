-- /qompassai/Diver/lsp/systemdlint.lua
-- Qompass AI Systemd Unit Lint Spec (systemdlint)
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config['systemdlint'] = {
  cmd = { 'systemdlint' },
  filetypes = { 'systemd', 'systemd.unit', 'systemd.service', 'systemd.timer' },
  codeActionProvider = false,
  colorProvider = false,
  semanticTokensProvider = nil,
  settings = {
    systemdlint = {
    },
  },
  flags = {
    debounce_text_changes = 150,
  },
  single_file_support = true,
 }