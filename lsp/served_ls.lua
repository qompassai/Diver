-- /qompassai/Diver/lsp/served_ls.lua
-- Qompass AI Serve-D LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
  cmd = {
    'serve-d',
    '--provide',
    'http',
    '--require',
    'served:workspace-d',
  },
  filetypes = {
    'd',
    'di',
    'dpp',
  },
  root_markers = {
    '.git',
    'dub.json',
    'dub.sdl',
    'meson.build',
    'package.json',
  },
}