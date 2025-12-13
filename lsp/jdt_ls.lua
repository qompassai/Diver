-- /qompassai/Diver/lsp/jdt_ls.lua
-- Qompass AI Java LSP SPec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.lsp.config['jdt_ls'] = {
    cmd = {
        'jdtls',
    },
    filetypes = {
        'java',
    },
    root_markers = {
        'mvnw',
        'gradlew',
        'settings.gradle',
        'settings.gradle.kts',
        '.git',
        'build.xml',
        'pom.xml',
        'build.gradle',
        'build.gradle.kts',
    },
    init_options = {},
}
