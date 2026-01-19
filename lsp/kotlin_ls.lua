-- /qompassai/Diver/lsp/kotlin_ls.lua
-- Qompass AI Diver Kotlin LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'kotlin-language-server',
    },
    filetypes = {
        'kotlin',
    },
    root_markers = {
        'build.gradle',
        'build.gradle.kts',
        'build.xml',
        'settings.gradle',
        'settings.gradle.kts',

        'pom.xml',
    },
    settings = {},
}