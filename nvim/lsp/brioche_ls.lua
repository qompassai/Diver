-- /qompassai/Diver/lsp/brioche_ls.lua
-- Qompass AI Brioche LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'brioche',
        'lsp',
    },
    filetypes = {
        'brioche',
    },
    root_markers = {
        'project.bri',
    },
    vim.api.nvim_create_autocmd('FileType', {
        pattern = 'brioche',
        callback = function()
            vim.lsp.start({
                name = 'brioche_ls',
                cmd = {
                    'brioche',
                    'lsp',
                },
                root_dir = vim.fs.dirname(vim.fs.find({
                    'project.bri',
                    '.git',
                })[1]),
            })
        end,
    }),
}
