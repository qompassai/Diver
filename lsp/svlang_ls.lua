-- /qompassai/Diver/lsp/svlang_ls.lua
-- Qompass AI SystemVerilog LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- Reference: https://github.com/imc-trading/svlangserver
--pnpm add -g @imc-trading/svlangserver@latest
return ---@type vim.lsp.Config
{
    cmd = {
        'svlangserver',
    },
    filetypes = {
        'verilog',
        'systemverilog',
    },
    root_markers = {
        '.svlangserver',
        '.git',
    },
    settings = {
        systemverilog = {
            includeIndexing = {
                '*.{v,vh,sv,svh}',
                '**/*.{v,vh,sv,svh}',
            },
        },
    },
    on_attach = function(client, bufnr)
        vim.api.nvim_buf_create_user_command(bufnr, 'LspSvlangserverBuildIndex', function()
            client:exec_cmd({
                title = 'Build Index',
                command = 'systemverilog.build_index',
            }, { bufnr = bufnr })
        end, {
            desc = 'Instructs language server to rerun indexing',
        })
        vim.api.nvim_buf_create_user_command(bufnr, 'LspSvlangserverReportHierarchy', function()
            client:exec_cmd({
                title = 'Build Index',
                command = 'systemverilog.build_index',
                arguments = {
                    vim.fn.expand('<cword>'),
                },
            }, {
                bufnr = bufnr,
            })
        end, {
            desc = 'Generates hierarchy for the given module',
        })
    end,
}