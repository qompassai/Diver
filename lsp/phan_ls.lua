-- /qompassai/Diver/lsp/phan_ls.lua
-- Qompass AI Phan LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'phan',
        '-m',
        'json',
        '--no-color',
        '--no-progress-bar',
        '-x',
        '-u',
        '-S',
        '--language-server-on-stdin',
        '--allow-polyfill-parser',
    },
    filetypes = { ---@type string[]
        'php',
    },
    root_markers = { ---@type string[]
        'composer.json',
        '.git',
    },
}
