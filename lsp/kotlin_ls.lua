-- /qompassai/Diver/lsp/kotlin_ls.lua
-- Qompass AI Diver Kotlin LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
return ---@type vim.lsp.Config
{
    -- stdio is the server's default mode: upstream editor docs invoke
    -- 'kotlin-language-server' with no arguments, so no flag is needed.
    cmd = {
        'kotlin-language-server',
    },
    filetypes = {
        'kotlin',
    },
    root_markers = {
        '.git',
        'build.gradle',
        'build.gradle.kts',
        'gradle.properties',
        'pom.xml',
        'settings.gradle',
        'settings.gradle.kts',
    },
    settings = {
        kotlin = {
            compiler = {
                jvm = {
                    target = '17',
                },
            },
            completion = {
                snippets = {
                    enabled = true,
                },
            },
            debugAdapter = {
                enabled = true,
            },
            externalSources = {
                autoConvertToKotlin = true,
                useKlsScheme = true,
            },
            indexing = {
                enabled = true,
            },
            languageServer = {
                enabled = true,
                transport = 'stdio',
            },
            trace = {
                server = 'off',
            },
        },
    },
}
