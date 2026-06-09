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
        'rumdl.toml',
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
                line_length = 350,
                respect_gitignore = true,
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
            MD013 = {
                ['line-length'] = 350,
                ['code-blocks'] = false,
                tables = false,
                headings = false,
                paragraphs = true,
                strict = false,
                reflow = true,
                ['reflow-mode'] = 'default',
                ['length-mode'] = 'visual',
            },
            MD022 = {
                ['lines-above'] = {
                    0,
                    0,
                    1,
                    1,
                    1,
                    1,
                },
                ['lines-below'] = {
                    0,
                    0,
                    1,
                    0,
                    0,
                    0,
                },
            },
            MD029 = {
                style = 'ordered',
            },
            MD046 = {
                style = 'consistent',
            },
            MD048 = {
                style = 'backtick',
            },
            MD051 = {
                ['anchor-style'] = 'github',
            },
            MD055 = {
                style = 'leading_and_trailing',
            },
        },
    },
}
