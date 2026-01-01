-- debputy_ls.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
    cmd = { 'debputy', 'lsp', 'server' },
    filetypes = { 'debcontrol', 'debcopyright', 'debchangelog', 'autopkgtest', 'make', 'yaml' },
    root_markers = { 'debian' },
}
