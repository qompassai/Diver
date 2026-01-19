-- /qompassai/Diver/lsp/jimmerdto_ls.lua
-- Qompass AI Diver Jimmer-DTO LSP Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'java',
        '-jar',
        vim.fn.expand('~/.local/share/jimmer-dto-lsp/server.jar'),
    },
    filetypes = { 'jimmer_dto' },
    root_markers = {
        'pom.xml',
        'build.gradle',
        'build.gradle.kts',
        '.git',
    },
    settings = {},
    vim.api.nvim_create_autocmd({
        'BufRead',
        'BufNewFile',
    }, {
        pattern = '*.dto',
        callback = function()
            vim.bo.filetype = 'jimmer_dto'
        end,
    }),
}