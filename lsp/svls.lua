-- /qompassai/Diver/lsp/svls.lua
-- Qompass AI SVLS SystemVerilog LSP Spec (svls)
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config["svls"] = {
  cmd = { "svls" },
  filetypes = { "systemverilog" },
  codeActionProvider = {
    codeActionKinds = { "", "quickfix", "refactor" },
    resolveProvider = true,
  },
  colorProvider = false,
  semanticTokensProvider = nil,
  settings = {
    svls = {
      enable_linter = true,
    },
  },
}
