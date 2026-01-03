-- /qompassai/Diver/lsp/cobol_ls.lua
-- Qompass AI Cobol LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lsp.Config
{
    name = 'cobol-ls',
    cmd = {
        'cobol-lsp',
    },
    filetypes = {
        'cobol',
        'COBOL',
        'cpy',
        'cpyb',
    },
    root_markers = {
        '.git',
        '.cobolplugin',
    },
    settings = {},
    on_attach = function(client, bufnr)
        client.server_capabilities.documentFormattingProvider = false
        vim.o.signcolumn = 'yes'
        vim.o.updatetime = 250
        vim.diagnostic.config({ virtual_text = false })
        vim.api.nvim_create_autocmd('CursorHold', {
            buffer = bufnr,
            callback = function()
                local opts = {
                    focusable = false,
                    close_events = {
                        'BufLeave',
                        'CursorMoved',
                        'InsertEnter',
                        'FocusLost',
                    },
                    border = 'rounded',
                    source = 'always',
                    prefix = ' ',
                    scope = 'cursor',
                }
                vim.diagnostic.open_float(nil, opts)
            end,
        })
    end,
}
