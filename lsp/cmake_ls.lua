-- /qompassai/Diver/lsp/cmake_ls.lua
-- Qompass AI CMake LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.lsp.config['cmake'] = {
  cmd = { 'cmake-language-server' },
  filetypes = { 'cmake' },
  single_file_support = true,
  init_options = {
    buildDirectory = "build",
  },
  settings = {},
}