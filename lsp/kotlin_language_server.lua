-- kotlin_language_server.lua
-- Qompass AI kotlin_language_server LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.lsp.config["kotlin_language_server"] = {
  cmd = { "kotlin-language-server" },
  filetypes = { "kotlin" },
  root_markers = {
    "settings.gradle",
    "settings.gradle.kts",
    "build.xml",
    "pom.xml",
    "build.gradle",
    "build.gradle.kts",
  },
}
