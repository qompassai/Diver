-- /qompassai/Diver/lsp/spectral_ls.lua
-- Qompass AI Spectral LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'spectral-language-server',
        '--stdio',
    },
    filetypes = { ---@type string[]
        'yaml',
        'json',
        'yml',
    },
    root_markers = { ---@type string[]
        '.spectral.yaml',
        '.spectral.yml',
        '.spectral.json',
        '.spectral.js',
    },
    settings = {
        enable = true,
        run = 'onType',
        validateLanguages = {
            'yaml',
            'json',
            'yml',
        },
    },
}
