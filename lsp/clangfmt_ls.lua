-- /qompassai/Diver/lsp/clang_format_ls.lua
-- Qompass AI C/C++ Formatter LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config['clangfmt_ls'] = {
    cmd = {
        'clang-format',
    },
    filetypes = {
        'c',
        'cpp',
        'cuda',
        'objc',
        'objcpp',
    },
    codeActionProvider = false,
    colorProvider = false,
    semanticTokensProvider = nil,
    settings = {
        clang_format = {
            extra_args = {
                '--style=file',
            },
        },
    },
}
