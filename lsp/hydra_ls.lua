-- /qompassai/Diver/lsp/hydra_ls.lua
-- Qompass AI Hydra LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'hydra-lsp',
    },
    filetypes = {
        'yaml',
    },
    root_markers = {
        '.git',
    },
}
