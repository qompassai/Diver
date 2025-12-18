-- /qompassai/Diver/lsp/haxe_ls.lua
-- Qompass AI Haxe LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'node',
        'server.js',
    },
    filetypes = { ---@type string[]
        'haxe',
    },
    root_markers = { ---@type string[]
        'build.hxml',
        'haxe_libraries',
        '.git',
    },
    init_options = {
        displayArguments = {
            'build.hxml',
        },
    },
    settings = {
        haxe = {
            executable = 'haxe',
            buildCompletionCache = true,
        },
    },
}
