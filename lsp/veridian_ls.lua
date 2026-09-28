-- /qompassai/Diver/lsp/veridian_ls.lua
-- Qompass AI Veridian LSP Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- Veridian: SystemVerilog language server
-- Source: https://github.com/vivekmalneedi/veridian
-- Install: cargo install --git https://github.com/vivekmalneedi/veridian.git --all-features
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'veridian',
    },
    filetypes = { ---@type string[]
        'verilog',
        'systemverilog',
    },
    root_markers = { ---@type string[]
        'veridian.yml',
        '.git',
    },
}
