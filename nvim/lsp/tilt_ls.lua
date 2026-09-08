-- /qompassai/Diver/lsp/tilt_ls.lua
-- Qompass AI Diver Tilt LSP Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
---@source https://docs.tilt.dev/
return ---@type vim.lsp.Config
{
    cmd = {
        'tilt',
        'lsp',
        'start',
    },
    filetypes = {
        'tiltfile',
    },
    root_markers = {
        '.git',
    },
    settings = {},
}
