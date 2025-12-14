-- /qompassai/Diver/lsp/neocmake_ls.lua
-- Qompass AI Neocmake LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Reference:  https://github.com/neocmakelsp/neocmakelsp
-- cargo install neocmake
vim.lsp.config['neocmake_ls'] = {
  cmd = {
    'neocmakelsp',
    '--stdio',
  },
  filetypes = {
    'cmake',
  },
  init_options = {
    format = {
      enable = true
    },
    lint = {
      enable = true
    },
    scan_cmake_in_package = true
  },
  root_markers = {
    '.neocmake.toml',
    'CMakeLists.txt',
    'CMakeCache.txt',
    'build',
    '.git',
  },
}
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.completion.completionItem.snippetSupport = true
capabilities = capabilities