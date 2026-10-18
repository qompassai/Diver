-- /qompassai/Diver/lsp/bsc_ls.lua
-- Qompass AI BrighterScript LSP Spec
---@type vim.lsp.Config
return {
    cmd = {
        'bsc',
        '--lsp',
        '--stdio',
    },
    filetypes = {
        'brs',
    },
    root_markers = {
        'makefile',
        'Makefile',
        '.git',
    },
}
