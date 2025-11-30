-- /qompassai/Diver/lsp/tex_fmt.lua
-- Qompass AI Tex_Fmt LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config["tex_fmt"] = {
  cmd = {
    "tex-fmt",
  },
  filetypes = {
    "tex",
    "plaintex",
    "latex",
  },
  codeActionProvider = false,
  colorProvider = false,
  semanticTokensProvider = nil,
  settings = {
    tex_fmt = {},
  },
}
