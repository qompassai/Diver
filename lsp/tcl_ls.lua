-- /qompassai/Diver/lsp/tcl_ls.lua
-- Qompass AI Tool Command Language (TCL) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference: https://github.com/nmoroze/tclint
--pip install tclint
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'tclsp',
    },
    filetypes = { ---@type string[]
        'tcl',
        'sdc',
        'xdc',
        'upf',
    },
    root_markers = { ---@type string[]
        'tclint.toml',
        '.tclint',
        'pyproject.toml',
        '.git',
    },
}
