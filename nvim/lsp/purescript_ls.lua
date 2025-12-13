-- /qompassai/Diver/lsp/purescript_ls.lua
-- Qompass AI PureScript LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference: https://github.com/nwolverson/purescript-language-server
--pnpm add -g purescript-language-server
vim.lsp.config['purescript_ls'] = {
    cmd = {
        'purescript-language-server',
        '--stdio',
    },
    filetypes = {
        'purescript',
    },
    root_markers = {
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
