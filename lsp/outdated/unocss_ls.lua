-- /qompassai/Diver/lsp/unocss_ls.lua
-- Qompass AI Uno CSS LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
--https://github.com/xna00/unocss-language-server
--pnpm add -g unocss-language-server
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'unocss-language-server',
        '--stdio',
    },
    filetypes = { ---@type string[]
        'astro',
        'css',
        'ejs',
        'erb',
        'haml',
        'hbs',
        'html',
        'javascript',
        'javascriptreact',
        'less',
        'markdown',
        'php',
        'postcss',
        'rescript',
        'rust',
        'sass',
        'scss',
        'stylus',
        'typescript',
        'typescriptreact',
        'svelte',
        'vue',
        'vue-html',
    },
    root_markers = { ---@type string[]
        'uno.config.js',
        'uno.config.ts',
        'unocss.config.js',
        'unocss.config.ts',
    },
    workspace_required = true, ---@type boolean
}