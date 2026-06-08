-- /qompassai/Diver/lsp/csharp_ls.lua
-- Qompass AI Diver Csharp LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------

return ---@type vim.lsp.Config
{
    capabilities = require('config.core.lsp'),
    cmd = {
        'csharp-ls',
        '--features',
        'metadata-uris',
    },
    filetypes = {
        'cs',
    },
    root_markers = {
        '.sln',
        '.csproj',
    },
    settings = {
        csharp = {
            useMetadataUris = true,
            csharp_ls = {
                AutomaticWorkspaceInit = true,
            },
        },
    },
}