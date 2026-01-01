-- racket_ls.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
    cmd = { 'racket', '--lib', 'racket-langserver' },
    filetypes = { 'racket', 'scheme' },
    root_markers = { '.git' },
}
