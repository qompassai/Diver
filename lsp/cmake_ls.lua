-- /qompassai/Diver/lsp/cmake_ls.lua
-- Qompass AI CMake LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.lsp.config['cmake_ls'] = {
  cmd = {
    'cmake-language-server',
  },
  filetypes = {
    'cmake',
  },
  root_markers = {
    'build',
    'cmake',
    'CMakePresets.json',
    'CTestConfig.cmake',
    '.git'
  },
  init_options = {
    buildDirectory = 'build',
  },
  settings = {},
}