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
 
root_markers = {
        '.git',
        '.marksman.toml',
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
