-- /qompassai/Diver/lsp/cmake_ls.lua
-- Qompass AI CMake LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- References: https://github.com/regen100/cmake-language-server
vim.lsp.config['cmake'] = {
  cmd = {
    'cmake-language-server'
  },
  filetypes = {
    'cmake'
  },
  root_markers = {
    'CMakePresets.json',
    'CTestConfig.cmake',
    '.git',
    'build',
    'cmake'
  },
  init_options = {
    buildDirectory = 'build',
  },
  settings = {},
}