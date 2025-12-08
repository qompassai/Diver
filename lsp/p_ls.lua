-- /qompassai/Diver/lsp/p_ls.lua
-- Qompass AI Perl LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference: https://github.com/FractalBoy/perl-language-server |  https://metacpan.org/pod/PLS
vim.lsp.config['p_ls'] = {
  cmd = {
    'pls'
  },
  filetypes = {
    'perl'
  },
  root_markers = {
    ".git",
    "Makefile",
    "Build.PL",
    "cpanfile",
    "dist.ini"
  },
  settings = {
    pls = {
      perltidy = {
        perltidyrc = os.getenv('HOME') .. '/.perltidyrc',
      },
      perlcritic = {
        enabled = true,
        perlcriticrc = os.getenv("HOME") .. '/.perlcriticrc',
      },
      syntax = {
        enabled = true,
      },
      inc = {
        "${workspaceFolder}/lib"
      },
      cwd = "${workspaceFolder}",
    },
  },
  init_options = {},
}