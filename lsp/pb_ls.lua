-- /qompassai/Diver/lsp/pb_ls.lua
-- Qompass AI Protobuf (Pb) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'pbls',
    },
    filetypes = {
        'proto',
    },
    root_markers = {
        '.pbls.toml',
        '.git',
    },
    settings = {},
}
