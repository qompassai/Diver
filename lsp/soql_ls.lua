#!/usr/bin/env lua
--- soql-language-server language-server config — starts the Salesforce SOQL/SOSL query files tutor.
---
--- Plain-language version: a language server is a helper program that reads your code and tells Neovim about
--- errors, completions, and definitions -- like a tutor looking over your shoulder. This file is the introduction
--- card that tells Neovim how to start the `soql-language-server` tutor whenever you open Salesforce SOQL/SOSL
--- query files. It only takes effect if `soql-language-server` is installed on your computer.
---@module 'lsp.soql_ls'
-- /qompassai/Diver/lsp/soql_ls.lua
-- Qompass AI SOQL LSP Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
---@source https://www.npmjs.com/package/@salesforce/soql-language-server
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
