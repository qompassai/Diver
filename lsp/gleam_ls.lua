-- /qompassai/Diver/lsp/gleam_ls.lua
-- Qompass AI Diver Gleam LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'gleam',
        'lsp',
    },
    filetypes = {
        'gleam',
    },
    root_markers = {
        'gleam.toml',
        '.git',
    },
    settings = {
        gleam = {},
    },
}