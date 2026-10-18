-- /qompassai/Diver/lsp/hydra_ls.lua
-- Qompass AI Hydra LSP Spec
return ---@type vim.lsp.Config
{
    cmd = {
        'hydra-lsp',
    },
    filetypes = {
        'yaml',
    },
    root_markers = {
        '.git',
    },
}
