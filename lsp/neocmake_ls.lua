-- /qompassai/Diver/lsp/neocmake_ls.lua
-- Qompass AI Neocmake LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Reference:  https://github.com/neocmakelsp/neocmakelsp
-- cargo install neocmake
vim.lsp.config['neocmake_ls'] = {
    cmd = {
        'neocmakelsp',
        '--stdio',
    },

    filetypes = {
        'cmake',
    },
    root_markers = {
        '.neocmake.toml',
        'CMakeLists.txt',
        'CMakeCache.txt',
        'build',
        '.git',
    },
    init_options = {
        format = {
            enable = true,
        },
        lint = {
            enable = true,
        },
        scan_cmake_in_package = true,
        semantic_token = true,
    },
    capabilities = vim.tbl_deep_extend('force', vim.lsp.protocol.make_client_capabilities(), {
        workspace = {
            didChangeWatchedFiles = {
                dynamicRegistration = true,
                relative_pattern_support = true,
            },
        },
        textDocument = {
            completion = {
                completionItem = {
                    snippetSupport = true,
                },
            },
        },
    }),
}
