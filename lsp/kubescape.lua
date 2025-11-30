-- /qompassai/Diver/lsp/kubescape.lua
-- Qompass AI KubeScape Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config["kubescape"] = {
  cmd = { "kubescape" },
  filetypes = { "yaml", "yml", "json", "jsonc" },
  codeActionProvider = false,
  colorProvider = false,
  semanticTokensProvider = nil,
  settings = {
    kubescape = {},
  },
  single_file_support = true,
}
