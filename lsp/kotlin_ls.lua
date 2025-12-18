-- /qompassai/Diver/lsp/kotlin_ls.lua
-- Qompass AI Kotlin LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'kotlin-language-server',
    },
    filetypes = {
        'kotlin',
    },
    root_markers = { ---@type string[]
        'settings.gradle',
        'settings.gradle.kts',
        'build.xml',
        'pom.xml',
        'build.gradle',
        'build.gradle.kts',
    },
}
