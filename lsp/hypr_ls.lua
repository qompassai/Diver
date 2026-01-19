-- /qompassai/Diver/lsp/hypr_ls.lua
-- Qompass AI HyprLS LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.filetype.add({
    pattern = {
        ['.*/hypr/.+%.conf'] = 'hyprlang',
        ['.*/hyprland%.conf'] = 'hyprlang',
    },
})
return ---@type vim.lsp.Config
    {
    cmd = {
        'hyprls',
    },
    filetypes = {
        'hyprlang',
        'hypr',
    },
    settings = {
        hyprls = {
            colorProvider = {
                enable = true,
            },
            completion = {
                enable = true,
                keywordSnippet = 'Both',
            },
            documentSymbol = {
                enable = true,
            },
            hover = {
                enable = true,
            },
            preferIgnoreFile = true,
            telemetry = {
                enable = false,
            },
        },
    },
},
    vim.api.nvim_create_autocmd({
        'BufEnter',
        'BufWinEnter',
    }, {
        pattern = {
            '*.hl',
            'hypr*.conf',
        },
        callback = function(event)
            print(string.format('starting hyprls for %s', vim.inspect(event)))
            vim.lsp.start({
                name = 'hyprlang',
                cmd = {
                    'hyprls',
                },
                root_dir = vim.fn.getcwd(),
                settings = {
                    hyprls = {
                        preferIgnoreFile = false,
                        ignore = {
                            'hyprlock.conf',
                            'hypridle.conf',
                        },
                    },
                },
            })
        end,
    }),
    vim.api.nvim_create_autocmd('FileType', {
        pattern = { 'hyprlang', 'hypr' },
        callback = function()
            vim.lsp.start({
                name = 'hyprls',
                cmd = { 'hyprls' },
                root_dir = vim.fs.dirname(vim.fs.find({
                    'hyprland.conf',
                    'hypr',
                    '.git',
                })[1] or vim.loop.cwd()),
                settings = {
                    hyprls = {
                        colorProvider = {
                            enable = true,
                        },
                        completion = { enable = true, keywordSnippet = 'Both' },
                        documentSymbol = { enable = true },
                        hover = { enable = true },
                        preferIgnoreFile = true,
                        telemetry = { enable = false },
                    },
                },
            })
        end,
    })