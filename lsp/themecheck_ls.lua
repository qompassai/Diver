-- themecheck_ls.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
    cmd = { 'theme-check-language-server', '--stdio' },
    filetypes = { 'liquid' },
    root_markers = { '.theme-check.yml' },
    settings = {},
}
