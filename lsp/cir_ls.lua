-- /qompassai/Diver/lsp/cir_ls.lua
-- Qompass AI LLVM ClangIR LSP Spec
---@source https://llvm.github.io/clangir

return ---@type vim.lsp.Config
{
    cmd = {
        'cir-lsp-server',
    },
    filetypes = {
        'cir',
    },
    root_markers = {
        '.git',
    },
}
