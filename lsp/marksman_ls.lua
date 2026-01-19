-- /qompassai/Diver/lsp/marksman_ls.lua
-- Qompass AI Diver Marksman LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'marksman',
        'server',
    },
    filetypes = {
        'markdown',
        'markdown.mdx',
    },
    on_attach = function(client, bufnr)
        client.server_capabilities.documentFormattingProvider = false
        vim.api.nvim_buf_create_user_command(bufnr, 'MarksmanHeadings', function()
            vim.lsp.buf.document_symbol()
        end, {})
        vim.api.nvim_buf_create_user_command(bufnr, 'MarksmanGotoLink', function()
            vim.lsp.buf.definition()
        end, {})
        vim.api.nvim_buf_create_user_command(bufnr, 'MarksmanRenameLink', function()
            vim.lsp.buf.rename()
        end, {})
    end,
    root_markers = {
        '.marksman.toml',
        '.git',
        '.hg',
        '.svn',
    },
    settings = {
        marksman = {
            core = {
                exclude = {
                    'build/**',
                    'dist/**',
                    '.git/**',
                    'node_modules/**',
                    '.obsidian/**',
                    '.venv/**',
                },
                follow_links = true,
                include = {
                    '**/*.md',
                    '**/*.mdx',
                },
                markdown_extensions = {
                    'definition-lists',
                    'footnotes',
                    'wiki-links',
                    'front-matter',
                    'task-lists',
                    'strikethrough',
                    'tables',
                },
                root_path = '.',
            },
            diagnostics = {
                enabled = true,
                ignored = {
                    'frontmatter-missing',
                },
                level = 'information',
            },
            index = {
                build_on_change = true,
                build_on_save = true,
            },
            server = {
                completion = true,
                hover = true,
                reference = true,
            },
            workspace = {
                include = {
                    '**/*.md',
                    '**/*.markdown',
                },
                exclude = {
                    'node_modules/**',
                    '**/tmp/**',
                },
            },
        },
    },
}