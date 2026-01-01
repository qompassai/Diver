-- pact_ls.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
    cmd = { 'pact-lsp' },
    filetypes = { 'pact' },
    root_markers = { '.git' },
}
