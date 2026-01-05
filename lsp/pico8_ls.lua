-- /qompassai/Diver/lsp/pico8_ls.lua
-- Qompass AI Pico8 LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'pico8-ls',
        '--stdio',
    },
    filetypes = {
        'pico8',
        --'lua'
    },
    root_markers = {
        '.git',
        '.p8',
    },
    vim.api.nvim_create_autocmd('FileType', {
        pattern = {
            'pico8',
        },
        callback = function()
            vim.lsp.start({
                name = 'pico8_ls',
                cmd = {
                    'pico8_ls',
                    '--stdio',
                },
                root_dir = vim.fs.dirname(vim.fs.find({
                    '.git',
                    '.p8',
                })[1]),
            })
        end,
    }),
}
