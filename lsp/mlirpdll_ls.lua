-- /qompassai/Diver/lsp/mlirpdll_ls.lua
-- Qompass AI Multi-Level Intermediate Represntation (MLIR) PDLL LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
--Reference:  https://mlir.llvm.org/docs/Tools/MLIRLSP/#pdll-lsp-language-server--mlir-pdll-lsp-server
return ---@type vim.lsp.Config
{
    cmd = { ---@type string[]
        'mlir-pdll-lsp-server',
    },
    filetypes = { ---@type string[]
        'pdll',
    },
    root_markers = { ---@type string[]
        'pdll_compile_commands.yml',
        '.git',
    },
}
