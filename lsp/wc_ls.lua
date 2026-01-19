-- /qompassai/Diver/lsp/wc_ls.lua
-- Qompass AI Web Components (WC) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@source  https://github.com/wc-toolkit/wc-language-server/tree/main
return ---@type vim.lsp.Config
{
    cmd = {
        'wc-language-server',
        '--stdio',
    },
    filetypes = {
        'astro',
        'css',
        'html',
        'javascript',
        'javascriptreact',
        'less',
        'markdown',
        'mdx',
        'scss',
        'svelte',
        'typescript',
        'typescriptreact',
        'vue',
    },
    init_options = {
        hostInfo = 'neovim',
    },
    root_markers = {
        '.git',
        'custom-elements.json',
        'package.json',
        'wc.config.cjs',
        'wc.config.js',
        'wc.config.mjs',
        'wc.config.ts',
    },
    settings = {
        wc_ls = {
            diagnosticSeverity = {
                deprecatedAttribute = 'warning',
                deprecatedElement = 'warning',
                duplicateAttribute = 'info',
                invalidAttributeValue = 'error',
                invalidBoolean = 'error',
                invalidNumber = 'error',
                unknownAttribute = 'error',
                unknownElement = 'hint',
            },
            mcp = {
                enabled = true,
                host = '127.0.0.1',
                port = 3000,
                transport = 'http',
            },
        },
    },
    tsdk = vim.fn.getcwd() .. '/node_modules/typescript/lib',
}
