-- /qompassai/Diver/lsp/markdown_oxide.lua
-- Qompass AI Markdown_oxide LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.lsp.config['markdown_oxide'] = {
    cmd = {
        'markdown-oxide',
    },
    root_markers = {
        '.git',
        '.obsidian',
        '.moxide.toml',
    },
    filetypes = { 'markdown' },
}
