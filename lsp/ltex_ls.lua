-- /qompassai/Diver/lsp/ltex_ls.lua
-- Qompass AI Ltex LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'ltex-ls',
    },
    filetypes = { ---@type string[]
        'bib',
        'context',
        'gitcommit',
        'html',
        'lualatex',
        'mail',
        'rmd',
        'org',
        'plaintex',
        'quarto',
        'rnoweb',
        --'rst',
        'text',
        'xhtml',
    },
    root_markers = { ---@type string[]
        '.git',
    },
    settings = {
        ltex = {
            enabled = {
                'bibtex',
                'latex',
                'markdown',
                'restructuredtext',
                'rsweave',
                'plaintext',
                'tex',
            },
            language = 'en-US',
        },
    },
}
