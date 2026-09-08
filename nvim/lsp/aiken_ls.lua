-- /qompassai/Diver/lsp/aiken_l.lua
-- Qompass AI Aiken LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
return {
    cmd = {
        'aiken',
        'lsp',
    },
    filetypes = {
        'aiken',
    },
    root_markers = {
        'aiken.toml',
        '.git',
    },
    vim.api.nvim_create_autocmd('FileType', {
        pattern = {
            'aiken',
        },
        callback = function()
            vim.lsp.start({
                name = 'aiken_ls',
                cmd = {
                    'aiken',
                    'lsp',
                },
                root_dir = vim.fs.dirname(vim.fs.find({
                    'aiken.toml',
                    '.git',
                })[1]),
            })
        end,
    }),
}
