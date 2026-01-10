-- /qompassai/Diver/lsp/rego_ls.lua
-- Qompass AI Open Policy Agent (OPA) Rego LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'regols',
    },
    filetypes = {
        'rego',
    },
    root_markers = {
        '.git',
        '*.rego',
    },
    settings = {},
}