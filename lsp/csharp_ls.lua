-- /qompassai/Diver/lsp/csharp_ls.lua
-- Qompass AI Diver Csharp LSP Config
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
