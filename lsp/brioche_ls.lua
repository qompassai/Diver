-- /qompassai/Diver/lsp/brioche_ls.lua
-- Qompass AI Brioche LSP Spec
return ---@type vim.lsp.Config
{
    cmd = {
        'brioche',
        'lsp',
    },
    filetypes = {
        'brioche',
    },
    root_markers = {
        'project.bri',
    },
}
