-- /qompassai/Diver/lsp/oxlint_ls.lua
-- Qompass AI Javascript Oxidation Lint (Oxlint) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- References: https://www.npmjs.com/package/oxlint | https://oxc.rs/docs/guide/usage/linter/cli.html
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'oxlint',
        '-D',
        'correctness',
        '-D',
        'suspicious',
        '-D',
        'perf',
        '-W',
        'style',
        '--fix',
        '--type-aware',
        '--type-check',
        '--import-plugin',
        '--react-plugin',
        '', --nextjs-plugin'
        --'--tsconfig=tsconfig.json',
    },
    filetypes = { ---@type string[]
        'javascript',
        'javascriptreact',
        'javascript.jsx',
        'typescript',
        'typescriptreact',
        'typescript.tsx',
    },
    workspace_required = true, ---@type boolean
    root_markers = { ---@type string[]
        'oxlint',
        '.oxlintrc.json',
        '.oxlintrc.jsonc',
    },
}
