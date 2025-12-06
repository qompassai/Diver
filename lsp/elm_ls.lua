-- /qompassai/Diver/lsp/elm_ls.lua
-- Qompass AI Elm LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- Reference: https://github.com/elm-tooling/elm-language-server#installation
-- pnpm add -g elm elm-test elm-format elm-review @elm-tooling/elm-language-server

vim.lsp.config['elm_ls'] = {
  cmd = {
    'elm-language-server'
  },
  filetypes = {
    'elm'
  },
  init_options = {
    elmReviewDiagnostics = 'warning',
    skipInstallPackageConfirmation = false,
    disableElmLSDiagnostics = false,
    onlyUpdateDiagnosticsOnSave = false,
  },
  capabilities = {
    offsetEncoding = {
      'utf-8',
      'utf-16'
    },
  },
  root_markers = {
    'elm.json',
  }
}