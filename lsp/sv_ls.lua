-- /qompassai/Diver/lsp/svls.lua
-- Qompass AI SVLS SystemVerilog LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'svls',
    },
    filetypes = {
        'verilog',
        'systemverilog',
    },
    root_markers = {},
    settings = {},
}