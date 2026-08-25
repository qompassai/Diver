-- /qompassai/Diver/lsp/mdxana_ls.lua
-- Qompass AI MDX Analyzer LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'mdx-language-server',
        '--stdio',
    },
    filetypes = {
        'mdx',
    },
    init_options = {
        typescript = {
            enabled = true,
            tsdk = ' /usr/lib/node_modules/typescript/lib',
        },
        locale = 'en',
    },
    root_dir = vim.fn.getcwd,
    root_markers = { ---@type string[]
        'package.json',
        'package.jsonc',
    },
    settings = {
        mdx = {
            trace = {
                server = {
                    format = 'text',
                    verbosity = 'verbose',
                },
            },
            validate = {
                validateDuplicateLinkDefinitions = 'warning',
                validateFileLinks = 'warning',
                validateFragmentLinks = 'warning',
                validateMarkdownFileLinkFragments = 'warning',
                validateReferences = 'warning',
                validateUnusedLinkDefinitions = 'warning',
                ignoreLinks = {},
            },
        },
    },
    before_init = function(_, config) ---@class lsp.LSPObject.typescript
        local io = config.init_options
        if io and io.typescript and not io.typescript.tsdk then
            io.typescript.tsdk = vim.lsp.util.get_typescript_server_path(config.root_dir) ---@type string
        end
    end,
    vim.api.nvim_create_autocmd('BufWritePre', {
        pattern = { '*.mdx' },
        callback = function()
            local bufnr = vim.api.nvim_get_current_buf()
            local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
            local text = table.concat(lines, '\n')
            local job = vim.fn.jobstart({ 'prettierd', vim.api.nvim_buf_get_name(bufnr) }, {
                stdin = 'pipe',
                stdout_buffered = true,
                on_stdout = function(_, data)
                    if not data then
                        return
                    end
                    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, data)
                end,
            })

            vim.fn.chansend(job, text)
            vim.fn.chanclose(job, 'stdin')
        end,
    }),
    vim.api.nvim_create_autocmd('BufWritePre', {
        pattern = {
            '*.mdx',
        },
        callback = function()
            local bufnr = vim.api.nvim_get_current_buf()
            local fname = vim.api.nvim_buf_get_name(bufnr)
            local text = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
            local out = {}
            local job = vim.fn.jobstart({ 'biome', 'format', '--stdin-file-path', fname }, {
                stdin = 'pipe',
                stdout_buffered = true,
                on_stdout = function(_, data)
                    if data then
                        out = data
                    end
                end,
            })
            vim.fn.chansend(job, text)
            vim.fn.chanclose(job, 'stdin')
            if #out > 0 then
                vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, out)
            end
        end,
    }),
}
