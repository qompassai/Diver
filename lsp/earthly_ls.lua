-- earthly_ls.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
    cmd = { 'earthlyls' },
    filetypes = { 'earthfile' },
    root_markers = { 'Earthfile' },
}
