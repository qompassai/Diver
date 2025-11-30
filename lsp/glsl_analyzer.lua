-- /qompassai/Diver/lsp/glsl_analyzer.lua
-- Qompass AI GLSL Analyzer LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config["glsl_analyzer"] = {
  cmd = { "glsl_analyzer" },
  filetypes = { "glsl", "vert", "frag", "geom", "tesc", "tese", "comp" },
  codeActionProvider = {
    codeActionKinds = {
      "",
      "quickfix",
      "refactor",
    },
    resolveProvider = true,
  },
  colorProvider = false,
  semanticTokensProvider = nil,
  settings = {
    glsl = {
      cmd = { "glsl_analyzer", "--port", "7000" },
      includePaths = { "shaders/includes", "vendor/glsl" },
      defines = { "USE_NORMALMAP=1", "QUALITY=2" },
      formatter = { enabled = true },
    },
  },
}
