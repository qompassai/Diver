#!/usr/bin/env lua
-- /qompassai/Diver/lsp/soql_ls.lua
-- Qompass AI SOQL LSP Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
---@source [https://www.npmjs.com/package/@salesforce/soql-language-server](https://www.npmjs.com/package/@salesforce/soql-language-server)
return ---@type vim.lsp.Config
{
    cmd = {
        'soql-language-server',
        '--stdio',
    },
    filetypes = {
        'soql',
        'sosl',
    },
    root_markers = {
        '.git',
        'sfdx-project.json',
        'package.json',
        'pnpm-workspace.yaml',
    },
    settings = {
        soql = {
            enable_completion = true,
            enable_diagnostics = true,
            enable_go_to_definition = true,
            enable_hover = true,
            enable_references = true,
            enable_rename = true,
            enable_symbols = true,
            enable_validation = true,
        },
    },
}
