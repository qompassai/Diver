-- /qompassai/Diver/lsp/prisma_ls.lua
-- Qompass AI Prisma LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- pnpm add -g @prisma/language-server
--Reference: https://www.npmjs.com/package/@prisma/language-server
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'prisma-language-server',
        '--stdio',
    },
    filetypes = { ---@type string[]
        'prisma',
    },
    settings = {
        prisma = {
            prismaFmtBinPath = '',
        },
    },
    root_markers = { ---@type string[]
        '.git',
        'package.json',
    },
}
