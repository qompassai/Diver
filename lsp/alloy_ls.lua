-- /qompassai/Diver/lsp/alloy_ls.lua
-- Qompass AI Alloy LSP Spec
return ---@type vim.lsp.Config
{
    cmd = {
        'alloy',
        'lsp',
    },
    filetypes = {
        'alloy',
    },
    root_markers = {
        '.git',
    },
}
