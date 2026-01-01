-- camel_ls.lua
-- Qompass AI Camel LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lsp.Config
{
    -- cmd = { "java", "-jar", "$XDG_DATA_HOME/camel/camel-language-server.jar" },
    cmd = {
        'camel-language-server',
    },
    filetypes = {
        'java',
        'xml',
        'yaml',
        'kotlin',
        'groovy',
    },
    root_markers = {
        'pom.xml',
        'build.gradle',
        'build.gradle.kts',
        '.git',
    },
    settings = {
        camel = {
            ['Camel catalog version'] = '4.11.0',
            ['Camel catalog runtime provider'] = 'QUARKUS',
            ['extra-components'] = {},
        },
    },
}
