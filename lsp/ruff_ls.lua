-- /qompassai/Diver/lsp/ruff_ls.lua
-- Qompass AI Ruff LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
--https://docs.astral.sh/ruff/editors
vim.lsp.config['ruff_ls'] = {
    cmd = {
        'ruff',
        'server',
        '--preview',
    },
    filetypes = {
        'python',
    },
    root_markers = {
        'pyproject.toml',
        'ruff.toml',
        '.git',
    },
    init_options = {
        settings = {
            configuration = {
                lint = {
                    preview = true,
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
            fixAll = true,
            organizeImports = true,
            showSyntaxErrors = true,
            logLevel = 'info',
            -- logFile = '~/path/to/ruff.log', -- optional
            codeAction = {
                disableRuleComment = {
                    enable = false,
                },
                fixViolation = {
                    enable = true,
                },
            },
            lint = {
                enable = true,
                preview = true,
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
