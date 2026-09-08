-- /qompassai/Diver/lsp/earthly_ls.lua
-- Qompass AI Diver Earthly LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- -------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'earthlyls',
    },
    filetypes = {
        'earthfile',
    },
    root_markers = {
        'Earthfile',
    },
}
