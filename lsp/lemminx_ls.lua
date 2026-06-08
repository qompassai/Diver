-- /qompassai/Diver/lsp/lemminx.lua
-- Qompass AI LemMinX XML LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lsp.Config
return {
    capabilities = require('config.core.lsp').capabilities,
    cmd = {
        'lemminx',
    },
    filetypes = {
        'atom',
        'rss',
        'svg',
        'xaml',
        'xml',
        'xsd',
        'xsl',
        'xslt',
    },
    root_markers = {
        '*.csproj',
        '*.sln',
        '.git',
        'build.gradle',
        'build.xml',
        'ivy.xml',
        'pom.xml',
        'settings.gradle',
    },
    settings = {
        xml = {
            capabilities = {
                formatting = true,
            },

            catalogs = {
                vim.fn.expand('~/.config/lemminx/catalog.xml'),
            },

            completion = {
                autoCloseTags = true,
            },

            fileAssociations = {
                {
                    pattern = '*.xaml',
                    systemId = vim.fn.expand('~/.local/share/schemas/xaml/xaml2006.xsd'),
                },
                {
                    pattern = '*.xml',
                    systemId = 'https://www.w3.org/2001/XMLSchema.xsd',
                },
                {
                    pattern = '*.xsd',
                    systemId = 'https://www.w3.org/2001/XMLSchema.xsd',
                },
            },
            format = {
                enabled = true,
                formatComments = true,
                joinCDATALines = false,
                joinCommentLines = false,
                joinContentLines = false,
                spaceBeforeEmptyCloseTag = true,
                splitAttributes = false,
            },
            logs = {
                client = true,
                file = vim.fn.expand('~/.local/state/lemminx/lemminx.log'),
            },
            trace = {
                server = 'verbose',
            },
            useCache = true,
            validation = {
                enabled = true,
                noGrammar = 'hint',
                schema = true,
            },
        },
    },
}