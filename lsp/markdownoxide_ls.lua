-- /qompassai/Diver/lsp/markdown_oxide.lua
-- Qompass AI Diver Markdown Oxide LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'markdown-oxide',
    },
    filetypes = {
        'markdown',
    },
    root_markers = {
        '.git',
        '.obsidian',
        '.moxide.toml',
    },
    settings = {
        moxide = {
            block_transclusion = true,
            case_matching = 'Smart',
            dailynote = '%Y-%m-%d',
            daily_notes_folder = '',
            heading_completions = true,
            hover = true,
            include_md_extension_md_link = true,
            include_md_extension_wikilink = true,
            inlay_hints = true,
            link_filenames_only = false,
            new_file_folder_path = '',
            references_in_codeblocks = false,
            semantic_tokens = true,
            tags_in_codeblocks = false,
            title_headings = true,
            unresolved_diagnostics = true,
        },
    },
}
