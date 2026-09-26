#!/usr/bin/env lua5.1
--- agentscript-language-server language-server config — starts the AgentScript files tutor.
---
--- Plain-language version: a language server is a helper program that reads your code and tells Neovim about
--- errors, completions, and definitions -- like a tutor looking over your shoulder. This file is the introduction
--- card that tells Neovim how to start the `agentscript-language-server` tutor whenever you open AgentScript files.
--- It only takes effect if `agentscript-language-server` is installed on your computer.
---@module 'lsp.agentscript_ls'
-- /qompassai/Diver/lsp/agentscript_ls.lua
-- Qompass AI Agent Script LSP Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
---@source https://marketplace.visualstudio.com/items?itemName=salesforce.agent-script-language-client
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
