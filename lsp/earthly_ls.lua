-- /qompassai/Diver/lsp/earthly_ls.lua
-- Qompass AI Diver Earthly LSP Spec
return ---@type vim.lsp.Config
{
    cmd = {
        'earthlyls',
    },
    filetypes = {
        'earthfile',
    },
    root_markers = {
        'Earthfile',
    },
}
