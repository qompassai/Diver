-- /qompassai/diver/lsp/pest_ls.lua
-- Qompass AI Pest LSP Spec
---@type vim.lsp.Config
return {
    cmd = {
        'pest-language-server',
    },
    filetypes = {
        'pest',
    },
    root_markers = {
        '.git',
    },
}
