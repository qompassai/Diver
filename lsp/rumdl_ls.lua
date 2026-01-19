-- /qompassai/Diver/lsp/rumdl_ls.lua
-- Qompass AI Rumdl LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- -------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'rumdl',
        'server',
    },
    filetypes = {
        'markdown',
    },
    root_markers = {
        '.git',
        '.rumdl.toml',
    },
    settings = {
        rumdl = {
            global = {
                cache = true,
                cache_dir = '.rumdl_cache',
                disable = {
                    'MD013',
                    'MD033',
                },
                enable = {
                    'MD001',
                    'MD003',
                    'MD013',
                },
                exclude = {
                    '*.tmp.md',
                    'build',
                    'dist',
                    'docs/generated/**',
                    'node_modules',
                },
                flavor = 'mkdocs',
                include = {
                    '**/*.markdown',
                    'README.md',
                    'docs/**/*.md',
                },
                line_length = 120,
                respect_gitignore = false,
            },
            ['per-file-ignores'] = {
                ['**/TOC.md'] = {
                    'MD025',
                },
                ['README.md'] = {
                    'MD033',
                },
                ['SUMMARY.md'] = {
                    'MD025',
                },
                ['docs/api/**/*.md'] = {
                    'MD013',
                    'MD041',
                },
                ['docs/legacy/**/*.md'] = {
                    'MD003',
                    'MD022',
                },
            },
        },
    },
}
