-- /qompassai/Diver/lsp/air.lua
-- Qompass AI Air (R) LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return {
    cmd = {
        'air',
        'language-server',
    },
    filetypes = {
        'r',
    },
    on_attach = function(_, bufnr)
        vim.api.nvim_create_autocmd('BufWritePre', {
            buffer = bufnr,
            callback = function()
                vim.lsp.buf.format()
            end,
        })
    end,
}
