-- /qompassai/diver/lsp/lelwel_ls.lua
-- Qompass AI LelWel LSP Spec
return ---@type vim.lsp.Config
{
    cmd = {
        'lelwel-ls',
    },
    filetypes = {
        'llw',
    },
    root_markers = {
        '.git',
    },
}
