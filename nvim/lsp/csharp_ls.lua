-- /qompassai/Diver/lsp/csharp_ls.lua
-- Qompass AI Diver Csharp LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
---@source https://github.com/razzmatazz/csharp-language-server/blob/main/docs/features.md
return ---@type vim.lsp.Config
{
    cmd = {
        'csharp-ls',
        '--features',
        'metadata-uris',
    },
    filetypes = {
        'cs',
    },
    root_markers = {
        '.csproj',
        '.sln',
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
