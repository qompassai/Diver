-- /qompassai/Diver/lsp/quicklintjs_ls.lua
-- Qompass AI QuickLint-JS LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- pnpm add -g quick-lint-js@latest
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'quick-lint-js',
        '--lsp-server',
    },
    filetypes = { ---@type string[]
        'javascript',
        'typescript',
    },
    root_markers = { ---@type string[]
        'package.json',
        'jsconfig.json',
        '.git',
    },
}
