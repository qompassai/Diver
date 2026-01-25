-- /qompassai/Diver/lsp/oxlint_ls.lua
-- Qompass AI Javascript Oxidation Lint (Oxlint) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
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
    filetypes = {
        'javascript',
        'javascriptreact',
        'javascript.jsx',
        'typescript',
        'typescriptreact',
        'typescript.tsx',
    },
  on_attach = require('config.core.lsp').on_attach,
    root_markers = {
        'oxlint',
        '.oxlintrc.json',
        '.oxlintrc.jsonc',
    },
    workspace_required = true, ---@type boolean
}