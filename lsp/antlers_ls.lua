-- /qompassai/Diver/lsp/antlers_ls.lua
-- Qompass AI Diver Antlers LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'antlersls',
        '--stdio',
    },
    filetypes = {
        'antlers',
        'html.antlers',
        'antlers.html',
    },
    init_options = {
        settings = {
            antlers = {
                trace = {
                    server = 'on',
                },
            },
        },
    },
    root_markers = {
        '.git',
        'composer.json',
        'package.json',
        'antlers.config.js',
    },
    settings = {
        antlers = {
            formatting = {
                enabled = true,
                indentSize = 2,
            },
            validation = {
                enabled = true,
                strict = true,
            },
            completion = {
                enabled = true,
                triggerCharacters = {
                    '{',
                    ' ',
                    '.',
                },
            },
            snippets = {
                enabled = true,
            },
            logs = {
                enabled = true,
                trace = true,
            },
            hover = {
                enabled = true,
            },
            folding = {
                enabled = true,
            },
        },
    },
}