-- /qompassai/Diver/lsp/styleable_ls.lua
-- Qompass AI Diver Styleable LSP Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
return {
    cmd = {
        'stylable-ls',
        '--stdio',
    },
    filetypes = {
        'css',
        'styl',
        'stylable',
    },
    root_markers = {
        'package.json',
        '.git',
    },
    settings = {},
}
