-- /qompassai/Diver/lsp/jimmerdto_ls.lua
-- Qompass AI Diver Jimmer-DTO LSP Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- Outside the returned config table: a bare call inside it becomes a numeric
-- key, which breaks `:checkhealth vim.lsp` (vim.spairs sorts mixed keys).
vim.api.nvim_create_autocmd({
    'BufRead',
    'BufNewFile',
}, {
    pattern = '*.dto',
    callback = function()
        vim.bo.filetype = 'jimmer_dto'
    end,
})

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
}
