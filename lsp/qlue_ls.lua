-- /qompassai/Diver/lsp/qlue_ls.lua
-- Qompass AI Qlue LSP Spec
return ---@type vim.lsp.Config
{
    cmd = {
        'qlue-ls',
        'server',
    },
    filetypes = {
        'sparql',
    },
    root_markers = {},
    settings = {},
}
