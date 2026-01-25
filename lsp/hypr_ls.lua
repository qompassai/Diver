-- /qompassai/Diver/lsp/hypr_ls.lua
-- Qompass AI Diver HyprLS LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'hyprls',
    },
    filetypes = {
        'hyprlang',
        'hypr',
    },
    on_attach = require('config.core.lsp').on_attach,
    settings = {
        hyprls = {
            colorProvider = {
                enable = true,
            },
            completion = {
                enable = true,
                keywordSnippet = 'Both',
            },
            documentSymbol = {
                enable = true,
            },
            hover = {
                enable = true,
            },
            preferIgnoreFile = true,
            telemetry = {
                enable = false,
            },
        },
    },
}