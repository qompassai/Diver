-- /qompassai/Diver/lsp/djt_ls.lua
-- Qompass AI Django Template LSP Spec
---@type vim.lsp.Config
return {
    cmd = {
        'djlsp',
    },
    filetypes = {
        'htmldjango',
    },
    root_markers = { '.git' },
    settings = {},
}
