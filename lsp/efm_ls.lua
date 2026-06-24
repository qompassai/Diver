-- /qompassai/Diver/lsp/efm_ls.lua
-- Qompass AI Diver EFM LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'efm-langserver',
    },
    filetypes = {
        'alsaconf',
    },
    init_options = {
        documentFormatting = true,
        hover = true,
        lintDebounce = 100,
        lintOnChange = true,
        lintOnSave = true,
        completion = true,
    },
    root_markers = {
        '.git',
        '.hg',
        '.svn',
    },
    settings = {
        languages = {
            alsaconf = {
                {
                    lintCommand = 'alsatplg -c ${INPUT} -o /dev/null',
                    lintStdin = false,
                    lintFormats = {
                        '%f:%l:%c: %trror: %m',
                        '%f:%l:%c: %tarning: %m',
                        '%f: %trror: %m',
                        '%f: %tarning: %m',
                        '%trror: %m',
                    },
                    lintSource = 'alsatplg',
                    lintSeverity = 1,
                },
            },
        },
    },
}