-- /qompassai/diver/lsp/dafny_ls.lua
-- Qompass AI Dafny LSP Spec
---@type vim.lsp.Config
return {
    cmd = {
        'dafny',
        'server',
    },
    filetypes = {
        'dfy',
        'dafny',
    },
    root_markers = {
        '.git',
    },
}
