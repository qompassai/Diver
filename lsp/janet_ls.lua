-- janet_ls.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
    cmd = {
        'janet-lsp',
        '--stdio',
    },
    filetypes = { 'janet' },
    root_markers = { 'project.janet', '.git' },
}
