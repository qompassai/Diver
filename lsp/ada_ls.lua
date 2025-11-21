-- /qompassai/Diver/lsp/adals.lua
-- Qompass AI Ada_ls LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------

vim.lsp.config('ada_ls', {
  cmd = { 'ada_language_server' },
  filetypes = { 'ada' },
  root_markers = { 'Makefile', '.git', 'alire.toml', '*.gpr', '*.adc' },
  settings = {
    ada = {
      projectFile = "project.gpr",
      scenarioVariables = {
        Mode = "debug",
        Target = "native"
      }
    }
  }
})