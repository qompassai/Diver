-- /qompassai/Diver/lsp/fennel_ls.lua
-- Qompass AI Fennel LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference:  https://github.com/rydesun/fennel-language-server
vim.lsp.config['fennel_ls'] = {
    cmd = {
        'fennel-language-server',
    },
    filetypes = {
        'fennel',
    },
    root_markers = {
        'fnl',
        '.git',
    },
    settings = {
        fennel = {
            workspace = {
                library = vim.api.nvim_list_runtime_paths(),
                checkThirdParty = false,
            },
            diagnostics = {
                globals = {
                    'vim',
                },
            },
        },
    },
}
