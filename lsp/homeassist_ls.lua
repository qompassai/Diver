-- homeassist_ls.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
    cmd = { 'vscode-home-assistant', '--stdio' },
    filetypes = { 'yaml' },
    root_markers = {
        'configuration.yaml',
        'configuration.yml',
    },
}
