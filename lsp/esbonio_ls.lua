-- /qompassai/Diver/lsp/esbonio.lua
-- Qompass AI Diver Esbonio LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------

vim.lsp.config['esbonio_ls'] = {
    cmd = {
        'esbonio',
    },
    settings = {
        esbonio = {
            server = {
                logLevel = 'debug',
                timeout = 10,
            },
            sphinx = {
                enabled = true,
                builder = 'html',
                confDir = '${workspaceFolder}',
                srcDir = 'docs',
                buildDir = 'build',
                doctreeDir = 'build/.doctrees',
                pythonPath = nil,
            },
            docutils = {
                enabled = true,
                strict = true,
            },
            completion = {
                enabled = true,
            },
            diagnostics = {
                enabled = true,
            },
            preview = {
                enabled = true,
            },
        },
    },
    filetypes = {
        'rst',
        'rest',
        'restructuredtext',
    },
}
