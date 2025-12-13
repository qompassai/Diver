-- /qompassai/Diver/lsp/tcl_ls.lua
-- Qompass AI Tool Command Language (TCL) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference: https://github.com/nmoroze/tclint
--pip install tclint
vim.lsp.config['tcl_Ls'] = {
    cmd = {
        'tclsp',
    },
    filetypes = {
        'tcl',
        'sdc',
        'xdc',
        'upf',
    },
    root_markers = {
        'tclint.toml',
        '.tclint',
        'pyproject.toml',
        '.git',
    },
}
