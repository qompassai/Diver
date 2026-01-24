-- /qompassai/Diver/lsp/adals.lua
-- Qompass AI Diver Ada LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return {
    cmd = {
        'ada_language_server',
    },
    filetypes = {
        'ada',
    },
    root_markers = {
        '*.adc',
        'alire.toml',
        '.git',
        '*.gpr',
        'Makefile',
    },
    settings = {
        ada = {
            projectFile = 'project.gpr',
            scenarioVariables = {
                Mode = 'debug',
                Target = 'native',
            },
        },
    },
}