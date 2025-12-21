-- /qompassai/Diver/lsp/gdscript_ls.lua
-- Qompass AI Godot Script (GdScript) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local port = os.getenv('GDScript_Port') or '6005'
local cmd = vim.lsp.rpc.connect('127.0.0.1', tonumber(port)) ---@type fun()
---@type vim.lsp.Config
return {
  cmd = cmd,
  filetypes = {
    'gd',
    'gdscript',
    'gdscript3',
  },
  root_markers = {
    'project.godot',
    '.git',
  },
}