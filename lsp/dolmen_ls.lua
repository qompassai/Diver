-- /qompassai/Diver/lsp/dolmen_ls.lua
-- Qompass AI Dolmen LSP Spec
-- opam pin add https://github.com/Gbury/dolmen.git
return ---@type vim.lsp.Config
{
    cmd = {
        'opam',
        'exec',
        '--',
        'dolmenls',
    },
    filetypes = {
        'cnf',
        'icnf',
        'smt2',
        'tptp',
        'p',
        'zf',
    },
    root_markers = {
        '.git',
    },
    settings = {},
}
