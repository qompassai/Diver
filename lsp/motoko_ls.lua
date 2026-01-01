-- motoko_ls.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
    cmd = { 'motoko-lsp', '--stdio' },
    filetypes = { 'motoko' },
    root_markers = { 'dfx.json', '.git' },
    init_options = {
        formatter = 'auto',
    },
}
