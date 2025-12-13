-- /qompassai/Diver/lsp/nushell_ls.lua
-- Qompass AI NuShell LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference: https://github.com/nushell/nushell
vim.lsp.config['nu_ls'] = {
    cmd = {
        'nu',
        '--lsp',
    },
    filetypes = {
        'nu',
    },
    root_markers = {
        '.git',
    },
}
