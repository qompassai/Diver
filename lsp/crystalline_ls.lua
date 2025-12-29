-- /qompassai/Diver/lsp/crystalline_ls.lua
-- Qompass AI Crystalline LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'crystalline',
    },
    filetypes = {
        'crystal',
    },
    root_markers = {
        'shard.yml',
        '.git',
    },
    vim.api.nvim_create_autocmd('FileType', {
        pattern = { 'crystal' },
        callback = function()
            vim.lsp.start({
                name = 'crystalline_ls',
                cmd = { 'crystalline' },
                root_dir = vim.fs.dirname(vim.fs.find({ 'shard.yml', '.git' })[1]),
            })
        end,
    }),
}
