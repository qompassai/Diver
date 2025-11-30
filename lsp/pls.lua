-- /qompassai/Diver/lsp/pls.lua
-- Qompass AI Perl LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local lspconfig = require("lspconfig")
lspconfig.pls = {
  default_config = {
    cmd = { "pls" },
    filetypes = { "perl" },
    root_dir = lspconfig.util.root_pattern(".git", "Makefile", "Build.PL", "cpanfile", "dist.ini"),
    settings = {
      pls = {
        perltidy = {
          perltidyrc = os.getenv("HOME") .. "/.perltidyrc",
        },
        perlcritic = {
          enabled = true,
          perlcriticrc = os.getenv("HOME") .. "/.perlcriticrc",
        },
        syntax = {
          enabled = true,
        },
        inc = { "${workspaceFolder}/lib" },
        cwd = "${workspaceFolder}",
      },
    },
    init_options = {},
  },
}
