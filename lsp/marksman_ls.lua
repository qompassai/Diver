-- /qompassai/Diver/lsp/marksman_ls.lua
-- Qompass AI Marksman LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
--Reference:  https://github.com/artempyanykh/marksman
--https://github.com/artempyanykh/marksman/blob/main/docs/install.md

return ---@type vim.lsp.Config
{
    cmd = { ---@type string[]
        'marksman',
        'server',
    },
    filetypes = { ---@type string[]
        'markdown',
        'markdown.mdx',
    },
    root_markers = { ---@type string[]
        '.marksman.toml',
        '.git',
        '.hg',
        '.svn',
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
}
