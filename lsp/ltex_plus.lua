-- /qompassai/Diver/lsp/ltex_plus.lua
-- Qompass AI Ltex_plus LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
local language_id_mapping = {
    bib = 'bibtex',
    lualatex = 'markdown',
    plaintex = 'tex',
    rnoweb = 'rsweave',
    rst = 'restructuredtext',
    tex = 'latex',
    text = 'plaintext',
}
local function get_language_id(_, filetype)
    return language_id_mapping[filetype] or filetype
end
---@type vim.lsp.Config
return {
    cmd = {
        'ltex-ls-plus',
    },
    filetypes = {
        'bib',
        'context',
        'gitcommit',
        'html',
        'markdown',
        'org',
        'lualatex',
        'plaintex',
        'quarto',
        'mail',
        'mdx',
        'rmd',
        'rnoweb',
        'rst',
        'tex',
        'text',
        'typst',
        'xhtml',
    },
    root_markers = {
        '.git',
    },
    get_language_id = get_language_id,
    settings = {
        ltex = {
            language = 'en-US',
            enabled = {
                'bib',
                'context',
                'gitcommit',
                'html',
                'markdown',
                'org',
                'lualatex',
                'plaintex',
                'quarto',
                'mail',
                'mdx',
                'rmd',
                'rnoweb',
                'rst',
                'tex',
                'latex',
                'text',
                'typst',
                'xhtml',
            },
        },
    },
}
