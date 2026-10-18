-- /qompassai/Diver/lsp/koka_ls.lua
-- Qompass AI Diver Koka LSP Spec
return ---@type vim.lsp.Config
{
    cmd = {
        'koka',
        '--language-server',
        '--lsstdio',
    },
    filetypes = {
        'koka',
    },
    root_markers = {
        '.git',
    },
}
