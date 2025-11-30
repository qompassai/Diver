-- /qompassai/Diver/lsp/gdshader.lua
-- Qompass AI GDShader LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return {
  cmd = { "gdshader-lsp", "--stdio" },
  filetypes = { "gdshader", "gdshaderinc" },
  root_markers = { "project.godot" },
}
