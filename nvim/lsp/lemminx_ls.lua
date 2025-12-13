-- /qompassai/Diver/lsp/lemminx.lua
-- Qompass AI Lemminx XML LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.lsp.config['lemminx_ls'] = {
    cmd = {
        'lemminx',
    },
    filetypes = {
        'atom',
        'rss',
        'svg',
        'xsd',
        'xsl',
        'xslt',
        'xml',
    },
    root_markers = {
        '.git',
        'pom.xml',
        'build.gradle',
        'settings.gradle',
        'build.xml',
        'ivy.xml',
    },
    settings = {
        xml = {
            format = {
                enabled = true,
                indentSize = 2,
                preserveEmptyContent = false,
                joinLines = true,
            },
            completion = {
                autoCloseTags = true,
                defaultNamespace = '',
                useSchemaLocation = true,
            },
            validation = {
                enabled = true,
                schemas = {
                    {
                        fileMatch = {
                            '*.xsd',
                            '*.xml',
                        },
                        url = 'https://www.w3.org/2001/XMLSchema.xsd',
                    },
                },
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
    init_options = {
        settings = {
            xml = {
                catalogs = {},
                trace = { server = 'verbose' },
            },
        },
    },
}
