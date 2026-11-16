-- /qompassai/Diver/lsp/rumdl_ls.lua
-- Qompass AI Rumdl LSP Spec
-- Alphabetical order throughout; positional arrays (cmd, MD022 lines-*) keep semantic order.
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
            MD013 = {
                ['code-blocks'] = false,
                headings = false,
                ['length-mode'] = 'visual',
                ['line-length'] = 350,
                paragraphs = true,
                reflow = true,
                ['reflow-mode'] = 'default',
                strict = false,
                tables = false,
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
                ['docs/api/**/*.md'] = {
                    'MD013',
                    'MD041',
                },
                ['**/TOC.md'] = {
                    'MD025',
                },
                ['README.md'] = {
                    'MD033',
                },
                ['SUMMARY.md'] = {
                    'MD025',
                },

                ['docs/legacy/**/*.md'] = {
                    'MD003',
                    'MD022',
                },
            },
        },
    },
}
