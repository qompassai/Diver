-- /qompassai/Diver/lsp/kotlin_ls.lua
-- Qompass AI Kotlin LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
vim.lsp.config['kotlin_ls'] = {
    cmd = {
        'kotlin-language-server',
    },
    filetypes = {
        'kotlin',
    },
    root_markers = {
        'settings.gradle',
        'settings.gradle.kts',
        'build.xml',
        'pom.xml',
        'build.gradle',
        'build.gradle.kts',
    },
}
