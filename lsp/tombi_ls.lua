-- /qompassai/Diver/lsp/tombi_ls.lua
-- Qompass AI Diver Tombi LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Reference: https://tombi-toml.github.io/tombi/docs/configuration/
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'tombi',
        'lsp',
    },
    filetypes = { ---@type string[]
        'toml',
    },
    root_markers = { ---@type string[]
        'tombi.toml',
        'pyproject.toml',
        '.git',
    },
    settings = {
        extensions = {
            ['tombi-toml/cargo'] = {
                enabled = true,
                lsp = {
                    ['code-action'] = {
                        ['add-to-workspace-and-inherit-dependency'] = {
                            enabled = true,
                        },
                        ['convert-dependency-to-table-format'] = {
                            enabled = true,
                        },
                        enabled = true,
                        ['inherit-dependency-from-workspace'] = {
                            enabled = true,
                        },
                        ['inherit-from-workspace'] = { enabled = true },
                        ['update-dependency-to-latest-version'] = { enabled = true },
                    },
                    completion = {
                        ['dependency-feature'] = { enabled = true },
                        ['dependency-version'] = { enabled = true },
                        enabled = true,
                        path = { enabled = true },
                    },
                    ['document-link'] = {
                        ['crates-io'] = { enabled = true },
                        enabled = true,
                    },
                    enabled = true,
                    ['goto-declaration'] = {
                        dependency = { enabled = true },
                        enabled = true,
                        path = { enabled = true },
                    },
                    ['goto-definition'] = {
                        dependency = { enabled = true },
                        enabled = true,
                        member = { enabled = true },
                        path = { enabled = true },
                    },
                    hover = {
                        ['dependency-detail'] = { enabled = true },
                        ['feature-dependencies'] = { enabled = true },
                    },
                    references = {
                        dependency = { enabled = true },
                        enabled = true,
                    },
                },
            },
            ['tombi-toml/pyproject'] = {
                lsp = {
                    ['code-action'] = {
                        ['add-to-workspace-and-use-workspace-dependency'] = { enabled = true },
                        ['update-dependency-to-latest-version'] = { enabled = true },
                        ['use-workspace-dependency'] = { enabled = true },
                    },
                    completion = {
                        path = { enabled = true },
                    },
                    ['document-link'] = {
                        ['pypi-org'] = { enabled = true },
                    },
                    ['goto-declaration'] = {
                        dependency = { enabled = true },
                        member = { enabled = true },
                        path = { enabled = true },
                    },
                    ['goto-definition'] = {
                        dependency = { enabled = true },
                        member = { enabled = true },
                        path = { enabled = true },
                    },
                    hover = {
                        ['dependency-detail'] = { enabled = true },
                        ['feature-dependencies'] = { enabled = true },
                    },
                    ['inlay-hint'] = {
                        ['dependency-version'] = {
                            enabled = true,
                        },
                    },
                },
            },
            ['tombi-toml/tombi'] = {
                lsp = {
                    completion = {
                        path = {
                            enabled = true,
                        },
                    },
                    ['document-link'] = { enabled = true },
                    ['goto-definition'] = {
                        path = { enabled = true },
                    },
                    hover = { enabled = true },
                },
            },
        },

        files = {
            exclude = {
                '.cache/**/*.toml',
            },
            include = {
                '**/*.toml',
            },
            ['respect-ignore-files'] = true,
        },

        format = {
            rules = {
                ['array-bracket-space-width'] = 0,
                ['array-comma-space-width'] = 1,
                ['comment-style'] = 'normalize',
                ['date-time-delimiter'] = 'T',
                ['group-blank-lines-limit'] = 1,
                ['indent-style'] = 'space',
                ['indent-sub-tables'] = false,
                ['indent-table-key-value-pairs'] = false,
                ['indent-width'] = 2,
                ['inline-table-brace-space-width'] = 1,
                ['inline-table-comma-space-width'] = 1,
                ['key-quote-style'] = 'double',
                ['key-value-equals-sign-alignment'] = false,
                ['key-value-equals-sign-space-width'] = 1,
                ['line-ending'] = 'lf',
                -- line-width intentionally omitted: default is "no limit".
                ['string-quote-style'] = 'double',
                ['table-blank-lines'] = 1,
                ['trailing-comment-alignment'] = false,
                ['trailing-comment-space-width'] = 2,
            },
        },

        lint = {
            rules = {
                ['dotted-keys-out-of-order'] = 'warn',
                ['key-empty'] = 'warn',
                ['tables-out-of-order'] = 'warn',
            },
        },

        lsp = {
            ['code-action'] = { enabled = true },
            completion = { enabled = true },
            diagnostic = { enabled = true },
            ['document-link'] = { enabled = true },
            formatting = { enabled = true },
            ['goto-declaration'] = { enabled = true },
            ['goto-definition'] = { enabled = true },
            ['goto-type-definition'] = { enabled = true },
            hover = { enabled = true },
            references = { enabled = true },
            ['workspace-diagnostic'] = { enabled = true },
        },

        overrides = {},

        schema = {
            catalog = {
                paths = {
                    'tombi://www.schemastore.org/api/json/catalog.json',
                    'https://www.schemastore.org/api/json/catalog.json',
                },
            },
            enabled = true,
            strict = false,
        },

        schemas = {
            {
                path = 'tombi://www.schemastore.org/pyproject.json',
                include = { 'pyproject.toml' },
            },
            {
                path = 'tombi://www.schemastore.org/pyproject.json',
                include = { 'pyproject.toml' },
                root = 'tool.hatch',
                strict = false,
            },
        },
        ['toml-version'] = 'v1.0.0',
    },
}
