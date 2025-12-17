-- /qompassai/Diver/lsp/purescript_ls.lua
-- Qompass AI PureScript LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference: https://github.com/nwolverson/purescript-language-server
--pnpm add -g purescript-language-server@latest
return {
  cmd = { ---@type string[]
    'purescript-language-server',
    '--stdio',
  },
  filetypes = { ---@type string[]
    'purescript',
  },
  root_markers = { ---@type string[]
    'bower.json',
    'flake.nix',
    'psc-package.json',
    'shell.nix',
    'spago.dhall',
    'spago.yaml',
  },
  settings = {
    purescript = {
      addSpagoSources = true,
      addNpmPath = true,
      formatter = 'purs-tidy',
    },
  },
}