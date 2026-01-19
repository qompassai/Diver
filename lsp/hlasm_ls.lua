-- /qompassai/diver/lsp/hlasm_ls.lua
-- Qompass AI Diver High Level Assembler (HLASM) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- -----------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'hlasm_language_server',
    },
    filetypes = {
        'hlasm',
    },
    root_markers = {
        '.hlasmplugin',
    },
}
