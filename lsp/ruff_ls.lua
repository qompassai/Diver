-- /qompassai/Diver/lsp/ruff_ls.lua
-- Qompass AI Diver Ruff LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- -------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'ruff',
        'server',
        '--preview',
    },
    filetypes = {
        'python',
    },
    on_attach = function(client)
        client.server_capabilities.semanticTokensProvider = nil
    end,
    root_markers = {
        '.git',
        'pyproject.toml',
        'ruff.toml',
    },
    init_options = {
        settings = {
            codeAction = {
                disableRuleComment = {
                    enable = true,
                },
                fixViolation = {
                    enable = true,
                },
            },
            configuration = {
                format = {
                    ['quote-style'] = 'single',
                },
                lint = {
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
                    preview = true,
                    unfixable = {
                        'F401',
                    },
                },
            },
            configurationPreference = 'filesystemFirst',
            exclude = {
                '**/tests/**',
            },
            fixAll = true,
            format = {
                backend = 'internal',
                preview = true,
            },
            lineLength = 100,
            lint = {
                enable = true,
                extendSelect = {
                    'W',
                    'C4',
                    'SIM',
                },
                ignore = {
                    'E4',
                    'E7',
                },
                preview = true,
                select = {
                    'E',
                    'F',
                    'I',
                    'UP',
                    'W',
                    'N',
                    'B',
                },
            },
            logLevel = 'info',
            organizeImports = true,
            showSyntaxErrors = true,
        },
    },
    vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('lsp_attach_disable_ruff_hover', {
            clear = true,
        }),
        callback = function(args)
            local client = vim.lsp.get_client_by_id(args.data.client_id)
            if client == nil then
                return
            end
            if client.name == 'ruff' then
                client.server_capabilities.hoverProvider = false
            end
        end,
        desc = 'LSP: Disable hover capability from Ruff',
    }),
}
