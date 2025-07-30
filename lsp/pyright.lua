-- /qompassai/Diver/lsp/pyright.lua
-- Qompass AI Python LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
vim.lsp.config['pyright'] = {
    cmd = { 'pyright-langserver', "--stdio" },
    filetypes = { 'python' },
    root_markers = {
        "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt",
        "Pipfile", "pyrightconfig.json",
    },
    settings = {
        python = {
            analysis = {
                autoSearchPaths = true,
                useLibraryCodeForTypes = true,
                autoImportCompletions = true,
                extraPaths = { "./src", "./lib" },
                stubPath = "typings",
                typeCheckingMode = "strict",
            },
        },
    },
    capabilities = vim.lsp.protocol.make_client_capabilities(),
    flags = { debounce_text_changes = 150 },
    single_file_support = true,
}
