-- /qompassai/Diver/lsp/gdscript.lua
-- Qompass AI - [Add description here]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local port = os.getenv("GDScript_Port") or "6005"
local cmd = vim.lsp.rpc.connect("127.0.0.1", tonumber(port))
vim.lsp.config['gdscript'] = {
  cmd = cmd,
  filetypes = {
    "gd",
    "gdscript",
    "gdscript3"
  },
  root_markers = {
    "project.godot",
    ".git"
  },
}