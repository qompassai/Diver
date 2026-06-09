#!/usr/bin/env lua5.1
-- /qompassai/Diver/lsp/avalonia_ls.lua
-- Qompass AI Diver Avalonia LSP Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
------------------------------------------------------
local ERROR = vim.log.levels.ERROR
return ---@type vim.lsp.Config
{
    -- capabilities = require('config.core.lsp'),
    cmd = {
        'avalonia-ls',
    },
    filetypes = {
        'axaml',
        'xml',
        'xaml',
    },
    on_attach = function(client, bufnr)
        -- client.server_capabilities.inlineCompletionProvider = true
        --client.server_capabilities.inlayHintProvider = true ---method not provided
        client.server_capabilities.semanticTokensProvider = nil
        client.server_capabilities.codeLensProvider = nil
        -- client.server_capabilities.documentHighlightProvider = true ---method not provided
        require('config.core.lsp').on_attach(client, bufnr)
        vim.api.nvim_buf_create_user_command(bufnr, 'XamlStyle', function()
            local file = vim.api.nvim_buf_get_name(bufnr)
            if file == '' then
                vim.notify('No file name for buffer', ERROR)
                return
            end
            if not file:match('%.axaml$') and not file:match('%.xaml$') then
                vim.notify('XamlStyler: not a .xaml/.axaml file', vim.log.levels.WARN)
                return
            end
            local cmd = {
                'xstyler',
                '--file',
                file,
            }
            vim.fn.jobstart(cmd, {
                stdout_buffered = true,
                stderr_buffered = true,
                on_exit = function(_, code, _)
                    vim.schedule(function()
                        if code == 0 then
                            if vim.api.nvim_buf_is_valid(bufnr) then
                                vim.cmd('checktime ' .. bufnr)
                            end
                            vim.notify('XamlStyler: formatted ' .. file)
                        else
                            vim.notify('XamlStyler: failed (exit ' .. code .. ')', ERROR)
                        end
                    end)
                end,
            })
        end, {
            desc = 'Format current XAML buffer with XamlStyler',
        })
    end,
    root_markers = {
        '*.csproj',
        'Directory.Packages.props',
        '.git',
        'global.json',
        'nuget.config',
        '*.sln',
    },
    settings = {
        avalonia = {
            previewer = {
                enabled = true,
            },
            xaml = {
                stylist = {
                    executable = 'xaml-styler', ---dotnet tool install --global XamlStyler.Console
                },
            },
        },
    },
}
