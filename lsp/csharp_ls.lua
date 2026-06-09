-- /qompassai/Diver/lsp/csharp_ls.lua
-- Qompass AI Diver Csharp LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
---@source https://github.com/razzmatazz/csharp-language-server/blob/main/docs/features.md
return ---@type vim.lsp.Config
{
    --capabilities = require('config.core.lsp'),
    cmd = {
        'csharp-ls',
        '--features',
        'metadata-uris',
    },
    filetypes = {
        'cs',
    },
    on_attach = require('config.core.lsp').on_attach,
    --[[
    on_attach = function(client, bufnr)
        client.server_capabilities.inlineCompletionProvider = true
        client.server_capabilities.inlayHintProvider = true
        client.server_capabilities.semanticTokensProvider = nil
        client.server_capabilities.codeLensProvider = nil
        client.server_capabilities.documentHighlightProvider = nil
        require('config.core.lsp').on_attach(client, bufnr)
    end,
    --]]
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
