-- /qompassai/Diver/lsp/remark_ls.lua
-- Qompass AI Remark LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'remark-language-server',
        '--stdio',
    },
    filetypes = {
        'markdown',
        'mdx',
    },
    root_markers = {
        '.remarkrc',
        '.remarkrc.json',
        '.remarkrc.js',
        '.remarkrc.cjs',
        '.remarkrc.mjs',
        '.remarkrc.yml',
        '.remarkrc.yaml',
        '.remarkignore',
    },
    settings = {
        remark = {
            plugins = {
                {
                    'remark-preset-lint-recommended',
                    {},
                },
                {
                    'remark-lint-no-dead-urls',
                    {
                        skipOffline = true,
                    },
                },
            },
            validate = true,
            run = 'onType',
            organizeImports = true,
        },
    },
    on_attach = function(client, bufnr)
        client.server_capabilities.documentFormattingProvider = true
        vim.api.nvim_buf_create_user_command(bufnr, 'RemarkFormat', function()
            vim.lsp.buf.format({
                bufnr = bufnr,
                filter = function(c)
                    return c.id == client.id
                end,
            })
        end, {
            desc = 'Format Markdown via remark-language-server',
        })
    end,
}