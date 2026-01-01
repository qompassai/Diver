-- /qompassai/Diver/lsp/alloy_ls.lua
-- Qompass AI Alloy LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'alloy',
        'lsp',
    },
    filetypes = {
        'alloy',
    },
    root_markers = {
        '.git',
    },
    vim.api.nvim_create_autocmd('FileType', {
        pattern = {
            'alloy',
        },
        callback = function()
            vim.lsp.start({
                name = 'alloy_ls',
                cmd = {
                    'alloy',
                    'lsp',
                },
                root_dir = vim.fs.dirname(vim.fs.find({
                    '.git',
                })[1]),
            })
        end,
    }),
}
