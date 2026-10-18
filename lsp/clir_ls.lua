-- /qompassai/diver/lsp/clir_ls.lua
-- Qompass AI Clang IR (Clir) LSP Spec
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
