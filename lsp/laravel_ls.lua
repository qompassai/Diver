-- /qompassai/Diver/lsp/laravel_ls.lua
-- Qompass AI Laravel LSP Spec
---@type vim.lsp.Config
return {
    cmd = {
        'laravel-ls',
    },
    filetypes = {
        'php',
        'blade',
    },
    root_markers = {
        'artisan',
    },
    settings = {
        ['laravel-ls'] = {},
    },
}
