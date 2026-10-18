-- /qompassai/Diver/lsp/luau_ls.lua
-- Qompass AI Diver Luau LSP Spec
return ---@type vim.lsp.Config
{
    cmd = {
        'luau-lsp',
        'lsp',
    },
    filetypes = {
        'luau',
    },
    root_markers = {
        '.git',
    },
    settings = {},
}
