-- /qompassai/Diver/lsp/mlirpdll_ls.lua
-- Qompass AI Multi-Level Intermediate Represntation (MLIR) PDLL LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
--Reference:  https://mlir.llvm.org/docs/Tools/MLIRLSP/#pdll-lsp-language-server--mlir-pdll-lsp-server
vim.lsp.config['mlirpdll_ls'] = {
    cmd = {
        'mlir-pdll-lsp-server',
    },
    filetypes = {
        'pdll',
    },
    root_markers = {
        'pdll_compile_commands.yml',
        '.git',
    },
}
