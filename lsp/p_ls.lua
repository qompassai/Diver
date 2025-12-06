-- /qompassai/Diver/lsp/p_ls.lua
-- Qompass AI Perl Language Server (PSL) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference: https://github.com/FractalBoy/perl-language-server |  https://metacpan.org/pod/PLS
vim.lsp.config['p_ls'] = {
  cmd = {
    'pls'
  },
  settings = {
    perl = {
      perlcritic = {
        enabled = false
      },
      syntax = {
        enabled = true
      },
    },
  },
  filetypes = {
    'perl'
  },
  root_markers = {
    '.git'
  },
}