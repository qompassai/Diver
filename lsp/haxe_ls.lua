-- /qompassai/Diver/lsp/haxe_ls.lua
-- Qompass AI Haxe LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.lsp.config['haxe_ls'] = {
    cmd = {
        'node',
        'server.js',
    },
    filetypes = {
        'haxe',
    },
    root_markers = {
        'build.hxml',
        'haxe_libraries',
        '.git',
    },
    init_options = {
        displayArguments = {
            'build.hxml',
        },
    },
    settings = {
        haxe = {
            executable = 'haxe',
            buildCompletionCache = true,
        },
    },
}
