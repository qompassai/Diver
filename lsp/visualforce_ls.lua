-- visualforce_ls.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
--@type vim.lsp.Config
return {
    filetypes = { 'visualforce' },
    root_markers = { 'sfdx-project.json' },
    init_options = {
        embeddedLanguages = {
            css = true,
            javascript = true,
        },
    },
}
