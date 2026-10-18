-- /qompassai/Diver/lsp/clarinet_ls.lua
-- Qompass AI Diver Clarinet LSP Spec
return ---@type vim.lsp.Config
{
    cmd = {
        'clarinet',
        'lsp',
    },
    filetypes = {
        'clar',
        'clarity',
    },
    root_markers = {
        'Clarinet.toml',
    },
    settings = {},
}
