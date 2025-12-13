-- /qompassai/Diver/lsp/mlir_ls.lua
-- Qompass AI Multi-Level Intermediate Representation (MLIR) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ------------------------------------------------------------------
--Reference: https://mlir.llvm.org/docs/Tools/MLIRLSP/#mlir-lsp-language-server--mlir-lsp-server=
--[[
git clone https://github.com/llvm/llvm-project.git
cd llvm-project
mkdir build && cd build
cmake -G Ninja ../llvm \
  -DLLVM_ENABLE_PROJECTS="mlir" \
  -DCMAKE_BUILD_TYPE=Release
ninja mlir-lsp-server mlir-pdll-lsp-server
  --]]
vim.lsp.config['mlir_ls'] = {
    cmd = {
        'mlir-lsp-server',
    },
    filetypes = {
        'mlir',
    },
    root_markers = {
        '.git',
    },
}
