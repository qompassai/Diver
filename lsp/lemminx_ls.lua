-- /qompassai/Diver/lsp/lemminx.lua
-- Qompass AI LemMinX XML LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lsp.Config
return {
    cmd = {
        'lemminx',
    },
    filetypes = {
        'atom',
        'csproj',
        'rss',
        'svg',
        'xaml',
        'xml',
        'xsd',
        'xsl',
        'xslt',
    },
    root_markers = {
        'build.gradle',
        'build.xml',
        '*.csproj',
        'Directory.Build.props',
        'Directory.Packages.props',
        '.git',

        'ivy.xml',
        'pom.xml',
        'settings.gradle',
        '*.sln',
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
