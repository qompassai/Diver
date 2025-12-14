-- /qompassai/Diver/lsp/pyright.lua
-- Qompass AI Python LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
vim.lsp.config['pyright_ls'] = {
    cmd = {
        'pyright',
        '--stdio',
    },
    filetypes = {
        'python',
    },
    root_markers = {
        'pyproject.toml',
        'setup.py',
        'setup.cfg',
        'requirements.txt',
        'Pipfile',
        'pyrightconfig.json',
    },
    settings = {
        python = {
            analysis = {
                autoSearchPaths = true,
                useLibraryCodeForTypes = true,
                autoImportCompletions = true,
                extraPaths = {
                    './src',
                    './lib',
                },
                stubPath = 'typings',
                typeCheckingMode = 'strict',
            },
        },
    },
}
