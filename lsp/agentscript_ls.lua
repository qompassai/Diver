#!/usr/bin/env lua5.1
-- /qompassai/Diver/lsp/agentscript_ls.lua
-- Qompass AI Agent Script LSP Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
---@source [https://marketplace.visualstudio.com/items?itemName=salesforce.agent-script-language-client](https://marketplace.visualstudio.com/items?itemName=salesforce.agent-script-language-client)
return ---@type vim.lsp.Config
{
    cmd = {
        'agentscript-language-server',
        '--stdio',
    },
    filetypes = {
        'agent',
        'agentscript',
    },
    root_markers = {
        '.git',
        'package.json',
        'pnpm-workspace.yaml',
        'sfdx-project.json',
    },
    settings = {
        agentscript = {
            enable_completion = true,
            enable_diagnostics = true,
            enable_document_symbols = true,
            enable_formatting = true,
            enable_hover = true,
            enable_references = true,
            enable_rename = true,
            enable_validation = true,
        },
    },
}