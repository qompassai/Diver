-- /qompassai/Diver/lsp/dolmen_ls.lua
-- Qompass AI Dolmen LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Reference: https://github.com/Gbury/dolmen/blob/master/doc/lsp.md
-- opam install dolmen_lsp
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'dolmenls',
    },
    filetypes = { ---@type string[]
        'cnf',
        'icnf',
        'smt2',
        'tptp',
        'p',
        'zf',
    },
    root_markers = { ---@type string[]
        '.git',
    },
}
