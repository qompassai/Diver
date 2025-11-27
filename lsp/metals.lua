-- /qompassai/Diver/lsp/metals.lua
-- Qompass AI Metals LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return {
  cmd = { 'metals' },
  filetypes = { 'scala' },
  root_markers = { 'build.sbt', 'build.sc', 'build.gradle', 'pom.xml' },
  init_options = {
    statusBarProvider = 'show-message',
    isHttpEnabled = true,
    compilerOptions = {
      snippetAutoIndent = false,
    },
  },
  capabilities = {
    workspace = {
      configuration = false,
    },
  },
}