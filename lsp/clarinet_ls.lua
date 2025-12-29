-- /qompassai/Diver/lsp/clarinet_ls.lua
-- Qompass AI Clarinet LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'clarinet',
        'lsp',
    },
    filetypes = {
        'clar',
        'clarity',
    },
    root_markers = {
        'Clarinet.toml',
    },
    vim.api.nvim_create_autocmd('FileType', {
        pattern = { 'clar', 'clarity' },
        callback = function()
            vim.lsp.start({
                name = 'clarity_ls',
                cmd = { 'clarinet', 'lsp' },
                root_dir = vim.fs.dirname(vim.fs.find({ 'Clar.toml', '.git' })[1]),
            })
        end,
    }),
}
