-- /qompassai/Diver/lsp/turtle_ls.lua
-- Qompass AI Turtle LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
--pnpm add -g turtle-language-server@latest
--Reference: ttps://github.com/stardog-union/stardog-language-servers/tree/master/packages/turtle-language-server
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'node',
        'turtle-language-server',
        '--stdio',
    },
    filetypes = { ---@type string[]
        'turtle',
        'ttl',
    },
    root_markers = { ---@type string[]
        '.git',
    },
}
