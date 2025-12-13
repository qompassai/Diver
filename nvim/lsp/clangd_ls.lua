-- /qompassai/Diver/lsp/clangd.lua
-- Qompass AI Clangd LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
vim.lsp.config['clangd_ls'] = {
    cmd = {
        'clangd',
    },
    filetypes = {
        'c',
        'cpp',
        'cuda',
        'objc',
        'objcpp',
        'proto',
        'ptx',
    },
    root_markers = {
        '.clangd',
        '.clang-tidy',
        '.clang-format',
        'compile_commands.json',
        'compile_flags.txt',
        'configure.ac',
    },
    capabilities = {
        textDocument = {
            completion = {
                editsNearCursor = true,
            },
        },
        offsetEncoding = {
            'utf-8',
            'utf-16',
        },
    },
}
