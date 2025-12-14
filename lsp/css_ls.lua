-- /qompassai/Diver/lsp/css_ls.lua
-- Qompass AI VSCode Css LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
----------------------------------------------------------------
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.completion.completionItem.snippetSupport = true
vim.lsp.config['css_ls'] = {
    capabilities = capabilities,
    cmd = {
        'vscode-css-language-server',
        '--stdio',
    },
    filetypes = {
        'css',
        'scss',
        'less',
    },
    init_options = {
        provideFormatter = true,
    },
    root_markers = {
        '.git',
        'package.json',
    },
    settings = {
        css = {
            validate = true,
        },
        scss = {
            validate = true,
        },
        less = {
            validate = true,
        },
        cssVariables = {
            lookupFiles = {
                '**/*.css',
                '**/*.scss',
                '**/*.sass',
                '**/*.less',
            },
        },
    },
}
capabilities.textDocument.completion.completionItem.snippetSupport = true
