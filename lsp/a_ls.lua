-- /qompassai/Diver/lsp/a_ls.lua
-- Qompass AI AML LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
return {
    cmd = {
        'als',
        '--port',
        '5000',
    },
    filetypes = {
        'yaml',
        'yml',
        'json',
        'raml',
    },
    root_markers = {
        'api.raml',
        'api.yaml',
        'api.yml',
        'oas.yaml',
        'oas.yml',
        'asyncapi.yaml',
        'asyncapi.yml',
        '.amlconfig',
        'package.json',
        '.git',
    },
    settings = {
        als = {
            formattingOptions = {
                raml = {
                    tabSize = 2,
                    insertSpaces = true,
                },
                oas = {
                    tabSize = 2,
                    insertSpaces = true,
                },
            },
            genericOptions = {
                validateOnSave = true,
                validateOnChange = true,
            },
            templateType = 'FULL',
        },
    },
}
