-- /qompassai/Diver/lsp/atopile_ls.lua
-- Qompass AI Atopile LSP Spec
---@type vim.lsp.Config
return {
    cmd = {
        'ato',
        'lsp',
        'start',
    },
    filetypes = {
        'ato',
    },
    root_markers = {
        'ato.yaml',
        '.ato',
        '.git',
    },
}
