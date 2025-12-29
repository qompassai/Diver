-- /qompassai/Diver/lsp/helm_ls.lua
-- Qompass AI Helm LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'helm_ls',
        'serve',
    },
    filetypes = {
        'helm',
        'yaml.helm-values',
    },
    root_markers = {
        'Chart.yaml',
        '.git',
    },
    vim.api.nvim_create_autocmd('FileType', {
        pattern = { 'helm', 'yaml.helm-values' },
        callback = function()
            vim.lsp.start({
                name = 'helm_ls',
                cmd = { 'helm_ls', 'serve' },
                root_dir = vim.fs.dirname(vim.fs.find({ 'Chart.yaml', '.git' })[1]),
            })
        end,
    }),
}
