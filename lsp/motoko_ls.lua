-- /qompassai/Diver/lsp/motoko_ls.lua
-- Qompass AI Motoko LSP Spec
---@type vim.lsp.Config
return {
    cmd = {
        'motoko-lsp',
        '--stdio',
    },
    init_options = {
        formatter = 'auto',
    },
    filetypes = {
        'motoko',
    },
    root_markers = {
        'dfx.json',
        '.git',
    },
    settings = {},
}
