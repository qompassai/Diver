-- /qompassai/Diver/lsp/racket_ls.lua
-- Qompass AI Racket LSP Spec
return ---@type vim.lsp.Config
{
    cmd = {
        'racket',
        '--lib',
        'racket-langserver',
    },
    filetypes = {
        'racket',
        'scheme',
    },
    root_markers = {
        '.git',
    },
    settings = {},
}
