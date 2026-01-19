-- /qompassai/Diver/lsp/adals.lua
-- Qompass AI Ada LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference:  https://github.com/AdaCore/ada_language_server
return {
    cmd = {
        'ada_language_server',
    },
    filetypes = {
        'ada',
    },
    root_markers = {
        'Makefile',
        '.git',
        'alire.toml',
        '*.gpr',
        '*.adc',
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
