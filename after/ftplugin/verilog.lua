-- /qompassai/Diver/after/plugin/verilog.lua
-- Qompass AI Diver After Plugin Verilog Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.bo.shiftwidth = 2
vim.bo.tabstop = 2
vim.bo.expandtab = false
vim.api.nvim_create_autocmd('BufWritePre', {
    buffer = 0,
    callback = function(args)
        if vim.lsp.buf.server_ready() then
            vim.lsp.buf.format({
                bufnr = args.buf,
                async = true,
            })
        end
    end,
})