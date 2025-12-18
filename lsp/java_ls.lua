-- /qompassai/Diver/lsp/java_language_server.lua
-- Qompass AI Java Language Server Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'java-language-server',
    },
    filetypes = { ---@type string[]
        'java',
    },
    root_markers = { ---@type string[]
        'build.gradle',
        'build.gradle.kts',
        '.git',
        'pom.xml',
    },
    settings = { ---@type string[]
        ...,
    },
}
