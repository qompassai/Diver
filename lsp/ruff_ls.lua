-- /qompassai/Diver/lsp/ruff_ls.lua
-- Qompass AI Diver Ruff LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- -------------------------------------------------
---@param bufnr integer
---@param kind string
local function ruff_action(bufnr, kind)
    vim.lsp.buf.code_action({
        context = {
            only = {
                kind,
            }, ---@as lsp.CodeActionKind[]
            diagnostics = {},
        },
        apply = true,
        bufnr = bufnr,
    })
end
return ---@type vim.lsp.Config
{
    capabilities = require('config.core.lsp').capabilities,
    cmd = {
        'ruff',
        'server',
        '--preview',
    },
    filetypes = {
        'python',
    },
    on_attach = function(client, bufnr)
        client.server_capabilities.semanticTokensProvider = nil
        client.server_capabilities.inlayHintProvider = nil
        client.server_capabilities.hoverProvider = false

        local augroup = vim.api.nvim_create_augroup('ruff_fix_on_save_' .. bufnr, {
            clear = true,
        })
        vim.api.nvim_create_autocmd('BufWritePre', {
            group = augroup,
            buffer = bufnr,
            callback = function()
                vim.lsp.inlay_hint.enable(false, {
                    bufnr = bufnr,
                })
                ruff_action(bufnr, 'source.fixAll.ruff')
                ruff_action(bufnr, 'source.organizeImports.ruff')
                vim.lsp.buf.format({ bufnr = bufnr, async = false })
            end,
        })
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
                    'C4',
                    'SIM',
                    'W',
                },
                ignore = {
                    'E4',
                    'E7',
                },
                preview = true,
                select = {
                    'B',
                    'E',
                    'F',
                    'I',
                    'N',
                    'UP',
                    'W',
                },
            },
            logLevel = 'info',
            organizeImports = true,
            showSyntaxErrors = true,
        },
    },
}