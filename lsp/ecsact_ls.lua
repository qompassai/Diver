-- ecsact_ls.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
    cmd = { 'ecsact_lsp_server', '--stdio' },
    filetypes = { 'ecsact' },
    root_markers = { '.git' },
}
