-- /qompassai/diver/lsp/gn_ls.lua
-- Qompass AI GN LSP Spec
return ---@type vim.lsp.Config
{
    cmd = {
        'gn-language-server',
        '--stdio',
    },
    filetypes = {
        'gn',
    },
    root_markers = {
        '.gn',
        '.git',
    },
}
