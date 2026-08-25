-- /qompassai/Diver/lsp/pli_ls.lua
-- Qompass AI  PL/I LSP Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
    cmd = {
        'pli_language_server',
    },
    filetypes = {
        'pli',
    },
    root_markers = {
        '.pliplugin',
    },
}
