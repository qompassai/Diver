-- /qompassai/Diver/lsp/tsgo.lua
-- Qompass AI Typescript-Go (tsgo) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- pnpm add -g  @typescript/native-preview
vim.lsp.config['tsgo'] = {
    cmd = {
        'tsgo',
        '--lsp',
        '--stdio',
    },
    filetypes = {
        'javascript',
        'javascript.jsx',
        'javascriptreact',
        'typescript',
        'typescriptreact',
        'typescript.tsx',
    },
    root_markers = {
        'bun.lockb',
        'bun.lock',
        '.git',
        'package.json',
        'package-lock.json',
        'pnpm-lock.yaml',
        'yarn.lock',
    },
}
