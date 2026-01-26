-- /qompassai/Diver/lsp/rech_ls.lua
-- Qompass AI Diver Rech LSP Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
return {
    cmd = {
        'node',
        'server.js',
        '--stdio',
    },
    filetypes = {
        'cobol',
        'cbl',
    },
    root_markers = {
        '.git',
        '.cobol-root',
    },
    settings = {},
}
