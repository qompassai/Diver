-- /qompassai/Diver/lsp/ziggy_schema.lua
-- Qompass AI Ziggy Schema Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@source:  https://ziggy-lang.io/documentation/ziggy-lsp/
---@type vim.lsp.Config
return {
    cmd = {
        'ziggy', ---@type string[]
        'lsp',
        '--schema',
    },
    filetypes = {
        'ziggy_schema',
    },
    root_markers = {
        '.git',
    },
    settings = {},
}