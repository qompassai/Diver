-- /qompassai/Diver/lsp/systemd_ls.lua
-- Qompass AI Systemd Language Server LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@source https://github.com/JFryy/systemd-lsp
return ---@type vim.lsp.Config
{
    cmd = {
        'systemd-language-server',
    },
    filetypes = {
        'systemd',
    },
    root_markers = {
        '.git',
    },
    vim.api.nvim_create_autocmd('BufEnter',
    {
        pattern = {
            '*.automount',
            '*.build',
            '*.container',
            '*.device',
            '*.image',
            '*.kube',
            '*.mount',
            '*.network',
            '*.path',
            '*.pod',
            '*.scope',
            '*.service',
            '*.slice',
            '*.socket',
            '*.swap',
            '*.target',
            '*.timer',
            '*.volume',
        },
        callback = function()
            vim.bo.filetype = 'systemd'
            vim.lsp.start({
                name = 'systemd_ls',
                cmd = {
                    'systemd-lsp',
                },
                root_dir = vim.fn.getcwd(),
            })
        end,
    }),
}