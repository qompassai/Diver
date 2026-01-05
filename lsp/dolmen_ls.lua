-- /qompassai/Diver/lsp/dolmen_ls.lua
-- Qompass AI Dolmen LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- opam install dolmen_lsp
return ---@type vim.lsp.Config
{
    cmd = {
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
}
