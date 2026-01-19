-- /qompassai/Diver/lsp/sway_ls.lua
-- Qompass AI Sway LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
    cmd = {
        'forc-lsp',
    },
    filetypes = {
        'sway',
    },
    root_markers = {
        'Forc.toml',
        'forc.toml',
        '.git',
    },
    settings = {},
    on_init = function(client)
        client.server_capabilities.documentFormattingProvider = false
    end,
}
