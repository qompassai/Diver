-- /qompassai/Diver/lsp/cmake.lua
-- Qompass AI CMake LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
vim.lsp.config['cmake-language-server'] = {
  cmd = {
    'cmake-language-server'
  },
  filetypes = {
    "cmake"
  },
  init_options = {
    buildDirectory = 'build',
  },
}