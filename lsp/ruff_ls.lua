-- /qompassai/Diver/lsp/ruff_ls.lua
-- Qompass AI Diver Ruff LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- -------------------------------------------------
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'ruff',
        'server',
        '--preview',
    },
    filetypes = { ---@type string[]
        'python',
    },
    root_markers = { ---@type string[]
        'pyproject.toml',
        'ruff.toml',
        '.git',
    },
    init_options = {
        settings = {
            configuration = {
                lint = {
                    preview = true, ---@type boolean
                    unfixable = {
                        'F401',
                    },
                    ['extend-select'] = {
                        'TID251',
                    },
                    ['flake8-tidy-imports'] = {
                        ['banned-api'] = {
                            ['typing.TypedDict'] = {
                                msg = 'Use `typing_extensions.TypedDict` instead',
                            },
                        },
                    },
                },
                format = {
                    ['quote-style'] = 'single',
                },
            },
            configurationPreference = 'filesystemFirst',
            exclude = { '**/tests/**' },
            lineLength = 100,
            fixAll = true, ---@type boolean
            organizeImports = true, ---@type boolean
            showSyntaxErrors = true, ---@type boolean
            logLevel = 'info',
            codeAction = {
                disableRuleComment = {
                    enable = false, ---@type boolean
                },
                fixViolation = {
                    enable = true, ---@type boolean
                },
            },
            lint = {
                enable = true, ---@type boolean
                preview = true, ---@type boolean
                select = {
                    'E',
                    'F',
                },
                extendSelect = {
                    'W',
                },
                ignore = {
                    'E4',
                    'E7',
                },
            },
            format = {
                preview = true,
                backend = 'internal',
            },
        },
    },
}
