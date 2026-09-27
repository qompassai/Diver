-- /qompassai/Diver/after/plugin/verilog.lua
-- Qompass AI Diver After Plugin Verilog Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.bo.shiftwidth = 2
vim.bo.tabstop = 2
vim.bo.expandtab = false
-- Single BufWritePre ownership: the save-format pipeline in formatters/ is
-- the only save autocmd. This ftplugin file is sourced once per Verilog
-- buffer, so the stage registration is guarded by querying the registry
-- itself (no separate flag that could get out of sync if registration fails).
local formatters = require('formatters')
if formatters.get_stage('verilog_lsp_format') == nil then
    formatters.register_stage({
        name = 'verilog_lsp_format',
        priority = 434,
        filetypes = { 'verilog', 'systemverilog' },
        desc = 'Format Verilog sources with the attached LSP client before save',
        run = function(bufnr)
            if vim.lsp.buf.server_ready() then
                vim.lsp.buf.format({
                    bufnr = bufnr,
                    async = true,
                })
            end
        end,
    })
end
