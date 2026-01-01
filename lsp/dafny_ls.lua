-- dafny_ls.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
    cmd = { 'dafny', 'server' },
    filetypes = { 'dfy', 'dafny' },
    root_markers = { '.git' },
}
