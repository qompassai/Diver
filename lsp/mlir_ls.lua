-- /qompassai/Diver/lsp/mlir_ls.lua
-- Qompass AI Multi-Level Intermediate Representation (MLIR) LSP Spec
return ---@type vim.lsp.Config
{
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
