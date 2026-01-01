-- mojo_ls.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
    cmd = { 'mojo-lsp-server' },
    filetypes = { 'mojo' },
    root_markers = { '.git' },
}
