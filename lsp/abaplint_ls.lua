#!/usr/bin/env luajit
---@version >5.1
-- /qompassai/Diver/lsp/abaplint_ls.lua
-- Qompass AI Diver Abaplint LSP Spec
return ---@type vim.lsp.Config
{
    cmd = {
        'abaplint',
        '--lsp',
    },
    filetypes = {
        'abap',
    },
    root_markers = {
        'abaplint.json',
        '.git',
    },
    settings = {},
}
