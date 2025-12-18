-- /qompassia/Diver/lsp/contextive_ls.lua
-- Qompass AI Contextive LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- Reference: https://github.com/dev-cycles/contextive
-- curl -L -o Contextive.LanguageServer.zip "https://github.com/dev-cycles/contextive/releases/download/v1.17.8/Contextive.LanguageServer-linux-x64-1.17.8.zip"
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'Contextive.LanguageServer',
    },
    root_markers = { ---@type string[]
        '.contextive',
        '.git',
    },
}
