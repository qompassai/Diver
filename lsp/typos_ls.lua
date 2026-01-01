-- typos_ls.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
    cmd = { 'typos-lsp' },
    root_markers = { 'typos.toml', '_typos.toml', '.typos.toml', 'pyproject.toml', 'Cargo.toml' },
    settings = {},
}
